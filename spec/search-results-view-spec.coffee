RootView = require 'root-view'
SearchModel = require 'search-in-buffer/lib/search-model'
SearchResultsModel = require 'search-in-buffer/lib/search-results-model'
SearchResultsView = require 'search-in-buffer/lib/search-results-view'

fdescribe 'SearchResultsView', ->
  [goToLine, editor, subject, buffer, searchModel] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    editor = rootView.getActiveView()
    buffer = editor.activeEditSession.buffer

    searchModel = new SearchModel()
    subject = new SearchResultsView(searchModel, editor)

  describe "searching marks the results", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "marks all ranges", ->
      expect(subject.searchResults.length).toEqual 6
