RootView = require 'root-view'
SearchModel = require 'search-in-buffer/lib/search-model'
SearchResultsModel = require 'search-in-buffer/lib/search-results-model'

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

      searchModel.setPattern('')
      expect(subject.getCurrentResult()).toEqual total: 0

  describe "search() with options", ->
    beforeEach ->

    describe "regex option", ->
      it 'returns regex matches when on', ->
        searchModel.search('items.', regex: true)
        expect(subject.markers.length).toEqual 6

      it 'returns only literal matches when off', ->
        searchModel.search('items.', regex: false)
        expect(subject.markers.length).toEqual 4

  describe "current result", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "findNext() sets the currentResult", ->
      subject.on 'change:current-result', matchHandler = jasmine.createSpy()

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
      subject.on 'change:current-result', matchHandler = jasmine.createSpy()

      buffer.insert([1, 10], "items")
      advanceClock(buffer.stoppedChangingDelay+2)

      expect(matchHandler).toHaveBeenCalled()
      arg = matchHandler.mostRecentCall.args[0]

      expect(arg.total).toEqual 7

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

  describe "buffer modification", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "ranges move with the update", ->
      buffer.insert([1, 0], "xxx")
      advanceClock(buffer.stoppedChangingDelay+2)

      range = subject.findNext([[0,0],[0,3]]).range
      expect(range).toEqual [[1,25],[1,30]]

    it "will not return an invalid result until revalidated", ->
      buffer.insert([1, 23], "o")
      advanceClock(buffer.stoppedChangingDelay+2)

      result = subject.findNext([[0,0],[0,3]])
      expect(result.range).toEqual [[2,8],[2,13]]
      expect(result.total).toEqual 5

      buffer.delete([[1, 23], [1, 24]])
      advanceClock(buffer.stoppedChangingDelay+2)

      result = subject.findNext([[0,0],[0,3]])
      expect(result.total).toEqual 6
      expect(result.range).toEqual [[1,22],[1,27]]
      
    it "adds a new marker for a new result added into the buffer", ->
      subject.on 'add:markers', addHandler = jasmine.createSpy()

      buffer.insert([1, 10], "items")
      advanceClock(buffer.stoppedChangingDelay+2)

      expect(subject.markers.length).toEqual 7
      expect(addHandler).toHaveBeenCalled()

      range = subject.findNext([[0,0],[0,3]]).range
      expect(range).toEqual [[1,10],[1,15]]

      range = subject.findNext([[1,20],[1,20]]).range
      expect(range).toEqual [[1,27],[1,32]]

