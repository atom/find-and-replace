{TextEditor} = require 'atom'
BufferSearch = require '../lib/buffer-search'

describe "BufferSearch", ->
  [search, editor, markersListener] = []

  beforeEach ->
    editor = new TextEditor

    editor.setText """
      -----------
      aaa bbb ccc
      ddd aaa bbb
      ccc ddd aaa
      -----------
      aaa bbb ccc
      ddd aaa bbb
      ccc ddd aaa
      -----------
    """

    search = new BufferSearch

    markersListener = jasmine.createSpy('markersListener')
    search.onDidUpdate(markersListener)

    search.setEditor(editor)
    search.setSearchParams(
      pattern: "a+"
      caseSensitive: false
      useRegex: true
      wholeWord: false
    )

  afterEach ->
    search.destroy()
    editor.destroy()

  expectResultsUpdated = (expectEvent, ranges) ->
    highlightedRanges = editor
      .getDecorations(type: 'highlight', class: 'find-result')
      .map (decoration) -> decoration.getMarker().getBufferRange()
      .sort (a, b) -> a.compare(b)
      .map (range) -> range.serialize()
    expect(highlightedRanges).toEqual(ranges)

    if expectEvent
      emittedMarkerRanges = markersListener
        .mostRecentCall.args[0]
        .map (marker) -> marker.getBufferRange().serialize()
      expect(emittedMarkerRanges).toEqual(ranges)

  it "highlights all the occurrences of the search regexp", ->
    expectResultsUpdated false, [
      [[1, 0], [1, 3]]
      [[2, 4], [2, 7]]
      [[3, 8], [3, 11]]
      [[5, 0], [5, 3]]
      [[6, 4], [6, 7]]
      [[7, 8], [7, 11]]
    ]

  describe "when the buffer changes", ->
    describe "when changes occur in the middle of the buffer", ->
      it "removes any invalidated search results and recreates markers in the changed regions", ->
        editor.setCursorBufferPosition([2, 5])
        editor.addCursorAtBufferPosition([6, 5])
        editor.insertText(".")
        editor.insertText(".")

        expectResultsUpdated false, [
          [[1, 0], [1, 3]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[7, 8], [7, 11]]
        ]

        spyOn(editor, 'scanInBufferRange').andCallThrough()
        advanceClock(editor.buffer.stoppedChangingDelay)

        expectResultsUpdated true, [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 5]]
          [[2, 7], [2, 9]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 5]]
          [[6, 7], [6, 9]]
          [[7, 8], [7, 11]]
        ]

        scannedRanges = (args[1] for args in editor.scanInBufferRange.argsForCall)
        expect(scannedRanges).toEqual [
          [[1, 3], [3, 8]]
          [[5, 3], [7, 8]]
        ]

    describe "when changes occur within the first search result", ->
      it "rescans the buffer from the beginning to the first valid marker", ->
        editor.setCursorBufferPosition([1, 2])
        editor.insertText(".")
        editor.insertText(".")

        expectResultsUpdated false, [
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        spyOn(editor, 'scanInBufferRange').andCallThrough()
        advanceClock(editor.buffer.stoppedChangingDelay)

        expectResultsUpdated true, [
          [[1, 0], [1, 2]]
          [[1, 4], [1, 5]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        scannedRanges = (args[1] for args in editor.scanInBufferRange.argsForCall)
        expect(scannedRanges).toEqual [
          [[0, 0], [2, 4]]
        ]

    describe "when changes occur within the last search result", ->
      it "rescans the buffer from the last valid marker to the end", ->
        editor.setCursorBufferPosition([7, 9])
        editor.insertText(".")
        editor.insertText(".")

        expectResultsUpdated false, [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
        ]

        spyOn(editor, 'scanInBufferRange').andCallThrough()
        advanceClock(editor.buffer.stoppedChangingDelay)

        expectResultsUpdated true, [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 9]]
          [[7, 11], [7, 13]]
        ]

        scannedRanges = (args[1] for args in editor.scanInBufferRange.argsForCall)
        expect(scannedRanges).toEqual [
          [[6, 7], [Infinity, Infinity]]
        ]
