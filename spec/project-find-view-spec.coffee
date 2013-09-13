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

  describe "when core:cancel is triggered", ->
    beforeEach ->
      editor.trigger 'project-find:show'
      expect(projectFindView.find('.loading')).not.toBeVisible()
      projectFindView.focus()

    it "detaches from the root view", ->
      $(document.activeElement).trigger 'core:cancel'
      expect(rootView.find('.project-find')).not.toExist()
