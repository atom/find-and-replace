os = require 'os'
path = require 'path'
temp = require 'temp'

_ = require 'underscore-plus'
{$, View} = require 'atom-space-pen-views'
fs = require 'fs-plus'

ResultsPaneView = require '../lib/project/results-pane'

# Default to 30 second promises
waitsForPromise = (fn) -> window.waitsForPromise timeout: 30000, fn

describe 'ProjectFindView', ->
  [activationPromise, editor, editorView, projectFindView, searchPromise, resultsPane, workspaceElement, mainModule] = []

  getAtomPanel = ->
    workspaceElement.querySelector('.project-find').parentNode

  getExistingResultsPane = ->
    pane = atom.workspace.paneForURI(ResultsPaneView.URI)
    return pane.itemForURI(ResultsPaneView.URI) if pane?
    null

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    atom.project.setPaths([path.join(__dirname, 'fixtures')])
    jasmine.attachToDOM(workspaceElement)

    atom.config.set('find-and-replace.openProjectFindResultsInRightPane', false)
    activationPromise = atom.packages.activatePackage("find-and-replace").then (options) ->
      mainModule = options.mainModule
      mainModule.createViews()
      {projectFindView} = mainModule
      spy = spyOn(projectFindView, 'search').andCallFake ->
        searchPromise = spy.originalValue.apply(projectFindView, arguments)
        resultsPane = $(workspaceElement).find('.preview-pane').view()
        searchPromise

  describe "when project-find:show is triggered", ->
    it "attaches ProjectFindView to the root view", ->
      atom.commands.dispatch(workspaceElement, 'project-find:show')

      waitsForPromise ->
        activationPromise

      runs ->
        projectFindView.findEditor.setText('items')

        expect(getAtomPanel()).toBeVisible()
        expect(projectFindView.find('.preview-block')).not.toBeVisible()
        expect(projectFindView.find('.loading')).not.toBeVisible()
        expect(projectFindView.findEditor.getModel().getSelectedBufferRange()).toEqual [[0, 0], [0, 5]]

    describe "with an open buffer", ->
      editor = null

      beforeEach ->
        atom.commands.dispatch(workspaceElement, 'project-find:show')

        waitsForPromise ->
          activationPromise

        runs ->
          projectFindView.findEditor.setText('')

        waitsForPromise ->
          atom.workspace.open('sample.js').then (o) -> editor = o

      it "populates the findEditor with selection when there is a selection", ->
        editor.setSelectedBufferRange([[2, 8], [2, 13]])
        atom.commands.dispatch(workspaceElement, 'project-find:show')
        expect(getAtomPanel()).toBeVisible()
        expect(projectFindView.findEditor.getText()).toBe('items')

        editor.setSelectedBufferRange([[2, 14], [2, 20]])
        atom.commands.dispatch(workspaceElement, 'project-find:show')
        expect(getAtomPanel()).toBeVisible()
        expect(projectFindView.findEditor.getText()).toBe('length')

      it "populates the findEditor with the previous selection when there is no selection", ->
        editor.setSelectedBufferRange([[2, 14], [2, 20]])
        atom.commands.dispatch(workspaceElement, 'project-find:show')
        expect(getAtomPanel()).toBeVisible()
        expect(projectFindView.findEditor.getText()).toBe('length')

        editor.setSelectedBufferRange([[2, 30], [2, 30]])
        atom.commands.dispatch(workspaceElement, 'project-find:show')
        expect(getAtomPanel()).toBeVisible()
        expect(projectFindView.findEditor.getText()).toBe('length')

      it "places selected text into the find editor and escapes it when Regex is enabled", ->
        atom.commands.dispatch(projectFindView[0], 'project-find:toggle-regex-option')
        editor.setSelectedBufferRange([[6, 6], [6, 65]])
        atom.commands.dispatch(workspaceElement, 'project-find:show')
        expect(projectFindView.findEditor.getText()).toBe 'current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);'

    describe "when the ProjectFindView is already attached", ->
      beforeEach ->
        atom.commands.dispatch(workspaceElement, 'project-find:show')

        waitsForPromise ->
          activationPromise

        runs ->
          projectFindView.findEditor.setText('items')
          projectFindView.findEditor.getModel().setSelectedBufferRange([[0, 0], [0, 0]])

      it "focuses the find editor and selects all the text", ->
        atom.commands.dispatch(workspaceElement, 'project-find:show')
        expect(projectFindView.findEditor).toHaveFocus()
        expect(projectFindView.findEditor.getModel().getSelectedText()).toBe "items"

    it "honors config settings for find options", ->
      atom.config.set('find-and-replace.useRegex', true)
      atom.config.set('find-and-replace.caseSensitive', true)
      atom.config.set('find-and-replace.wholeWord', true)

      atom.commands.dispatch(workspaceElement, 'project-find:show')

      waitsForPromise ->
        activationPromise

      runs ->
        expect(projectFindView.caseOptionButton).toHaveClass 'selected'
        expect(projectFindView.regexOptionButton).toHaveClass 'selected'
        expect(projectFindView.wholeWordOptionButton).toHaveClass 'selected'

  describe "when project-find:toggle is triggered", ->
    it "toggles the visibility of the ProjectFindView", ->
      atom.commands.dispatch(workspaceElement, 'project-find:toggle')

      waitsForPromise ->
        activationPromise

      runs ->
        expect(getAtomPanel()).toBeVisible()
        atom.commands.dispatch(workspaceElement, 'project-find:toggle')
        expect(getAtomPanel()).not.toBeVisible()

  describe "when project-find:show-in-current-directory is triggered", ->
    [nested, tree, projectPath] = []

    class DirElement extends View
      @content: (path) ->
        @div class: 'directory', =>
          @div class: 'nested-thing', =>
            @span outlet: 'name', class: 'name', 'data-path': path, path
            @ul outlet: 'files', class: 'files'
      initialize: (@path) ->
      createFiles: (names) ->
        for name in names
          @files.append(new FileElement(path.join(@path, name), name))

    class FileElement extends View
      @content: (path, name) ->
        @li class: 'file', 'data-path': path, =>
          @span outlet: 'name', class: 'name', name
      initialize: (path) ->
        fs.writeFileSync(path, '')

    beforeEach ->
      projectPath = temp.mkdirSync("atom")
      atom.project.setPaths([projectPath])
      p = atom.project.getPaths()[0]
      tree = new DirElement(p)
      tree.createFiles(['one.js', 'two.js'])

      nested = new DirElement(path.join(p, 'nested'))
      nested.createFiles(['another.js'])

      tree.files.append(nested)
      workspaceElement.appendChild(tree[0])

    it "populates the pathsEditor when triggered with a directory", ->
      atom.commands.dispatch nested.name[0], 'project-find:show-in-current-directory'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(getAtomPanel()).toBeVisible()
        expect(projectFindView.pathsEditor.getText()).toBe('nested')
        expect(projectFindView.findEditor).toHaveFocus()

        atom.commands.dispatch tree.name[0], 'project-find:show-in-current-directory'
        expect(projectFindView.pathsEditor.getText()).toBe('')

    it "populates the pathsEditor when triggered on a directory's name", ->
      atom.commands.dispatch nested[0], 'project-find:show-in-current-directory'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(getAtomPanel()).toBeVisible()
        expect(projectFindView.pathsEditor.getText()).toBe('nested')
        expect(projectFindView.findEditor).toHaveFocus()

        atom.commands.dispatch tree.name[0], 'project-find:show-in-current-directory'
        expect(projectFindView.pathsEditor.getText()).toBe('')

    it "populates the pathsEditor when triggered on a file", ->
      atom.commands.dispatch nested.files.find('> .file:eq(0)').view().name[0], 'project-find:show-in-current-directory'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(getAtomPanel()).toBeVisible()
        expect(projectFindView.pathsEditor.getText()).toBe('nested')
        expect(projectFindView.findEditor).toHaveFocus()

        atom.commands.dispatch tree.files.find('> .file:eq(0)').view().name[0], 'project-find:show-in-current-directory'
        expect(projectFindView.pathsEditor.getText()).toBe('')

    describe "when there are multiple root directories", ->
      beforeEach ->
        atom.project.addPath(temp.mkdirSync("another-path-"))

      it "includes the basename of the containing root directory in the paths-editor", ->
        atom.commands.dispatch nested.files.find('> .file:eq(0)').view().name[0], 'project-find:show-in-current-directory'

        waitsForPromise ->
          activationPromise

        runs ->
          expect(getAtomPanel()).toBeVisible()
          expect(projectFindView.pathsEditor.getText()).toBe(path.join(path.basename(projectPath), 'nested'))

  describe "finding", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample.js')

      runs ->
        editor = atom.workspace.getActiveTextEditor()
        editorView = atom.views.getView(editor)
        atom.commands.dispatch(workspaceElement, 'project-find:show')

      waitsForPromise ->
        activationPromise

    describe "when the find string contains an escaped char", ->
      beforeEach ->
        projectPath = temp.mkdirSync("atom")
        fs.writeFileSync(path.join(projectPath, "tabs.txt"), "\t\n\\\t\n\\\\t")
        atom.project.setPaths([projectPath])
        atom.commands.dispatch(workspaceElement, 'project-find:show')

      describe "when regex seach is enabled", ->
        it "finds a literal tab character", ->
          atom.commands.dispatch(projectFindView[0], 'project-find:toggle-regex-option')
          projectFindView.findEditor.setText('\\t')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          waitsForPromise ->
            searchPromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView
            expect(resultsView).toBeVisible()
            expect(resultsView.find("li > ul > li")).toHaveLength(2)

      describe "when regex seach is disabled", ->
        it "finds the escape char", ->
          projectFindView.findEditor.setText('\\t')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          waitsForPromise ->
            searchPromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView
            expect(resultsView).toBeVisible()
            expect(resultsView.find("li > ul > li")).toHaveLength(1)

        it "finds a backslash", ->
          projectFindView.findEditor.setText('\\')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          waitsForPromise ->
            searchPromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView
            expect(resultsView).toBeVisible()
            expect(resultsView.find("li > ul > li")).toHaveLength(3)

        it "doesn't insert a escaped char if there are multiple backslashs in front of the char", ->
          projectFindView.findEditor.setText('\\\\t')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          waitsForPromise ->
            searchPromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView
            expect(resultsView).toBeVisible()
            expect(resultsView.find("li > ul > li")).toHaveLength(1)

    describe "when core:cancel is triggered", ->
      beforeEach ->
        atom.commands.dispatch(workspaceElement, 'project-find:show')
        projectFindView.focus()

      it "detaches from the root view", ->
        atom.commands.dispatch(document.activeElement, 'core:cancel')
        expect(getAtomPanel()).not.toBeVisible()

    describe "when close option is true", ->
      beforeEach ->
        atom.config.set('find-and-replace.closeFindPanelAfterSearch', true)
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

      it "close the panel after search", ->
        waitsForPromise ->
          searchPromise
        runs ->
          expect(getAtomPanel()).not.toBeVisible()

    describe "splitting into a second pane", ->
      beforeEach ->
        workspaceElement.style.height = '1000px'
        atom.commands.dispatch editorView, 'project-find:show'

      it "splits when option is true", ->
        initialPane = atom.workspace.getActivePane()
        atom.config.set('find-and-replace.openProjectFindResultsInRightPane', true)
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          pane1 = atom.workspace.getActivePane()
          expect(pane1).not.toBe initialPane

      it "does not split when option is false", ->
        initialPane = atom.workspace.getActivePane()
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          pane1 = atom.workspace.getActivePane()
          expect(pane1).toBe initialPane

      it "can be duplicated", ->
        atom.config.set('find-and-replace.openProjectFindResultsInRightPane', true)
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          resultsPaneView1 = atom.views.getView(getExistingResultsPane())
          pane1 = atom.workspace.getActivePane()
          pane1.splitRight(copyActiveItem: true)

          pane2 = atom.workspace.getActivePane()
          resultsPaneView2 = atom.views.getView(pane2.itemForURI(ResultsPaneView.URI))

          expect(pane1).not.toBe pane2
          expect(resultsPaneView1).not.toBe resultsPaneView2

          length = resultsPaneView1.querySelectorAll('li > ul > li').length
          expect(length).toBeGreaterThan 0
          expect(resultsPaneView2.querySelectorAll('li > ul > li')).toHaveLength length

          expect(resultsPaneView2.querySelector('.preview-count').innerHTML).toEqual resultsPaneView1.querySelector('.preview-count').innerHTML

    describe "serialization", ->
      it "serializes if the case, regex and whole word options", ->
        atom.commands.dispatch editorView, 'project-find:show'
        expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
        projectFindView.caseOptionButton.click()
        expect(projectFindView.caseOptionButton).toHaveClass('selected')

        expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
        projectFindView.regexOptionButton.click()
        expect(projectFindView.regexOptionButton).toHaveClass('selected')

        expect(projectFindView.wholeWordOptionButton).not.toHaveClass('selected')
        projectFindView.wholeWordOptionButton.click()
        expect(projectFindView.wholeWordOptionButton).toHaveClass('selected')

        atom.packages.deactivatePackage("find-and-replace")

        activationPromise = atom.packages.activatePackage("find-and-replace").then ({mainModule}) ->
          mainModule.createViews()
          {projectFindView} = mainModule

        atom.commands.dispatch editorView, 'project-find:show'

        waitsForPromise ->
          activationPromise

        runs ->
          expect(projectFindView.caseOptionButton).toHaveClass('selected')
          expect(projectFindView.regexOptionButton).toHaveClass('selected')
          expect(projectFindView.wholeWordOptionButton).toHaveClass('selected')

    describe "description label", ->
      beforeEach ->
        atom.commands.dispatch editorView, 'project-find:show'

      it "indicates that it's searching, then shows the results", ->
        projectFindView.findEditor.setText('item')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          projectFindView.showResultPane()

        runs ->
          expect(projectFindView.descriptionLabel.text()).toContain 'Searching...'

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.descriptionLabel.text()).toContain '13 results found in 2 files'
          atom.commands.dispatch(projectFindView[0], 'core:confirm')
          expect(projectFindView.descriptionLabel.text()).toContain '13 results found in 2 files'

      it "shows an error when the pattern is invalid and clears when no error", ->
        spyOn(atom.workspace, 'scan').andReturn Promise.resolve()
        atom.commands.dispatch(projectFindView[0], 'project-find:toggle-regex-option')
        projectFindView.findEditor.setText('[')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.descriptionLabel).toHaveClass('text-error')
          expect(projectFindView.descriptionLabel.text()).toContain('Invalid regular expression')

          projectFindView.findEditor.setText('')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          expect(projectFindView.descriptionLabel).not.toHaveClass('text-error')
          expect(projectFindView.descriptionLabel.text()).toContain('Find in Project')

          projectFindView.findEditor.setText('items')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.descriptionLabel).not.toHaveClass('text-error')
          expect(projectFindView.descriptionLabel.text()).toContain('items')

    describe "regex", ->
      beforeEach ->
        atom.commands.dispatch editorView, 'project-find:show'
        projectFindView.findEditor.setText('i(\\w)ems+')
        spyOn(atom.workspace, 'scan').andCallFake -> Promise.resolve()

      it "escapes regex patterns by default", ->
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(atom.workspace.scan.argsForCall[0][0]).toEqual /i\(\\w\)ems\+/gi

      it "shows an error when the regex pattern is invalid", ->
        atom.commands.dispatch(projectFindView[0], 'project-find:toggle-regex-option')
        projectFindView.findEditor.setText('[')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.descriptionLabel).toHaveClass('text-error')

      describe "when search has not been run yet", ->
        it "toggles regex option via an event but does not run the search", ->
          expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
          atom.commands.dispatch(projectFindView[0], 'project-find:toggle-regex-option')
          expect(projectFindView.regexOptionButton).toHaveClass('selected')
          expect(atom.workspace.scan).not.toHaveBeenCalled()

      describe "when search has been run", ->
        beforeEach ->
          atom.commands.dispatch(projectFindView[0], 'core:confirm')
          waitsForPromise -> searchPromise

        it "toggles regex option via an event and finds files matching the pattern", ->
          expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
          atom.commands.dispatch(projectFindView[0], 'project-find:toggle-regex-option')

          waitsForPromise ->
            searchPromise

          runs ->
            expect(projectFindView.regexOptionButton).toHaveClass('selected')
            expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual /i(\w)ems+/gi

        it "toggles regex option via a button and finds files matching the pattern", ->
          expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
          projectFindView.regexOptionButton.click()

          waitsForPromise ->
            searchPromise

          runs ->
            expect(projectFindView.regexOptionButton).toHaveClass('selected')
            expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual /i(\w)ems+/gi

    describe "case sensitivity", ->
      beforeEach ->
        atom.commands.dispatch editorView, 'project-find:show'
        spyOn(atom.workspace, 'scan').andCallFake -> Promise.resolve()
        projectFindView.findEditor.setText('ITEMS')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')
        waitsForPromise -> searchPromise

      it "runs a case insensitive search by default", ->
        expect(atom.workspace.scan.argsForCall[0][0]).toEqual /ITEMS/gi

      it "toggles case sensitive option via an event and finds files matching the pattern", ->
        expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
        atom.commands.dispatch(projectFindView[0], 'project-find:toggle-case-option')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.caseOptionButton).toHaveClass('selected')
          expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual /ITEMS/g

      it "toggles case sensitive option via a button and finds files matching the pattern", ->
        expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
        projectFindView.caseOptionButton.click()

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.caseOptionButton).toHaveClass('selected')
          expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual /ITEMS/g

    describe "whole word", ->
      beforeEach ->
        atom.commands.dispatch editorView, 'project-find:show'
        spyOn(atom.workspace, 'scan').andCallFake -> Promise.resolve()
        projectFindView.findEditor.setText('wholeword')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')
        waitsForPromise -> searchPromise

      it "does not run whole word search by default", ->
        expect(atom.workspace.scan.argsForCall[0][0]).toEqual /wholeword/gi

      it "toggles whole word option via an event and finds files matching the pattern", ->
        expect(projectFindView.wholeWordOptionButton).not.toHaveClass('selected')
        atom.commands.dispatch(projectFindView[0], 'project-find:toggle-whole-word-option')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.wholeWordOptionButton).toHaveClass('selected')
          expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual /\bwholeword\b/gi

      it "toggles whole word option via a button and finds files matching the pattern", ->
        expect(projectFindView.wholeWordOptionButton).not.toHaveClass('selected')
        projectFindView.wholeWordOptionButton.click()

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.wholeWordOptionButton).toHaveClass('selected')
          expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual /\bwholeword\b/gi

    describe "when project-find:confirm is triggered", ->
      it "displays the results and no errors", ->
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch(projectFindView[0], 'project-find:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          resultsPaneView = getExistingResultsPane()
          resultsView = resultsPaneView.resultsView
          expect(resultsView).toBeVisible()
          resultsView.scrollToBottom() # To load ALL the results
          expect(resultsView.find("li > ul > li")).toHaveLength(13)

    describe "when core:confirm is triggered", ->
      beforeEach ->
        atom.commands.dispatch(workspaceElement, 'project-find:show')

      describe "when the there search field is empty", ->
        it "does not run the seach but clears the model", ->
          spyOn(atom.workspace, 'scan')
          spyOn(projectFindView.model, 'clear')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')
          expect(atom.workspace.scan).not.toHaveBeenCalled()
          expect(projectFindView.model.clear).toHaveBeenCalled()

      it "reruns the search when confirmed again after focusing the window", ->
        projectFindView.findEditor.setText('thisdoesnotmatch')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          spyOn(atom.workspace, 'scan')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(atom.workspace.scan).not.toHaveBeenCalled()
          atom.workspace.scan.reset()
          $(window).triggerHandler 'focus'
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(atom.workspace.scan).toHaveBeenCalled()
          atom.workspace.scan.reset()
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(atom.workspace.scan).not.toHaveBeenCalled()

      describe "when results exist", ->
        beforeEach ->
          projectFindView.findEditor.setText('items')

        it "displays the results and no errors", ->
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          waitsForPromise ->
            searchPromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView
            expect(resultsView).toBeVisible()
            resultsView.scrollToBottom() # To load ALL the results
            expect(resultsView.find("li > ul > li")).toHaveLength(13)
            expect(resultsPaneView.previewCount.text()).toBe "13 results found in 2 files for items"
            expect(projectFindView.errorMessages).not.toBeVisible()

        it "only searches paths matching text in the path filter", ->
          spyOn(atom.workspace, 'scan').andCallFake -> Promise.resolve()
          projectFindView.pathsEditor.setText('*.js')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          waitsForPromise ->
            searchPromise

          runs ->
            expect(atom.workspace.scan.argsForCall[0][1].paths).toEqual ['*.js']

        it "updates the results list when a buffer changes", ->
          atom.commands.dispatch(projectFindView[0], 'core:confirm')
          buffer = atom.project.bufferForPathSync('sample.js')

          waitsForPromise ->
            searchPromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView
            resultsView.scrollToBottom() # To load ALL the results
            expect(resultsView.find("li > ul > li")).toHaveLength(13)
            expect(resultsPaneView.previewCount.text()).toBe "13 results found in 2 files for items"

            resultsView.selectFirstResult()
            _.times 7, -> resultsView.selectNextResult()

            expect(resultsView.find("li > ul:eq(1) > li:eq(0)")).toHaveClass 'selected'

            buffer.setText('there is one "items" in this file')
            advanceClock(buffer.stoppedChangingDelay)

            expect(resultsView.find("li > ul > li")).toHaveLength(8)
            expect(resultsPaneView.previewCount.text()).toBe "8 results found in 2 files for items"
            expect(resultsView.find("li > ul:eq(1) > li:eq(0)")).toHaveClass 'selected'

            buffer.setText('no matches in this file')
            advanceClock(buffer.stoppedChangingDelay)

            expect(resultsView.find("li > ul > li")).toHaveLength(7)
            expect(resultsPaneView.previewCount.text()).toBe "7 results found in 1 file for items"

      describe "when no results exist", ->
        beforeEach ->
          projectFindView.findEditor.setText('notintheprojectbro')
          spyOn(atom.workspace, 'scan').andCallFake -> Promise.resolve()

        it "displays no errors and no results", ->
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          waitsForPromise ->
            searchPromise

          runs ->
            resultsView = getExistingResultsPane().resultsView
            expect(projectFindView.errorMessages).not.toBeVisible()
            expect(resultsView).toBeVisible()
            expect(resultsView.find("li > ul > li")).toHaveLength(0)

    describe "history", ->
      beforeEach ->
        atom.commands.dispatch(workspaceElement, 'project-find:show')
        spyOn(atom.workspace, 'scan').andCallFake ->
          promise = Promise.resolve()
          promise.cancel = ->
          promise

        projectFindView.findEditor.setText('sort')
        projectFindView.replaceEditor.setText('bort')
        projectFindView.pathsEditor.setText('abc')
        atom.commands.dispatch(projectFindView.findEditor[0], 'core:confirm')

        projectFindView.findEditor.setText('items')
        projectFindView.replaceEditor.setText('eyetims')
        projectFindView.pathsEditor.setText('def')
        atom.commands.dispatch(projectFindView.findEditor[0], 'core:confirm')

      it "can navigate the entire history stack", ->
        expect(projectFindView.findEditor.getText()).toEqual 'items'

        atom.commands.dispatch(projectFindView.findEditor[0], 'core:move-up')
        expect(projectFindView.findEditor.getText()).toEqual 'sort'

        atom.commands.dispatch(projectFindView.findEditor[0], 'core:move-down')
        expect(projectFindView.findEditor.getText()).toEqual 'items'

        atom.commands.dispatch(projectFindView.findEditor[0], 'core:move-down')
        expect(projectFindView.findEditor.getText()).toEqual ''

        expect(projectFindView.pathsEditor.getText()).toEqual 'def'

        atom.commands.dispatch(projectFindView.pathsEditor[0], 'core:move-up')
        expect(projectFindView.pathsEditor.getText()).toEqual 'abc'

        atom.commands.dispatch(projectFindView.pathsEditor[0], 'core:move-down')
        expect(projectFindView.pathsEditor.getText()).toEqual 'def'

        atom.commands.dispatch(projectFindView.pathsEditor[0], 'core:move-down')
        expect(projectFindView.pathsEditor.getText()).toEqual ''

        expect(projectFindView.replaceEditor.getText()).toEqual 'eyetims'

        atom.commands.dispatch(projectFindView.replaceEditor[0], 'core:move-up')
        expect(projectFindView.replaceEditor.getText()).toEqual 'bort'

        atom.commands.dispatch(projectFindView.replaceEditor[0], 'core:move-down')
        expect(projectFindView.replaceEditor.getText()).toEqual 'eyetims'

        atom.commands.dispatch(projectFindView.replaceEditor[0], 'core:move-down')
        expect(projectFindView.replaceEditor.getText()).toEqual ''

    describe "when find-and-replace:use-selection-as-find-pattern is triggered", ->
      it "places the selected text into the find editor", ->
        editor.setSelectedBufferRange([[1, 6], [1, 10]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(projectFindView.findEditor.getText()).toBe 'sort'

        editor.setSelectedBufferRange([[1, 13], [1, 21]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(projectFindView.findEditor.getText()).toBe 'function'

      it "places the word under the cursor into the find editor", ->
        editor.setSelectedBufferRange([[1, 8], [1, 8]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(projectFindView.findEditor.getText()).toBe 'sort'

        editor.setSelectedBufferRange([[1, 15], [1, 15]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(projectFindView.findEditor.getText()).toBe 'function'

      it "places the previously selected text into the find editor if no selection and no word under cursor", ->
        editor.setSelectedBufferRange([[1, 13], [1, 21]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(projectFindView.findEditor.getText()).toBe 'function'

        editor.setSelectedBufferRange([[1, 1], [1, 1]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(projectFindView.findEditor.getText()).toBe 'function'

      it "places selected text into the find editor and escapes it when Regex is enabled", ->
        atom.commands.dispatch(projectFindView[0], 'project-find:toggle-regex-option')
        editor.setSelectedBufferRange([[6, 6], [6, 65]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(projectFindView.findEditor.getText()).toBe 'current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);'

    describe "when there is an error searching", ->
      it "displays the errors in the results pane", ->
        [callback, resolve, called, resultsPaneView, errorList] = []
        projectFindView.findEditor.setText('items')
        spyOn(atom.workspace, 'scan').andCallFake (regex, options, fn) ->
          callback = fn
          called = true
          new Promise (res) -> resolve = res

        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsFor -> called

        runs ->
          resultsPaneView = getExistingResultsPane()
          errorList = resultsPaneView.errorList
          expect(errorList.find("li")).toHaveLength 0

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Nope'})
          expect(errorList).toBeVisible()
          expect(errorList.find("li")).toHaveLength 1

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Broken'})
          resolve()

        waitsForPromise ->
          searchPromise

        runs ->
          expect(errorList).toBeVisible()
          expect(errorList.find("li")).toHaveLength 2
          expect(errorList.find("li:eq(0)").text()).toBe 'Nope'
          expect(errorList.find("li:eq(1)").text()).toBe 'Broken'

    describe "buffer search sharing of the find options", ->
      getResultDecorations = (className) ->
        markerIdForDecorations = editor.decorationsForScreenRowRange(0, editor.getLineCount())
        resultDecorations = []
        for markerId, decorations of markerIdForDecorations
          for decoration in decorations
            resultDecorations.push decoration if decoration.getProperties().class is className
        resultDecorations

      it "setting the find text does not interfere with the project replace state", ->
        # Not sure why I need to advance the clock before setting the text. If
        # this advanceClock doesnt happen, the text will be ''. wtf.
        advanceClock(projectFindView.findEditor.getModel().getBuffer().stoppedChangingDelay + 1)
        spyOn(atom.workspace, 'scan')

        projectFindView.findEditor.setText('findme')
        advanceClock(projectFindView.findEditor.getModel().getBuffer().stoppedChangingDelay + 1)

        waitsForPromise ->
          projectFindView.search(onlyRunIfActive: false, onlyRunIfChanged: true)

        runs ->
          expect(atom.workspace.scan).toHaveBeenCalled()

      it "shares the buffers and history cyclers between both buffer and project views", ->
        {findView} = mainModule

        projectFindView.findEditor.setText('findme')
        projectFindView.replaceEditor.setText('replaceme')

        atom.commands.dispatch editorView, 'find-and-replace:show'
        expect(findView.findEditor.getText()).toBe 'findme'
        expect(findView.replaceEditor.getText()).toBe 'replaceme'

        # add some things to the history
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        findView.findEditor.setText('findme1')
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        findView.findEditor.setText('')

        atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
        findView.replaceEditor.setText('replaceme1')
        atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
        findView.replaceEditor.setText('')

        # Back to the project view to make sure we're using the same cycler
        atom.commands.dispatch editorView, 'project-find:show'

        expect(projectFindView.findEditor.getText()).toBe ''
        atom.commands.dispatch(projectFindView.findEditor.element, 'core:move-up')
        expect(projectFindView.findEditor.getText()).toBe 'findme1'
        atom.commands.dispatch(projectFindView.findEditor.element, 'core:move-up')
        expect(projectFindView.findEditor.getText()).toBe 'findme'

        expect(projectFindView.replaceEditor.getText()).toBe ''
        atom.commands.dispatch(projectFindView.replaceEditor.element, 'core:move-up')
        expect(projectFindView.replaceEditor.getText()).toBe 'replaceme1'
        atom.commands.dispatch(projectFindView.replaceEditor.element, 'core:move-up')
        expect(projectFindView.replaceEditor.getText()).toBe 'replaceme'

      it 'highlights the search results in the selected file', ->
        # Process here is to
        # * open samplejs
        # * run a search that has sample js results
        # * that should place the pattern in the buffer find
        # * focus sample.js by clicking on a sample.js result
        # * when the file has been activated, it's results for the project search should be highlighted

        waitsForPromise ->
          atom.workspace.open('sample.js')

        runs ->
          editor = atom.workspace.getActiveTextEditor()
          expect(getResultDecorations('find-result')).toHaveLength 0

        runs ->
          projectFindView.findEditor.setText('item')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          resultsPaneView = getExistingResultsPane()
          resultsView = resultsPaneView.resultsView
          resultsView.scrollToBottom() # To load ALL the results

          expect(resultsView).toBeVisible()
          expect(resultsView.find("li > ul > li")).toHaveLength(13)

          resultsView.selectFirstResult()
          _.times 10, -> atom.commands.dispatch(resultsView[0], 'core:move-down')
          atom.commands.dispatch(resultsView[0], 'core:confirm')

        waits 0 # not sure why this is async
        runs ->
          # sample.js has 6 results
          expect(getResultDecorations('find-result')).toHaveLength 5
          expect(getResultDecorations('current-result')).toHaveLength 1
          expect(workspaceElement).toHaveClass 'find-visible'

          initialSelectedRange = editor.getSelectedBufferRange()

          # now we can find next
          atom.commands.dispatch atom.views.getView(editor), 'find-and-replace:find-next'
          expect(editor.getSelectedBufferRange()).not.toEqual initialSelectedRange

          # Now we toggle the whole-word option to make sure it is updated in the buffer find
          atom.commands.dispatch(projectFindView[0], 'project-find:toggle-whole-word-option')

        waits 0
        runs ->
          # sample.js has 0 results for whole word `item`
          expect(getResultDecorations('find-result')).toHaveLength 0
          expect(workspaceElement).toHaveClass 'find-visible'

          # Now we toggle the whole-word option to make sure it is updated in the buffer find
          atom.commands.dispatch(projectFindView[0], 'project-find:toggle-whole-word-option')

  describe "replacing", ->
    [testDir, sampleJs, sampleCoffee, replacePromise] = []

    beforeEach ->
      testDir = path.join(os.tmpdir(), "atom-find-and-replace")
      fs.makeTreeSync(testDir)
      sampleJs = path.join(testDir, 'sample.js')
      sampleCoffee = path.join(testDir, 'sample.coffee')

      fs.writeFileSync(sampleCoffee, fs.readFileSync(require.resolve('./fixtures/sample.coffee')))
      fs.writeFileSync(sampleJs, fs.readFileSync(require.resolve('./fixtures/sample.js')))
      atom.commands.dispatch(workspaceElement, 'project-find:show')

      waitsForPromise ->
        activationPromise

      runs ->
        atom.project.setPaths([testDir])
        spy = spyOn(projectFindView, 'replaceAll').andCallFake ->
          replacePromise = spy.originalValue.call(projectFindView)

    afterEach ->
      # On Windows, you can not remove a watched directory/file, therefore we
      # have to close the project before attempting to delete. Unfortunately,
      # Pathwatcher's close function is also not synchronous. Once
      # atom/node-pathwatcher#4 is implemented this should be alot cleaner.
      activePane = atom.workspace.getActivePane()
      for item in (activePane?.getItems() or [])
        spyOn(item, 'shouldPromptToSave').andReturn(false) if item.shouldPromptToSave?
        activePane.destroyItem(item)

      success = false
      runs ->
        retry = setInterval ->
          try
            fs.removeSync(testDir)
            success = true
            clearInterval(retry)
          catch e
            success = false
        , 50
      waitsFor -> success

    describe "when the replace string contains an escaped char", ->
      filePath = null

      beforeEach ->
        projectPath = temp.mkdirSync("atom")
        filePath = path.join(projectPath, "tabs.txt")
        fs.writeFileSync(filePath, "a\nb\na")
        atom.project.setPaths([projectPath])
        atom.commands.dispatch(workspaceElement, 'project-find:show')

        spyOn(atom, 'confirm').andReturn 0

      describe "when the regex option is chosen", ->
        beforeEach ->
          atom.commands.dispatch(projectFindView[0], 'project-find:toggle-regex-option')

          projectFindView.findEditor.setText('a')
          atom.commands.dispatch(projectFindView[0], 'project-find:confirm')
          waitsForPromise -> searchPromise

        it "finds the escape char", ->
          projectFindView.replaceEditor.setText('\\t')
          atom.commands.dispatch(projectFindView[0], 'project-find:replace-all')

          waitsForPromise -> replacePromise

          runs ->
            fileContent = fs.readFileSync(filePath, 'utf8')
            expect(fileContent).toBe("\t\nb\n\t")

        it "doesn't insert a escaped char if there are multiple backslashs in front of the char", ->
          projectFindView.replaceEditor.setText('\\\\t')
          atom.commands.dispatch(projectFindView[0], 'project-find:replace-all')

          waitsForPromise -> replacePromise

          runs ->
            fileContent = fs.readFileSync(filePath, 'utf8')
            expect(fileContent).toBe("\\t\nb\n\\t")

      describe "when regex option is not set", ->
        beforeEach ->
          projectFindView.findEditor.setText('a')
          atom.commands.dispatch(projectFindView[0], 'project-find:confirm')
          waitsForPromise -> searchPromise

        it "finds the escape char", ->
          projectFindView.replaceEditor.setText('\\t')
          atom.commands.dispatch(projectFindView[0], 'project-find:replace-all')

          waitsForPromise -> replacePromise

          runs ->
            fileContent = fs.readFileSync(filePath, 'utf8')
            expect(fileContent).toBe("\\t\nb\n\\t")

    describe "replace all button enablement", ->
      it "is disabled initially", ->
        expect(projectFindView.replaceAllButton[0].disabled).toBe true

      it "is enabled when a search has results and disabled when there are no results", ->
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch(projectFindView[0], 'project-find:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.replaceAllButton[0].disabled).toBe false

          projectFindView.findEditor.setText('nopenotinthefile')
          atom.commands.dispatch(projectFindView[0], 'project-find:confirm')

          projectFindView.findEditor.setText('itemss')
          expect(projectFindView.replaceAllButton[0].disabled).toBe true

          projectFindView.findEditor.setText('items')
          expect(projectFindView.replaceAllButton[0].disabled).toBe false

        waitsForPromise ->
          searchPromise

        runs ->
          expect(projectFindView.replaceAllButton[0].disabled).toBe true

          projectFindView.findEditor.setText('')
          atom.commands.dispatch(projectFindView[0], 'project-find:confirm')

          expect(projectFindView.replaceAllButton[0].disabled).toBe true

    describe "when the replace button is pressed", ->
      beforeEach ->
        spyOn(atom, 'confirm').andReturn 0

      it "runs the search, and replaces all the matches", ->
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          projectFindView.replaceEditor.setText('sunshine')
          projectFindView.replaceAllButton.click()

        waitsForPromise ->
          replacePromise

        runs ->
          expect(projectFindView.errorMessages).not.toBeVisible()
          expect(projectFindView.descriptionLabel.text()).toContain 'Replaced'

          sampleJsContent = fs.readFileSync(sampleJs, 'utf8')
          expect(sampleJsContent.match(/items/g)).toBeFalsy()
          expect(sampleJsContent.match(/sunshine/g)).toHaveLength 6

          sampleCoffeeContent = fs.readFileSync(sampleCoffee, 'utf8')
          expect(sampleCoffeeContent.match(/items/g)).toBeFalsy()
          expect(sampleCoffeeContent.match(/sunshine/g)).toHaveLength 7

      describe "when there are search results after a replace", ->
        it "runs the search after the replace", ->
          projectFindView.findEditor.setText('items')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          waitsForPromise ->
            searchPromise

          runs ->
            projectFindView.replaceEditor.setText('items-123')
            projectFindView.replaceAllButton.click()

          waitsForPromise ->
            replacePromise

          runs ->
            expect(projectFindView.errorMessages).not.toBeVisible()

            expect(getExistingResultsPane().previewCount.text()).toContain '13 results found in 2 files for items'
            expect(projectFindView.descriptionLabel.text()).toContain 'Replaced items with items-123 13 times in 2 files'

            projectFindView.replaceEditor.setText('cats')
            advanceClock(projectFindView.replaceEditor.getModel().getBuffer().stoppedChangingDelay)

            expect(projectFindView.descriptionLabel.text()).not.toContain 'Replaced items'
            expect(projectFindView.descriptionLabel.text()).toContain "13 results found in 2 files for items"

    describe "when the project-find:replace-all is triggered", ->
      describe "when no search has been run", ->
        beforeEach ->
          spyOn(atom, 'confirm').andReturn 0

        it "does nothing", ->
          projectFindView.findEditor.setText('items')
          projectFindView.replaceEditor.setText('sunshine')

          spyOn(atom, 'beep')
          atom.commands.dispatch(projectFindView[0], 'project-find:replace-all')

          expect(replacePromise).toBeUndefined()

          expect(atom.beep).toHaveBeenCalled()
          expect(projectFindView.descriptionLabel.text()).toContain "Find in Project"

      describe "when a search with no results has been run", ->
        beforeEach ->
          spyOn(atom, 'confirm').andReturn 0
          projectFindView.findEditor.setText('nopenotinthefile')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          waitsForPromise ->
            searchPromise

        it "doesnt replace anything", ->
          projectFindView.replaceEditor.setText('sunshine')

          spyOn(atom.workspace, 'scan').andCallThrough()
          spyOn(atom, 'beep')
          atom.commands.dispatch(projectFindView[0], 'project-find:replace-all')

          # The replacement isnt even run
          expect(replacePromise).toBeUndefined()

          expect(atom.workspace.scan).not.toHaveBeenCalled()
          expect(atom.beep).toHaveBeenCalled()
          expect(projectFindView.descriptionLabel.text().replace(/(  )/g, ' ')).toContain "No results"

      describe "when a search with results has been run", ->
        beforeEach ->
          projectFindView.findEditor.setText('items')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

          waitsForPromise ->
            searchPromise

        it "messages the user when the search text has changed since that last search", ->
          spyOn(atom, 'confirm').andReturn 0
          spyOn(atom.workspace, 'scan').andCallThrough()

          projectFindView.findEditor.setText('sort')
          projectFindView.replaceEditor.setText('ok')

          atom.commands.dispatch(projectFindView[0], 'project-find:replace-all')

          expect(atom.confirm).toHaveBeenCalled()
          expect(replacePromise).toBeUndefined()
          expect(atom.workspace.scan).not.toHaveBeenCalled()

        it "replaces all the matches and updates the results view", ->
          spyOn(atom, 'confirm').andReturn 0
          projectFindView.replaceEditor.setText('sunshine')
          atom.commands.dispatch(projectFindView[0], 'project-find:replace-all')
          expect(projectFindView.errorMessages).not.toBeVisible()

          waitsForPromise ->
            replacePromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView

            expect(resultsView).toBeVisible()
            expect(resultsView.find("li > ul > li")).toHaveLength(0)

            expect(projectFindView.descriptionLabel.text()).toContain "Replaced items with sunshine 13 times in 2 files"

            sampleJsContent = fs.readFileSync(sampleJs, 'utf8')
            expect(sampleJsContent.match(/items/g)).toBeFalsy()
            expect(sampleJsContent.match(/sunshine/g)).toHaveLength 6

            sampleCoffeeContent = fs.readFileSync(sampleCoffee, 'utf8')
            expect(sampleCoffeeContent.match(/items/g)).toBeFalsy()
            expect(sampleCoffeeContent.match(/sunshine/g)).toHaveLength 7

        describe "when the confirm box is cancelled", ->
          beforeEach ->
            spyOn(atom, 'confirm').andReturn 1

          it "does not replace", ->
            projectFindView.replaceEditor.setText('sunshine')
            atom.commands.dispatch(projectFindView[0], 'project-find:replace-all')

            waitsForPromise -> replacePromise

            runs ->
              expect(projectFindView.descriptionLabel.text()).toContain "13 results found"

    describe "when there is an error replacing", ->
      beforeEach ->
        spyOn(atom, 'confirm').andReturn 0
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch(projectFindView[0], 'project-find:confirm')
        waitsForPromise -> searchPromise

      it "displays the errors in the results pane", ->
        [callback, resolve, called, resultsPaneView, errorList] = []
        projectFindView.replaceEditor.setText('sunshine')

        spyOn(atom.workspace, 'replace').andCallFake (regex, replacement, paths, fn) ->
          callback = fn
          called = true
          new Promise (res) -> resolve = res

        atom.commands.dispatch(projectFindView[0], 'project-find:replace-all')

        waitsFor -> called

        runs ->
          resultsPaneView = getExistingResultsPane()
          errorList = resultsPaneView.errorList
          expect(errorList.find("li")).toHaveLength 0

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Nope'})
          expect(errorList).toBeVisible()
          expect(errorList.find("li")).toHaveLength 1

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Broken'})
          resolve()

        waitsForPromise ->
          replacePromise

        runs ->
          expect(errorList).toBeVisible()
          expect(errorList.find("li")).toHaveLength 2
          expect(errorList.find("li:eq(0)").text()).toBe 'Nope'
          expect(errorList.find("li:eq(1)").text()).toBe 'Broken'

  describe "panel focus", ->
    beforeEach ->
      atom.commands.dispatch(workspaceElement, 'project-find:show')
      waitsForPromise -> activationPromise

    it "focuses the find editor when the panel gets focus", ->
      projectFindView.replaceEditor.focus()
      expect(projectFindView.replaceEditor).toHaveFocus()

      projectFindView.focus()
      expect(projectFindView.findEditor).toHaveFocus()

    it "moves focus between editors with find-and-replace:focus-next", ->
      projectFindView.findEditor.focus()
      expect(projectFindView.findEditor).toHaveClass('is-focused')
      expect(projectFindView.replaceEditor).not.toHaveClass('is-focused')
      expect(projectFindView.pathsEditor).not.toHaveClass('is-focused')

      atom.commands.dispatch projectFindView.findEditor.element, 'find-and-replace:focus-next'
      expect(projectFindView.findEditor).not.toHaveClass('is-focused')
      expect(projectFindView.replaceEditor).toHaveClass('is-focused')
      expect(projectFindView.pathsEditor).not.toHaveClass('is-focused')

      atom.commands.dispatch projectFindView.replaceEditor.element, 'find-and-replace:focus-next'
      expect(projectFindView.findEditor).not.toHaveClass('is-focused')
      expect(projectFindView.replaceEditor).not.toHaveClass('is-focused')
      expect(projectFindView.pathsEditor).toHaveClass('is-focused')

      atom.commands.dispatch projectFindView.replaceEditor.element, 'find-and-replace:focus-next'
      expect(projectFindView.findEditor).toHaveClass('is-focused')
      expect(projectFindView.replaceEditor).not.toHaveClass('is-focused')
      expect(projectFindView.pathsEditor).not.toHaveClass('is-focused')

      atom.commands.dispatch projectFindView.replaceEditor.element, 'find-and-replace:focus-previous'
      expect(projectFindView.findEditor).not.toHaveClass('is-focused')
      expect(projectFindView.replaceEditor).not.toHaveClass('is-focused')
      expect(projectFindView.pathsEditor).toHaveClass('is-focused')

      atom.commands.dispatch projectFindView.replaceEditor.element, 'find-and-replace:focus-previous'
      expect(projectFindView.findEditor).not.toHaveClass('is-focused')
      expect(projectFindView.replaceEditor).toHaveClass('is-focused')
      expect(projectFindView.pathsEditor).not.toHaveClass('is-focused')

  describe "panel opening", ->
    describe "when a panel is already open", ->
      beforeEach ->
        atom.config.set('find-and-replace.openProjectFindResultsInRightPane', true)

        waitsForPromise ->
          atom.workspace.open('sample.js')

        runs ->
          editor = atom.workspace.getActiveTextEditor()
          editorView = atom.views.getView(editor)
          atom.commands.dispatch(workspaceElement, 'project-find:show')

        waitsForPromise ->
          activationPromise

        runs ->
          projectFindView.findEditor.setText('items')
          atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

      it "doesn't open another panel even if the active pane is vertically split", ->
        atom.commands.dispatch(editorView, 'pane:split-down')
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch(projectFindView[0], 'core:confirm')

        waitsForPromise ->
          searchPromise

        runs ->
          expect(workspaceElement.querySelectorAll('.preview-pane').length).toBe(1)

  describe "when language-javascript is active", ->
    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage("language-javascript")

    it "uses the regexp grammar when regex-mode is loaded from configuration", ->
      atom.config.set('find-and-replace.useRegex', true)
      atom.commands.dispatch(workspaceElement, 'project-find:show')
      waitsForPromise ->
        activationPromise

      runs ->
        expect(projectFindView.model.getFindOptions().useRegex).toBe true
        expect(projectFindView.findEditor.getModel().getGrammar().scopeName).toBe 'source.js.regexp'

    describe "when panel is active", ->
      beforeEach ->
        atom.commands.dispatch(workspaceElement, 'project-find:show')
        waitsForPromise -> activationPromise

      it "does not use regexp grammar when in non-regex mode", ->
        expect(projectFindView.model.getFindOptions().useRegex).not.toBe true
        expect(projectFindView.findEditor.getModel().getGrammar().scopeName).toBe 'text.plain.null-grammar'

      it "uses regexp grammar when in regex mode and clears the regexp grammar when regex is disabled", ->
        atom.commands.dispatch(projectFindView[0], 'project-find:toggle-regex-option')

        expect(projectFindView.model.getFindOptions().useRegex).toBe true
        expect(projectFindView.findEditor.getModel().getGrammar().scopeName).toBe 'source.js.regexp'

        atom.commands.dispatch(projectFindView[0], 'project-find:toggle-regex-option')

        expect(projectFindView.model.getFindOptions().useRegex).not.toBe true
        expect(projectFindView.findEditor.getModel().getGrammar().scopeName).toBe 'text.plain.null-grammar'
