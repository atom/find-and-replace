RootView = require 'root-view'
FindModel = require 'find-and-replace/lib/find-model'
FindResultsView = require 'find-and-replace/lib/find-results-view'

$ = require('jquery')

describe 'FindResultsView', ->
  [goToLine, editor, buffer, findModel, findResultsView] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    pack = atom.activatePackage("find-and-replace")
    {findModel, findResultsView} = pack.mainModule
    editor = rootView.getActiveView()
    buffer = editor.activeEditSession.buffer

  describe "finding", ->
    beforeEach ->
      findModel.setPattern('items')
      findModel.search()

    it "marks all ranges", ->
      expect(findResultsView.parent()[0]).toBe editor.underlayer[0]
      expect(findResultsView.children().length).toEqual 6
      expect(findResultsView.markerViews.length).toEqual 6

    it "removes old marker views", ->
      findModel.setPattern('notinthefilebro')
      findModel.search()
      expect(findResultsView.children().length).toEqual 0
      expect(findResultsView.markerViews.length).toEqual 0

  describe "search model activation", ->
    beforeEach ->
      findModel.setPattern('items')

    it "creates views when shown", ->
      expect(findResultsView.children().length).toEqual 0
      expect(findResultsView.markerViews.length).toEqual 0

      findResultsView.setActive(true)

      expect(findResultsView.children().length).toEqual 6
      expect(findResultsView.markerViews.length).toEqual 6

    it "showResults() shows the results view", ->
      spyOn findResultsView, 'show'
      findResultsView.setActive(true)
      expect(findResultsView.show).toHaveBeenCalled()

    it "hide() hides the results view and removes all the marker views", ->
      findResultsView.setActive(true)
      spyOn(findResultsView, 'hide').andCallThrough()
      findResultsView.setActive(false)
      expect(findResultsView.hide).toHaveBeenCalled()

      expect(findResultsView.children().length).toEqual 0
      expect(findResultsView.markerViews.length).toEqual 0

    describe "with inactive panes", ->
      it "hides with inactive pane but active view", ->
        editor.getPane().makeInactive()
        findResultsView.setActive(true)

        expect(findResultsView.children().length).toEqual 0
        expect(findResultsView.markerViews.length).toEqual 0

        editor.getPane().makeActive()

        expect(findResultsView.children().length).toEqual 6
        expect(findResultsView.markerViews.length).toEqual 6

      it "inactive view, pane becomes active", ->
        editor.getPane().makeInactive()
        editor.getPane().makeActive()

        expect(findResultsView.children().length).toEqual 0
        expect(findResultsView.markerViews.length).toEqual 0

        findResultsView.setActive(true)

        expect(findResultsView.children().length).toEqual 6
        expect(findResultsView.markerViews.length).toEqual 6
