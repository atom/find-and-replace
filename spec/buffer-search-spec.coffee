RootView = require 'root-view'
BufferSearch = require 'search-in-buffer/lib/buffer-search'

fdescribe 'BufferSearch', ->
  [goToLine, editor, subject, buffer] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    editor = rootView.getActiveView()
    buffer = editor.activeEditSession.buffer

    subject = new BufferSearch()

  describe "search()", ->
    it "finds all the matching ranges", ->
      subject.search(buffer, 'items')
      expect(subject.ranges.length).toEqual 6

  describe "findNext()", ->
    beforeEach ->
      subject.search(buffer, 'items')

    it "finds next when before all ranges", ->
      range = subject.findNext([[0,0],[0,3]])
      expect(range).toEqual [[1,22],[1,27]]

    it "finds next when between ranges", ->
      range = subject.findNext([[2,22],[2,23]])
      expect(range).toEqual [[2,34],[2,39]]

    it "wraps when after all ranges", ->
      range = subject.findNext([[12,0],[12,0]])
      expect(range).toEqual [[1,22],[1,27]]

    it "finds proper next range when selection == range", ->
      range = subject.findNext([[1,22],[1,27]])
      expect(range).toEqual [[2,8],[2,13]]

    it "finds proper next range when selection inside of range", ->
      range = subject.findNext([[1,22],[1,25]])
      expect(range).toEqual [[2,8],[2,13]]