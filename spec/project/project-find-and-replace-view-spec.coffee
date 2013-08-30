RootView = require 'root-view'
FindAndReplace = require 'find-and-replace/lib/find'

describe 'ProjectFindAndReplaceView', ->
  [subject, previewList] = []
  beforeEach ->
    window.rootView = new RootView

    subject = FindAndReplace.activateForProject()
    previewList = subject.previewList

    rootView.trigger 'find-and-replace:display-find-in-project'

  afterEach ->
    FindAndReplace.deactivateForProject()

  describe "when running a search", ->
    it "runs a search and adds results to the preview list", ->
      waitsForPromise ->
        subject.findEditor.setText('so')
        subject.searchAndDisplayResults()

      runs ->
        expect(previewList.find('.search-result').length).toBeGreaterThan 0
