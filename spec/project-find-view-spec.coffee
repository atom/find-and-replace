os = require 'os'
path = require 'path'

{_, fs, $, RootView} = require 'atom'
Q = require 'q'

ResultsPaneView = require '../lib/project/results-pane'

# Default to 30 second promises
waitsForPromise = (fn) -> window.waitsForPromise timeout: 30000, fn

describe 'ProjectFindView', ->
  [pack, editor, projectFindView, searchPromise] = []

  getExistingResultsPane = ->
    pane = rootView.panes.paneForUri(ResultsPaneView.URI)
    return pane.itemForUri(ResultsPaneView.URI) if pane?
    null

  beforeEach ->
    window.rootView = new RootView()
    project.setPath(path.join(__dirname, 'fixtures'))
    rootView.attachToDom()
    pack = atom.activatePackage("find-and-replace", immediate: true)
    projectFindView = pack.mainModule.projectFindView

    config.set('find-and-replace.openProjectFindResultsInRightPane', false)

    spy = spyOn(projectFindView, 'confirm').andCallFake ->
      searchPromise = spy.originalValue.call(projectFindView)

  describe "when project-find:show is triggered", ->
    beforeEach ->
      projectFindView.findEditor.setText('items')

    it "attaches ProjectFindView to the root view", ->
      rootView.trigger 'project-find:show'
      expect(rootView.find('.project-find')).toExist()
      expect(projectFindView.find('.preview-block')).not.toBeVisible()
      expect(projectFindView.find('.loading')).not.toBeVisible()
      expect(projectFindView.findEditor.getSelectedBufferRange()).toEqual [[0, 0], [0, 5]]

  describe "finding", ->
    beforeEach ->
      rootView.openSync('sample.js')
      editor = rootView.getActiveView()

    describe "when core:cancel is triggered", ->
      beforeEach ->
        rootView.trigger 'project-find:show'
        projectFindView.focus()

      it "detaches from the root view", ->
        $(document.activeElement).trigger 'core:cancel'
        expect(rootView.find('.project-find')).not.toExist()

    describe "splitting into a second pane", ->
      beforeEach ->
        rootView.height(1000)

        editor.trigger 'project-find:show'

      it "splits when option is true", ->
        initialPane = rootView.getActivePane()
        config.set('find-and-replace.openProjectFindResultsInRightPane', true)
        projectFindView.findEditor.setText('items')
        projectFindView.trigger 'core:confirm'

        waitsForPromise ->
          searchPromise

        runs ->
          pane1 = rootView.getActivePane()
          expect(pane1[0]).not.toBe initialPane[0]

      it "does not split when option is false", ->
        initialPane = rootView.getActivePane()
        projectFindView.findEditor.setText('items')
        projectFindView.trigger 'core:confirm'

        waitsForPromise ->
          searchPromise

        runs ->
          pane1 = rootView.getActivePane()
          expect(pane1[0]).toBe initialPane[0]

      it "can be duplicated", ->
        config.set('find-and-replace.openProjectFindResultsInRightPane', true)
        projectFindView.findEditor.setText('items')
        projectFindView.trigger 'core:confirm'

        waitsForPromise ->
          searchPromise

        runs ->
          resultsPaneView1 = getExistingResultsPane()
          pane1 = rootView.getActivePane()
          pane1.splitRight(pane1.copyActiveItem())

          pane2 = rootView.getActivePane()
          resultsPaneView2 = pane2.itemForUri(ResultsPaneView.URI)

          expect(pane1[0]).not.toBe pane2[0]
          expect(resultsPaneView1[0]).not.toBe resultsPaneView2[0]

          length = resultsPaneView1.find('li > ul > li').length
          expect(length).toBeGreaterThan 0
          expect(resultsPaneView2.find('li > ul > li')).toHaveLength length

          expect(resultsPaneView2.previewCount.html()).toEqual resultsPaneView1.previewCount.html()

    describe "serialization", ->
      it "serializes if the view is attached", ->
        expect(projectFindView.hasParent()).toBeFalsy()
        editor.trigger 'project-find:show'
        atom.deactivatePackage("find-and-replace")
        pack = atom.activatePackage("find-and-replace", immediate: true)
        projectFindView = pack.mainModule.projectFindView

        expect(projectFindView.hasParent()).toBeTruthy()

      it "serializes if the case and regex options", ->
        editor.trigger 'project-find:show'
        expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
        projectFindView.caseOptionButton.click()
        expect(projectFindView.caseOptionButton).toHaveClass('selected')

        expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
        projectFindView.regexOptionButton.click()
        expect(projectFindView.regexOptionButton).toHaveClass('selected')

        atom.deactivatePackage("find-and-replace")
        pack = atom.activatePackage("find-and-replace", immediate: true)
        projectFindView = pack.mainModule.projectFindView

        expect(projectFindView.caseOptionButton).toHaveClass('selected')
        expect(projectFindView.regexOptionButton).toHaveClass('selected')

    describe "regex", ->
      beforeEach ->
        editor.trigger 'project-find:show'
        projectFindView.findEditor.setText('i(\\w)ems+')
        spyOn(project, 'scan').andCallFake -> Q()

      it "escapes regex patterns by default", ->
        projectFindView.trigger 'core:confirm'
        expect(project.scan.argsForCall[0][0]).toEqual /i\(\\w\)ems\+/gi

      it "toggles regex option via an event and finds files matching the pattern", ->
        expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
        projectFindView.trigger 'project-find:toggle-regex-option'
        expect(projectFindView.regexOptionButton).toHaveClass('selected')
        expect(project.scan.argsForCall[0][0]).toEqual /i(\w)ems+/gi

      it "toggles regex option via a button and finds files matching the pattern", ->
        expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
        projectFindView.regexOptionButton.click()
        expect(projectFindView.regexOptionButton).toHaveClass('selected')
        expect(project.scan.argsForCall[0][0]).toEqual /i(\w)ems+/gi

    describe "case sensitivity", ->
      beforeEach ->
        editor.trigger 'project-find:show'
        spyOn(project, 'scan').andCallFake -> Q()
        projectFindView.findEditor.setText('ITEMS')

      it "runs a case insensitive search by default", ->
        projectFindView.trigger 'core:confirm'
        expect(project.scan.argsForCall[0][0]).toEqual /ITEMS/gi

      it "toggles case sensitive option via an event and finds files matching the pattern", ->
        expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
        projectFindView.trigger 'project-find:toggle-case-option'
        expect(projectFindView.caseOptionButton).toHaveClass('selected')
        expect(project.scan.argsForCall[0][0]).toEqual /ITEMS/g

      it "toggles case sensitive option via a button and finds files matching the pattern", ->
        expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
        projectFindView.caseOptionButton.click()
        expect(projectFindView.caseOptionButton).toHaveClass('selected')
        expect(project.scan.argsForCall[0][0]).toEqual /ITEMS/g

    describe "when core:confirm is triggered", ->
      beforeEach ->
        rootView.trigger 'project-find:show'

      describe "when the there search field is empty", ->
        it "does not run the seach", ->
          spyOn(project, 'scan')
          projectFindView.trigger 'core:confirm'
          expect(project.scan).not.toHaveBeenCalled()

      describe "when results exist", ->
        beforeEach ->
          projectFindView.findEditor.setText('items')

        it "displays the results and no errors", ->
          projectFindView.trigger 'core:confirm'

          waitsForPromise ->
            searchPromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView
            expect(resultsView).toBeVisible()
            resultsView.scrollToBottom() # To load ALL the results
            expect(resultsView.find("li > ul > li")).toHaveLength(13)
            expect(resultsPaneView.previewCount.text()).toBe "13 matches in 2 files for 'items'"
            expect(projectFindView.errorMessages).not.toBeVisible()

        it "only searches paths matching text in the path filter", ->
          spyOn(project, 'scan').andCallFake -> Q()
          projectFindView.pathsEditor.setText('*.js')
          projectFindView.trigger 'core:confirm'

          expect(project.scan.argsForCall[0][1]['paths']).toEqual ['*.js']

        it "updates the results list when a buffer changes", ->
          projectFindView.trigger 'core:confirm'
          buffer = project.bufferForPathSync('sample.js')

          waitsForPromise ->
            searchPromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView
            resultsView.scrollToBottom() # To load ALL the results
            expect(resultsView.find("li > ul > li")).toHaveLength(13)
            expect(resultsPaneView.previewCount.text()).toBe "13 matches in 2 files for 'items'"

            resultsView.selectFirstResult()
            _.times 7, -> resultsView.selectNextResult()

            expect(resultsView.find("li > ul:eq(1) > li:eq(0)")).toHaveClass 'selected'

            buffer.setText('there is one "items" in this file')
            buffer.trigger('contents-modified')

            expect(resultsView.find("li > ul > li")).toHaveLength(8)
            expect(resultsPaneView.previewCount.text()).toBe "8 matches in 2 files for 'items'"
            expect(resultsView.find("li > ul:eq(1) > li:eq(0)")).toHaveClass 'selected'

            buffer.setText('no matches in this file')
            buffer.trigger('contents-modified')

            expect(resultsView.find("li > ul > li")).toHaveLength(7)
            expect(resultsPaneView.previewCount.text()).toBe "7 matches in 1 file for 'items'"

      describe "when no results exist", ->
        beforeEach ->
          projectFindView.findEditor.setText('notintheprojectbro')
          spyOn(project, 'scan').andCallFake -> Q()

        it "displays no errors and no results", ->
          projectFindView.trigger 'core:confirm'

          waitsForPromise ->
            searchPromise

          runs ->
            resultsView = getExistingResultsPane().resultsView
            expect(projectFindView.errorMessages).not.toBeVisible()
            expect(resultsView).toBeVisible()
            expect(resultsView.find("li > ul > li")).toHaveLength(0)

    describe "history", ->
      beforeEach ->
        rootView.trigger 'project-find:show'
        spyOn(project, 'scan').andCallFake -> Q()

        projectFindView.findEditor.setText('sort')
        projectFindView.replaceEditor.setText('bort')
        projectFindView.pathsEditor.setText('abc')
        projectFindView.findEditor.trigger 'core:confirm'

        projectFindView.findEditor.setText('items')
        projectFindView.replaceEditor.setText('eyetims')
        projectFindView.pathsEditor.setText('def')
        projectFindView.findEditor.trigger 'core:confirm'

      it "can navigate the entire history stack", ->
        expect(projectFindView.findEditor.getText()).toEqual 'items'

        projectFindView.findEditor.trigger 'core:move-up'
        expect(projectFindView.findEditor.getText()).toEqual 'sort'

        projectFindView.findEditor.trigger 'core:move-down'
        expect(projectFindView.findEditor.getText()).toEqual 'items'

        projectFindView.findEditor.trigger 'core:move-down'
        expect(projectFindView.findEditor.getText()).toEqual ''

        expect(projectFindView.pathsEditor.getText()).toEqual 'def'

        projectFindView.pathsEditor.trigger 'core:move-up'
        expect(projectFindView.pathsEditor.getText()).toEqual 'abc'

        projectFindView.pathsEditor.trigger 'core:move-down'
        expect(projectFindView.pathsEditor.getText()).toEqual 'def'

        projectFindView.pathsEditor.trigger 'core:move-down'
        expect(projectFindView.pathsEditor.getText()).toEqual ''

        expect(projectFindView.replaceEditor.getText()).toEqual 'eyetims'

        projectFindView.replaceEditor.trigger 'core:move-up'
        expect(projectFindView.replaceEditor.getText()).toEqual 'bort'

        projectFindView.replaceEditor.trigger 'core:move-down'
        expect(projectFindView.replaceEditor.getText()).toEqual 'eyetims'

        projectFindView.replaceEditor.trigger 'core:move-down'
        expect(projectFindView.replaceEditor.getText()).toEqual ''

    describe "when find-and-replace:set-find-pattern is triggered", ->
      it "places the selected text into the find editor", ->
        editor.setSelectedBufferRange([[1,6],[1,10]])
        rootView.trigger 'find-and-replace:use-selection-as-find-pattern'

        expect(projectFindView.findEditor.getText()).toBe 'sort'

  describe "replacing", ->
    [testDir, sampleJs, sampleCoffee, replacePromise] = []

    beforeEach ->
      testDir = path.join(os.tmpdir(), "atom-find-and-replace")
      fs.makeTreeSync(testDir)
      sampleJs = path.join(testDir, 'sample.js')
      sampleCoffee = path.join(testDir, 'sample.coffee')

      fs.writeFileSync(sampleCoffee, fs.readFileSync(require.resolve('./fixtures/sample.coffee')))
      fs.writeFileSync(sampleJs, fs.readFileSync(require.resolve('./fixtures/sample.js')))
      rootView.trigger 'project-find:show'
      project.setPath(testDir)

      spy = spyOn(projectFindView, 'replaceAll').andCallFake ->
        replacePromise = spy.originalValue.call(projectFindView)

    afterEach ->
      # On Windows, you can not remove a watched directory/file, therefore we
      # have to close the project before attempting to delete. Unfortunately,
      # Pathwatcher's close function is also not synchronous. Once
      # atom/node-pathwatcher#4 is implemented this should be alot cleaner.
      activePane = rootView.getActivePane()
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

    describe "when the replace button is pressed", ->
      it "runs the search, and replaces all the matches", ->
        projectFindView.findEditor.setText('items')
        projectFindView.trigger 'core:confirm'

        waitsForPromise ->
          searchPromise

        runs ->
          projectFindView.replaceEditor.setText('sunshine')
          projectFindView.replaceAllButton.click()

        waitsForPromise ->
          replacePromise

        runs ->
          expect(projectFindView.errorMessages).not.toBeVisible()
          expect(projectFindView.infoMessages).toBeVisible()
          expect(projectFindView.infoMessages.find('li').text()).toContain 'Replaced'

          sampleJsContent = fs.read sampleJs
          expect(sampleJsContent.match(/items/g)).toBeFalsy()
          expect(sampleJsContent.match(/sunshine/g)).toHaveLength 6

          sampleCoffeeContent = fs.read sampleCoffee
          expect(sampleCoffeeContent.match(/items/g)).toBeFalsy()
          expect(sampleCoffeeContent.match(/sunshine/g)).toHaveLength 7

    describe "when the project-find:replace-all is triggered", ->
      describe "when no search has been run", ->
        it "does not replace anything", ->
          spyOn(project, 'scan')
          spyOn(atom, 'beep')
          projectFindView.trigger 'project-find:replace-all'

          waitsForPromise ->
            replacePromise

          runs ->
            expect(project.scan).not.toHaveBeenCalled()
            expect(atom.beep).toHaveBeenCalled()
            expect(projectFindView.infoMessages.find('li').text()).toBe "Nothing replaced"

      describe "when the search text has changed since that last search", ->
        beforeEach ->
          projectFindView.findEditor.setText('items')
          projectFindView.trigger 'core:confirm'

          waitsForPromise ->
            searchPromise

        it "clears the search results and does not replace anything", ->
          spyOn(project, 'scan')
          spyOn(atom, 'beep')

          projectFindView.findEditor.setText('sort')
          expect(projectFindView.resultsView).not.toBeVisible()

          projectFindView.trigger 'project-find:replace-all'

          waitsForPromise ->
            replacePromise

          runs ->
            expect(project.scan).not.toHaveBeenCalled()
            expect(atom.beep).toHaveBeenCalled()
            expect(projectFindView.infoMessages.find('li').text()).toBe "Nothing replaced"

      describe "when the text in the search box triggered the results", ->
        beforeEach ->
          projectFindView.findEditor.setText('items')
          projectFindView.trigger 'core:confirm'

          waitsForPromise ->
            searchPromise

        it "runs the search, and replaces all the matches", ->
          projectFindView.replaceEditor.setText('sunshine')
          projectFindView.trigger 'project-find:replace-all'
          expect(projectFindView.errorMessages).not.toBeVisible()

          waitsForPromise ->
            replacePromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView

            expect(resultsView).toBeVisible()
            expect(resultsView.find("li > ul > li")).toHaveLength(0)

            expect(projectFindView.infoMessages.find('li').text()).toBe "Replaced 13 results in 2 files"

            sampleJsContent = fs.read sampleJs
            expect(sampleJsContent.match(/items/g)).toBeFalsy()
            expect(sampleJsContent.match(/sunshine/g)).toHaveLength 6

            sampleCoffeeContent = fs.read sampleCoffee
            expect(sampleCoffeeContent.match(/items/g)).toBeFalsy()
            expect(sampleCoffeeContent.match(/sunshine/g)).toHaveLength 7
