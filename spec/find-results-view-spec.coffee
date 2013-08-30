RootView = require 'root-view'
FindModel = require 'find-and-replace/lib/find-model'
FindResultsView = require 'find-and-replace/lib/find-results-view'

describe 'FindResultsView', ->
  [goToLine, editor, subject, buffer, searchModel] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    editor = rootView.getActiveView()
    buffer = editor.activeEditSession.buffer

    searchModel = new FindModel()
    subject = new FindResultsView(searchModel, editor)

  describe "searching marks the results", ->
    beforeEach ->
      searchModel.setPattern('items')
      subject.setActive(true)

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

      subject.setActive(true)

      expect(subject.children().length).toEqual 6
      expect(subject.markerViews.length).toEqual 6

    it "showResults() shows the results view", ->
      spyOn subject, 'show'
      subject.setActive(true)
      expect(subject.show).toHaveBeenCalled()

    it "hide() hides the results view and removes all the marker views", ->
      subject.setActive(true)
      spyOn(subject, 'hide').andCallThrough()
      subject.setActive(false)
      expect(subject.hide).toHaveBeenCalled()

      expect(subject.children().length).toEqual 0
      expect(subject.markerViews.length).toEqual 0

    describe "with inactive panes", ->
      it "hides with inactive pane but active view", ->
        editor.getPane().makeInactive()
        subject.setActive(true)

        expect(subject.children().length).toEqual 0
        expect(subject.markerViews.length).toEqual 0

        editor.getPane().makeActive()

        expect(subject.children().length).toEqual 6
        expect(subject.markerViews.length).toEqual 6

      it "inactive view, pane becomes active", ->
        editor.getPane().makeInactive()
        editor.getPane().makeActive()

        expect(subject.children().length).toEqual 0
        expect(subject.markerViews.length).toEqual 0

        subject.setActive(true)

        expect(subject.children().length).toEqual 6
        expect(subject.markerViews.length).toEqual 6
