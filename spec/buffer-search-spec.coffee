BufferSearch = require '../lib/buffer-search'
FindOptions = require '../lib/find-options'
buildTextEditor = require '../lib/build-text-editor'

describe "BufferSearch", ->
  [model, editor, markersListener, currentResultListener] = []

  beforeEach ->
    editor = buildTextEditor()
    spyOn(editor, 'scanInBufferRange').andCallThrough()

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

    findOptions = new FindOptions
    model = new BufferSearch(findOptions)

    markersListener = jasmine.createSpy('markersListener')
    model.onDidUpdate(markersListener)

    currentResultListener = jasmine.createSpy('currentResultListener')
    model.onDidChangeCurrentResult(currentResultListener)

    model.setEditor(editor)
    markersListener.reset()

    model.search "a+",
      caseSensitive: false
      useRegex: true
      wholeWord: false

  afterEach ->
    model.destroy()
    editor.destroy()

  getHighlightedRanges = ->
    ranges = []

    if editor.decorationsStateForScreenRowRange?
      for id, decoration of editor.decorationsStateForScreenRowRange(0, editor.getLineCount())
        if decoration.properties.class in ['find-result', 'current-result']
          ranges.push(decoration.screenRange)
    else
      for decoration in editor.getDecorations(type: 'highlight')
        marker = decoration.getMarker()
        if marker.isValid() and decoration.getProperties()['class'] in ['find-result', 'current-result']
          ranges.push(marker.getBufferRange())

    ranges
      .sort (a, b) -> a.compare(b)
      .map (range) -> range.serialize()

  expectUpdateEvent = ->
    expect(markersListener.callCount).toBe 1
    emittedMarkerRanges = markersListener
      .mostRecentCall.args[0]
      .map (marker) -> marker.getBufferRange().serialize()
    expect(emittedMarkerRanges).toEqual(getHighlightedRanges())
    markersListener.reset()

  expectNoUpdateEvent = ->
    expect(markersListener).not.toHaveBeenCalled()

  scannedRanges = ->
    args[1] for args in editor.scanInBufferRange.argsForCall

  it "highlights all the occurrences of the search regexp", ->
    expectUpdateEvent()
    expect(getHighlightedRanges()).toEqual [
      [[1, 0], [1, 3]]
      [[2, 4], [2, 7]]
      [[3, 8], [3, 11]]
      [[5, 0], [5, 3]]
      [[6, 4], [6, 7]]
      [[7, 8], [7, 11]]
    ]

    expect(scannedRanges()).toEqual [
      [[0, 0], [Infinity, Infinity]]
    ]

  describe "when the buffer changes", ->
    beforeEach ->
      markersListener.reset()
      editor.scanInBufferRange.reset()

    describe "when changes occur in the middle of the buffer", ->
      it "removes any invalidated search results and recreates markers in the changed regions", ->
        editor.setCursorBufferPosition([2, 5])
        editor.addCursorAtBufferPosition([6, 5])
        editor.insertText(".")
        editor.insertText(".")

        expectNoUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[7, 8], [7, 11]]
        ]

        advanceClock(editor.buffer.stoppedChangingDelay)

        expectUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 5]]
          [[2, 7], [2, 9]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 5]]
          [[6, 7], [6, 9]]
          [[7, 8], [7, 11]]
        ]

        expect(scannedRanges()).toEqual [
          [[1, 0], [3, 11]]
          [[5, 0], [7, 11]]
        ]

    describe "when changes occur within the first search result", ->
      it "rescans the buffer from the beginning to the first valid marker", ->
        editor.setCursorBufferPosition([1, 2])
        editor.insertText(".")
        editor.insertText(".")

        expectNoUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        advanceClock(editor.buffer.stoppedChangingDelay)

        expectUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 2]]
          [[1, 4], [1, 5]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        expect(scannedRanges()).toEqual [
          [[0, 0], [2, 7]]
        ]

    describe "when changes occur within the last search result", ->
      it "rescans the buffer from the last valid marker to the end", ->
        editor.setCursorBufferPosition([7, 9])
        editor.insertText(".")
        editor.insertText(".")

        expectNoUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
        ]

        advanceClock(editor.buffer.stoppedChangingDelay)

        expectUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 9]]
          [[7, 11], [7, 13]]
        ]

        expect(scannedRanges()).toEqual [
          [[6, 4], [Infinity, Infinity]]
        ]

    describe "when changes occur within two adjacent markers", ->
      it "rescans the changed region in a single scan", ->
        editor.setCursorBufferPosition([2, 5])
        editor.addCursorAtBufferPosition([3, 9])
        editor.insertText(".")
        editor.insertText(".")

        expectNoUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        advanceClock(editor.buffer.stoppedChangingDelay)

        expectUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 5]]
          [[2, 7], [2, 9]]
          [[3, 8], [3, 9]]
          [[3, 11], [3, 13]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        expect(scannedRanges()).toEqual [
          [[1, 0], [5, 3]]
        ]

    describe "when changes extend an existing search result", ->
      it "updates the results with the new extended ranges", ->
        editor.setCursorBufferPosition([2, 4])
        editor.addCursorAtBufferPosition([6, 7])
        editor.insertText("a")
        editor.insertText("a")

        expectNoUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 6], [2, 9]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        advanceClock(editor.buffer.stoppedChangingDelay)

        expectUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 9]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 9]]
          [[7, 8], [7, 11]]
        ]

    describe "when the changes are before any marker", ->
      it "doesn't change the markers", ->
        editor.setCursorBufferPosition([0, 3])
        editor.insertText("..")

        expectNoUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        advanceClock(editor.buffer.stoppedChangingDelay)

        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        expect(scannedRanges()).toEqual [
          [[0, 0], [1, 3]]
        ]

    describe "when the changes are between markers", ->
      it "doesn't change the markers", ->
        editor.setCursorBufferPosition([3, 1])
        editor.insertText("..")

        expectNoUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 10], [3, 13]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        advanceClock(editor.buffer.stoppedChangingDelay)

        expectUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 10], [3, 13]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        expect(scannedRanges()).toEqual [
          [[2, 4], [3, 13]]
        ]

    describe "when the changes are after all the markers", ->
      it "doesn't change the markers", ->
        editor.setCursorBufferPosition([8, 3])
        editor.insertText("..")

        expectNoUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        advanceClock(editor.buffer.stoppedChangingDelay)

        expectUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        expect(scannedRanges()).toEqual [
          [[7, 8], [Infinity, Infinity]]
        ]

    describe "when the changes are undone", ->
      it "recreates any temporarily-invalidated markers", ->
        editor.setCursorBufferPosition([2, 5])
        editor.insertText(".")
        editor.insertText(".")
        editor.backspace()
        editor.backspace()

        expectNoUpdateEvent()
        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        advanceClock(editor.buffer.stoppedChangingDelay)

        expect(getHighlightedRanges()).toEqual [
          [[1, 0], [1, 3]]
          [[2, 4], [2, 7]]
          [[3, 8], [3, 11]]
          [[5, 0], [5, 3]]
          [[6, 4], [6, 7]]
          [[7, 8], [7, 11]]
        ]

        expect(scannedRanges()).toEqual []

  describe "replacing a search result", ->
    beforeEach ->
      editor.scanInBufferRange.reset()

    it "replaces the marked text with the given string", ->
      markers = markersListener.mostRecentCall.args[0]
      markersListener.reset()

      editor.setSelectedBufferRange(markers[1].getBufferRange())
      expect(currentResultListener).toHaveBeenCalledWith(markers[1])
      currentResultListener.reset()

      model.replace([markers[1]], "new-text")

      expect(editor.getText()).toBe """
        -----------
        aaa bbb ccc
        ddd new-text bbb
        ccc ddd aaa
        -----------
        aaa bbb ccc
        ddd aaa bbb
        ccc ddd aaa
        -----------
      """

      expectUpdateEvent()
      expect(getHighlightedRanges()).toEqual [
        [[1, 0], [1, 3]]
        [[3, 8], [3, 11]]
        [[5, 0], [5, 3]]
        [[6, 4], [6, 7]]
        [[7, 8], [7, 11]]
      ]

      editor.setSelectedBufferRange(markers[2].getBufferRange())
      expect(currentResultListener).toHaveBeenCalledWith(markers[2])
      currentResultListener.reset()

      advanceClock(editor.buffer.stoppedChangingDelay)

      expectUpdateEvent()
      expect(getHighlightedRanges()).toEqual [
        [[1, 0], [1, 3]]
        [[3, 8], [3, 11]]
        [[5, 0], [5, 3]]
        [[6, 4], [6, 7]]
        [[7, 8], [7, 11]]
      ]
      expect(scannedRanges()).toEqual [
        [[1, 0], [3, 11]]
      ]

      expect(currentResultListener).toHaveBeenCalled()
      expect(currentResultListener.mostRecentCall.args[0].getBufferRange()).toEqual markers[2].getBufferRange()
      expect(currentResultListener.mostRecentCall.args[0].isDestroyed()).toBe false

  describe ".prototype.resultsMarkerLayerForTextEditor(editor)", ->
    it "creates or retrieves the results marker layer for the given editor", ->
      layer1 = model.resultsMarkerLayerForTextEditor(editor)

      return unless layer1 # remove this guard after 1.3.0 hits stable channel

      # basic check that this is the expected results layer
      expect(layer1.findMarkers().length).toBeGreaterThan(0)
      for marker in layer1.findMarkers()
        expect(editor.getTextInBufferRange(marker.getBufferRange())).toMatch /a+/

      editor2 = buildTextEditor()
      model.setEditor(editor2)
      layer2 = model.resultsMarkerLayerForTextEditor(editor2)

      model.setEditor(editor)
      expect(model.resultsMarkerLayerForTextEditor(editor)).toBe layer1
      expect(model.resultsMarkerLayerForTextEditor(editor2)).toBe layer2

      model.search "c+",
        caseSensitive: false
        useRegex: true
        wholeWord: false

      expect(layer1.findMarkers().length).toBeGreaterThan(0)
      for marker in layer1.findMarkers()
        expect(editor.getTextInBufferRange(marker.getBufferRange())).toMatch /c+/
