RootView = require 'root-view'
SearchModel = require 'buffer-find-and-replace/lib/search-model'
SearchResultsModel = require 'buffer-find-and-replace/lib/search-results-model'
SearchResultsView = require 'buffer-find-and-replace/lib/search-results-view'

describe 'SearchResultsView', ->
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
      searchModel.showResults()

    it "marks all ranges", ->
      expect(subject.children().length).toEqual 6
      expect(subject.markerViews.length).toEqual 6

    it "cleans up after itself", ->
      searchModel.setPattern('notinthefilebro')
      expect(subject.children().length).toEqual 0
      expect(subject.markerViews.length).toEqual 0

  describe "search model activation", ->
    beforeEach ->
      searchModel.setPattern('items')

    it "creates views when shown", ->
      expect(subject.children().length).toEqual 0
      expect(subject.markerViews.length).toEqual 0

      searchModel.showResults()

      expect(subject.children().length).toEqual 6
      expect(subject.markerViews.length).toEqual 6

    it "showResults() shows the results view", ->
      spyOn subject, 'show'
      searchModel.showResults()
      expect(subject.show).toHaveBeenCalled()

    it "hideResults() hides the results view and removes all the marker views", ->
      searchModel.showResults()
      spyOn subject, 'hide'
      searchModel.hideResults()
      expect(subject.hide).toHaveBeenCalled()

      expect(subject.children().length).toEqual 0
      expect(subject.markerViews.length).toEqual 0
