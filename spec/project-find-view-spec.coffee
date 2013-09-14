path = require 'path'
$ = require 'jquery'
RootView = require 'root-view'
Project = require 'project'

describe 'ProjectFindView', ->
  [editor, projectFindView, searchPromise] = []

  beforeEach ->
    window.rootView = new RootView()
    rootView.open('sample.js')
    rootView.attachToDom()
    editor = rootView.getActiveView()
    pack = atom.activatePackage("find-and-replace")
    projectFindView = pack.mainModule.projectFindView

    spy = spyOn(projectFindView, 'confirm').andCallFake ->
      searchPromise = spy.originalValue.call(projectFindView)

  describe "when project-find:show is triggered", ->
    beforeEach ->
      projectFindView.findEditor.setText('items')

    it "attaches ProjectFindView to the root view", ->
      editor.trigger 'project-find:show'
      expect(rootView.find('.project-find')).toExist()
      expect(projectFindView.find('.preview-block')).not.toBeVisible()
      expect(projectFindView.find('.loading')).not.toBeVisible()
      expect(projectFindView.findEditor.getSelectedBufferRange()).toEqual [[0, 0], [0, 5]]

  describe "when core:cancel is triggered", ->
    beforeEach ->
      editor.trigger 'project-find:show'
      projectFindView.focus()

    it "detaches from the root view", ->
      $(document.activeElement).trigger 'core:cancel'
      expect(rootView.find('.project-find')).not.toExist()

  describe "serialization", ->
    it "serializes if the view is attached", ->
      expect(projectFindView.hasParent()).toBeFalsy()
      editor.trigger 'project-find:show'
      atom.deactivatePackage("find-and-replace")
      pack = atom.activatePackage("find-and-replace")
      projectFindView = pack.mainModule.projectFindView

      expect(projectFindView.hasParent()).toBeTruthy()

  describe "regex", ->
    beforeEach ->
      editor.trigger 'project-find:show'
      projectFindView.findEditor.setText('i(\\w)ems+')

    it "toggles regex option via an event and finds files matching the pattern", ->
      expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
      projectFindView.trigger 'project-find:toggle-regex-option'
      expect(projectFindView.regexOptionButton).toHaveClass('selected')

      waitsForPromise ->
        searchPromise

      runs ->
        projectFindView.previewList.scrollToBottom() # To load ALL the results
        expect(projectFindView.previewList.find("li > ul > li")).toHaveLength(13)
        expect(projectFindView.previewCount.text()).toBe "13 matches in 2 files"

    it "toggles regex option via a button and finds files matching the pattern", ->
      expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
      projectFindView.regexOptionButton.click()
      expect(projectFindView.regexOptionButton).toHaveClass('selected')

      waitsForPromise ->
        searchPromise

      runs ->
        projectFindView.previewList.scrollToBottom() # To load ALL the results
        expect(projectFindView.previewList.find("li > ul > li")).toHaveLength(13)
        expect(projectFindView.previewCount.text()).toBe "13 matches in 2 files"

  describe "case sensitivity", ->
    beforeEach ->
      editor.trigger 'project-find:show'
      projectFindView.findEditor.setText('C')

    it "toggles case sensitive option via an event and finds files matching the pattern", ->
      expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
      projectFindView.trigger 'project-find:toggle-case-option'
      expect(projectFindView.caseOptionButton).toHaveClass('selected')

      waitsForPromise ->
        searchPromise

      runs ->
        projectFindView.previewList.scrollToBottom() # To load ALL the results
        expect(projectFindView.previewList.find("li > ul > li")).toHaveLength(1)
        expect(projectFindView.previewCount.text()).toBe "1 match in 1 file"

    it "toggles case sensitive option via a button and finds files matching the pattern", ->
      expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
      projectFindView.caseOptionButton.click()
      expect(projectFindView.caseOptionButton).toHaveClass('selected')

      waitsForPromise ->
        searchPromise

      runs ->
        projectFindView.previewList.scrollToBottom() # To load ALL the results
        expect(projectFindView.previewList.find("li > ul > li")).toHaveLength(1)
        expect(projectFindView.previewCount.text()).toBe "1 match in 1 file"

  describe "when core:confirm is triggered", ->
    beforeEach ->
      rootView.trigger 'project-find:show'

    describe "when results exist", ->
      beforeEach ->
        projectFindView.findEditor.setText('items')

      it "displays the results and no errors", ->
        projectFindView.trigger 'core:confirm'

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.previewList).toBeVisible()
          projectFindView.previewList.scrollToBottom() # To load ALL the results
          expect(projectFindView.errorMessages).not.toBeVisible()
          expect(projectFindView.previewList.find("li > ul > li")).toHaveLength(13)
          expect(projectFindView.previewCount.text()).toBe "13 matches in 2 files"

    describe "when results exist", ->
      beforeEach ->
        projectFindView.findEditor.setText('notintheprojectbro')

      it "displays no errors and no results", ->
        projectFindView.trigger 'core:confirm'

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.errorMessages).not.toBeVisible()
          expect(projectFindView.previewList).toBeVisible()
          expect(projectFindView.previewList.find("li > ul > li")).toHaveLength(0)
