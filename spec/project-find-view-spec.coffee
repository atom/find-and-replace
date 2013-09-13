path = require 'path'
$ = require 'jquery'
RootView = require 'root-view'
Project = require 'project'

describe 'ProjectFindView', ->
  [editor, projectFindView] = []

  beforeEach ->
    window.rootView = new RootView()
    rootView.open('sample.js')
    rootView.attachToDom()
    editor = rootView.getActiveView()
    pack = atom.activatePackage("find-and-replace")
    projectFindView = pack.mainModule.projectFindView

  describe "when project-find:show is triggered", ->
    it "attaches ProjectFindView to the root view", ->
      editor.trigger 'project-find:show'
      expect(rootView.find('.project-find')).toExist()
      expect(projectFindView.find('.preview-block')).not.toBeVisible()
      expect(projectFindView.find('.loading')).not.toBeVisible()

  describe "when core:cancel is triggered", ->
    beforeEach ->
      editor.trigger 'project-find:show'
      projectFindView.focus()

    it "detaches from the root view", ->
      $(document.activeElement).trigger 'core:cancel'
      expect(rootView.find('.project-find')).not.toExist()

  describe "when core:confirm is triggered", ->
    describe "when results exist", ->
      beforeEach ->
        projectFindView.findEditor.setText('items')

      it "displays the results", ->
        waitsForPromise ->
          projectFindView.confirm()

        runs ->
          expect(projectFindView.previewList.find("li > ul > li")).toHaveLength(13)
          expect(projectFindView.previewCount.text()).toBe "13 matches in 2 files"
