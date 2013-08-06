RootView = require 'root-view'
BufferSearch = require 'search-in-buffer/lib/buffer-search'
BufferSearchView = require 'search-in-buffer/lib/buffer-search-view'

fdescribe 'BufferSearchView', ->
  [goToLine, editor, subject, buffer, bufferSearch] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    editor = rootView.getActiveView()
    buffer = editor.activeEditSession.buffer

    bufferSearch = new BufferSearch()
    subject = new BufferSearchView(bufferSearch, {editor})

  describe "searching marks the results", ->
    beforeEach ->
      bufferSearch.search(buffer, 'items')

    it "marks all ranges", ->
      expect(subject.searchResults.length).toEqual 6
