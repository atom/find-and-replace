RootView = require 'root-view'
SearchModel = require 'buffer-find-and-replace/lib/search-model'
SearchResultsModel = require 'buffer-find-and-replace/lib/search-results-model'

describe 'SearchResultsModel', ->
  [goToLine, editor, subject, buffer, searchModel] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    editor = rootView.getActiveView()
    buffer = editor.activeEditSession.buffer

    searchModel = new SearchModel()
    subject = new SearchResultsModel(searchModel, editor)

  describe "search()", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "finds all the matching ranges", ->
      expect(subject.markers.length).toEqual 6

    it "runs empty search when nothing searched for", ->
      searchModel.setPattern('')
      expect(subject.markers.length).toEqual 0
      expect(subject.getCurrentResult()).toEqual total: 0

    it "resets current result on new search", ->
      expect(subject.getCurrentResult()).toEqual total: 6

      subject.on 'current-result-changed', currentResultChangedHandler = jasmine.createSpy('currentResultChangedHandler')

      searchModel.setPattern('')
      expect(subject.getCurrentResult()).toEqual total: 0

      expect(currentResultChangedHandler).toHaveBeenCalled()

  describe "search() with options", ->
    beforeEach ->

    describe "regex option", ->
      it 'returns regex matches when on', ->
        searchModel.search('items.', regex: true)
        expect(subject.markers.length).toEqual 6

      it 'returns only literal matches when off', ->
        searchModel.search('items.', regex: false)
        expect(subject.markers.length).toEqual 4

    describe "inSelection option", ->
      it 'returns only matches in the current selection', ->
        editor.setSelectedBufferRange([[0,1],[3,15]])
        searchModel.search('items', inSelection: true)
        expect(subject.markers.length).toEqual 3

        editor.setSelectedBufferRange(subject.findNext().range)
        expect(editor.getSelectedBufferRange()).toEqual [[1,22],[1,27]]
        editor.setSelectedBufferRange(subject.findNext().range)
        expect(editor.getSelectedBufferRange()).toEqual [[2,8],[2,13]]
        expect(subject.markers.length).toEqual 3

      it 'handles multiple selections', ->
        editor.setSelectedBufferRange([[0,1],[3,15]])
        editor.addSelectionForBufferRange([[5,1],[9,5]])
        searchModel.search('items', inSelection: true)
        expect(subject.markers.length).toEqual 4

        editor.setSelectedBufferRange(subject.findNext().range)
        editor.setSelectedBufferRange(subject.findNext().range)
        editor.setSelectedBufferRange(subject.findNext().range)
        editor.setSelectedBufferRange(subject.findNext().range)
        expect(editor.getSelectedBufferRange()).toEqual [[5,16],[5,21]]
        expect(subject.markers.length).toEqual 4

      it 'handles empty selections', ->
        editor.setCursorBufferPosition([0,1])
        editor.addCursorAtBufferPosition([2,5])
        searchModel.search('items', inSelection: true)
        expect(subject.markers.length).toEqual 6

  describe "current result", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "findNext() sets the currentResult", ->
      subject.on 'current-result-changed', matchHandler = jasmine.createSpy()

      subject.findNext([[0,0],[0,3]])

      expect(matchHandler).toHaveBeenCalled()
      arg = matchHandler.mostRecentCall.args[0]

      expect(arg.index).toEqual 0
      expect(arg.range).toEqual [[1,22],[1,27]]
      expect(arg.total).toEqual 6

      arg = subject.getCurrentResult()
      expect(arg.index).toEqual 0
      expect(arg.range).toEqual [[1,22],[1,27]]
      expect(arg.total).toEqual 6

    it "a total change sets the currentResult", ->
      subject.on 'current-result-changed', matchHandler = jasmine.createSpy()

      buffer.insert([1, 10], "items")
      advanceClock(buffer.stoppedChangingDelay)

      expect(matchHandler).toHaveBeenCalled()
      arg = matchHandler.mostRecentCall.args[0]

      expect(arg.total).toEqual 7

    it "handles invalidation of the current result marker", ->
      subject.setCurrentResultIndex(0)
      expect(subject.getCurrentResult().index).toEqual 0

      subject.markers[0].bufferMarker.invalidate()

      expect(subject.getCurrentResult().index).not.toEqual 0

  describe "findNext()", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "finds next when before all ranges", ->
      range = subject.findNext([[0,0],[0,3]]).range
      expect(range).toEqual [[1,22],[1,27]]

    it "finds next when between ranges", ->
      range = subject.findNext([[2,22],[2,23]]).range
      expect(range).toEqual [[2,34],[2,39]]

    it "wraps when after all ranges", ->
      range = subject.findNext([[12,0],[12,0]]).range
      expect(range).toEqual [[1,22],[1,27]]

    it "finds proper next range when selection == range", ->
      range = subject.findNext([[1,22],[1,27]]).range
      expect(range).toEqual [[2,8],[2,13]]

    it "finds proper next range when selection inside of range", ->
      range = subject.findNext([[1,22],[1,25]]).range
      expect(range).toEqual [[2,8],[2,13]]

    it "can use the current selection", ->
      editor.setSelectedBufferRange([[2,22],[2,23]])
      range = subject.findNext().range
      expect(range).toEqual [[2,34],[2,39]]

  describe "findPrevious()", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "wraps to the end", ->
      range = subject.findPrevious([[0,0],[0,3]]).range
      expect(range).toEqual [[5,16],[5,21]]

    it "finds previous when between ranges", ->
      range = subject.findPrevious([[2,22],[2,23]]).range
      expect(range).toEqual [[2,8],[2,13]]

    it "finds proper previous range when selection == range", ->
      range = subject.findPrevious([[2,8],[2,13]]).range
      expect(range).toEqual [[1,22],[1,27]]

    it "finds proper previous range when selection inside of range", ->
      range = subject.findPrevious([[1,22],[1,25]]).range
      expect(range).toEqual [[5,16],[5,21]]

  describe "replaceCurrentResultAndFindNext()", ->
    describe "when there are matches", ->
      beforeEach ->
        searchModel.setPattern('items')

      it "will replace the first thing it can find from the specified current buffer range", ->
        result = subject.replaceCurrentResultAndFindNext('cats', [[2,22],[2,23]])
        expect(result.range).toEqual [[3,16],[3,21]]
        expect(result.total).toEqual 5

      it "will replace current result", ->
        result = subject.findNext([[0,0],[0,0]])
        result = subject.replaceCurrentResultAndFindNext('cats', [[10,2],[10,2]])
        expect(result.range).toEqual [[2,8],[2,13]]
        expect(result.total).toEqual 5
        expect(buffer.getTextInRange([[1,22],[1,27]])).toEqual 'cats)'

      it "will replace the last one and wrap to find the first", ->
        result = subject.findNext([[5,0],[5,0]])
        result = subject.replaceCurrentResultAndFindNext('cats', [[5,16],[5,21]])
        expect(result.range).toEqual [[1,22],[1,27]]
        expect(result.total).toEqual 5
        expect(buffer.getTextInRange([[5,16],[5,21]])).toEqual 'cats.'

    describe "when there are no matches", ->
      beforeEach ->
        searchModel.setPattern('nope, not there')

      it "doesn't break or replace anything", ->
        old = buffer.getText()
        result = subject.replaceCurrentResultAndFindNext('not gonna do it', [[5,16],[5,21]])
        expect(buffer.getText()).toEqual old
        expect(result).toEqual total: 0

  describe "replaceAll()", ->

    describe "when there are no matches", ->
      beforeEach ->
        searchModel.setPattern('nope, not there')

      it "doesn't break or replace anything", ->
        old = buffer.getText()
        expect(subject.replaceAll('not gonna do it')).toEqual false
        expect(buffer.getText()).toEqual old

    describe "when there are matches", ->
      beforeEach ->
        searchModel.setPattern('items')

      it "will replace all and rerun the search", ->
        subject.findNext([[0,0],[0,0]])
        subject.replaceAll('cats')

        expect(subject.getCurrentResult()).toEqual total: 0
        expect(subject.markers.length).toEqual 0

      it "will replace all and find matches within the replacement", ->
        subject.findNext([[0,0],[0,0]])
        expect(subject.replaceAll('itemsandthings')).toEqual true
        expect(subject.getCurrentResult()).toEqual total: 6

  describe "cursor moving", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "moving cursor into result sets the current result", ->
      editor.setCursorBufferPosition([1,23])
      subject.onCursorMoved()

      expect(subject.currentResultIndex).toEqual 0

      editor.setCursorBufferPosition([1,10])
      subject.onCursorMoved()

      expect(subject.currentResultIndex).toEqual null

      editor.setCursorBufferPosition([2,10])
      subject.onCursorMoved()

      expect(subject.currentResultIndex).toEqual 1

    it "finding next finds the correct match", ->
      editor.setCursorBufferPosition([2,0])
      subject.selectNextResult()
      subject.onCursorMoved() # will happen in the app behind a timeout, doing it manually here. 

      expect(subject.currentResultIndex).toEqual 1

  describe "buffer modification", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "ranges move with the update", ->
      buffer.insert([1, 0], "xxx")
      advanceClock(buffer.stoppedChangingDelay)

      range = subject.findNext([[0,0],[0,3]]).range
      expect(range).toEqual [[1,25],[1,30]]

    it "will not return an invalid result until revalidated", ->
      buffer.insert([1, 23], "o")
      advanceClock(buffer.stoppedChangingDelay)

      result = subject.findNext([[0,0],[0,3]])
      expect(result.range).toEqual [[2,8],[2,13]]
      expect(result.total).toEqual 5

      buffer.delete([[1, 23], [1, 24]])
      advanceClock(buffer.stoppedChangingDelay)

      result = subject.findNext([[0,0],[0,3]])
      expect(result.total).toEqual 6
      expect(result.range).toEqual [[1,22],[1,27]]

    it "invalidation changes the total, and will emit an event", ->
      subject.on 'current-result-changed', handler = jasmine.createSpy()

      buffer.insert([1, 23], "o")
      advanceClock(buffer.stoppedChangingDelay)

      expect(handler).toHaveBeenCalled()
      result = handler.mostRecentCall.args[0]

      expect(result.total).toEqual 5
      
    it "adds a new marker for a new result added into the buffer", ->
      subject.on 'markers-added', addHandler = jasmine.createSpy()

      buffer.insert([1, 10], "items")
      advanceClock(buffer.stoppedChangingDelay)

      expect(subject.markers.length).toEqual 7
      expect(addHandler).toHaveBeenCalled()

      range = subject.findNext([[0,0],[0,3]]).range
      expect(range).toEqual [[1,10],[1,15]]

      range = subject.findNext([[1,20],[1,20]]).range
      expect(range).toEqual [[1,27],[1,32]]

  describe "handling editor events", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "handles the find-next event", ->
      editor.setSelectedBufferRange([[2,22],[2,23]])
      editor.trigger('find-and-replace:find-next')
      expect(editor.getSelectedBufferRange()).toEqual [[2,34],[2,39]]

    it "handles the find-previous event", ->
      editor.setSelectedBufferRange([[2,40],[2,40]])
      range = editor.trigger('find-and-replace:find-previous')
      expect(editor.getSelectedBufferRange()).toEqual [[2,34],[2,39]]
