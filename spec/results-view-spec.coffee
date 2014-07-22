path = require 'path'
_ = require 'underscore-plus'
{WorkspaceView} = require 'atom'
path = require 'path'

ResultsPaneView = require '../lib/project/results-pane'

# Default to 30 second promises
waitsForPromise = (fn) -> window.waitsForPromise timeout: 30000, fn

describe 'ResultsView', ->
  [pack, projectFindView, resultsView, searchPromise] = []

  getExistingResultsPane = ->
    pane = atom.workspaceView.panes.paneForUri(ResultsPaneView.URI)
    return pane.itemForUri(ResultsPaneView.URI) if pane?
    null

  getResultsView = ->
    resultsView = getExistingResultsPane().resultsView

  beforeEach ->
    atom.workspaceView = new WorkspaceView()
    atom.workspaceView.height(1000)
    atom.project.setPath(path.join(__dirname, 'fixtures'))
    atom.workspaceView.attachToDom()
    promise = atom.packages.activatePackage("find-and-replace").then ({mainModule}) ->
      mainModule.createProjectFindView()
      {projectFindView} = mainModule
      spy = spyOn(projectFindView, 'confirm').andCallFake ->
        searchPromise = spy.originalValue.call(projectFindView)

    atom.workspaceView.trigger 'project-find:show'

    waitsForPromise ->
      promise

  describe "when the result is for a long line", ->
    it "renders the context around the match", ->
      projectFindView.findEditor.setText('ghijkl')
      projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.find('.preview').length).toBe 1
        expect(resultsView.find('.preview').text()).toBe 'test test test test test test test test test test test a b c d e f g h i j k l abcdefghijklmnopqrstuvwxyz'
        expect(resultsView.find('.match').text()).toBe 'ghijkl'

  describe "rendering replacement text", ->
    modifiedDelay = null
    beforeEach ->
      projectFindView.findEditor.setText('ghijkl')
      modifiedDelay = projectFindView.replaceEditor.getEditor().getBuffer().stoppedChangingDelay

    it "renders the replacement when doing a search and there is a replacement pattern", ->
      projectFindView.replaceEditor.setText('cats')
      projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.find('.preview').length).toBe 1
        expect(resultsView.find('.match').text()).toBe 'ghijkl'
        expect(resultsView.find('.replacement').text()).toBe 'cats'

    it "renders the replacement when changing the text in the replacement field", ->
      projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.find('.match').text()).toBe 'ghijkl'
        expect(resultsView.find('.match')).toHaveClass 'highlight-info'
        expect(resultsView.find('.replacement').text()).toBe ''
        expect(resultsView.find('.replacement')).toBeHidden()

        projectFindView.replaceEditor.setText('cats')
        advanceClock(modifiedDelay)

        expect(resultsView.find('.match').text()).toBe 'ghijkl'
        expect(resultsView.find('.match')).toHaveClass 'highlight-error'
        expect(resultsView.find('.replacement').text()).toBe 'cats'
        expect(resultsView.find('.replacement')).toBeVisible()

        projectFindView.replaceEditor.setText('')
        advanceClock(modifiedDelay)

        expect(resultsView.find('.match').text()).toBe 'ghijkl'
        expect(resultsView.find('.match')).toHaveClass 'highlight-info'
        expect(resultsView.find('.replacement')).toBeHidden()

  describe "when list is scrollable", ->
    it "adds more operations to the DOM when `scrollBottom` nears the `pixelOverdraw`", ->
      projectFindView.findEditor.setText(' ')
      projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.prop('scrollHeight')).toBeGreaterThan resultsView.height()
        previousScrollHeight = resultsView.prop('scrollHeight')
        previousOperationCount = resultsView.find("li").length

        resultsView.scrollTop(resultsView.pixelOverdraw / 2)
        resultsView.trigger('scroll') # Not sure why scroll event isn't being triggered on it's own
        expect(resultsView.prop('scrollHeight')).toBe previousScrollHeight
        expect(resultsView.find("li").length).toBe previousOperationCount

        resultsView.scrollToBottom()
        resultsView.trigger('scroll') # Not sure why scroll event isn't being triggered on it's own
        expect(resultsView.prop('scrollHeight')).toBeGreaterThan previousScrollHeight
        expect(resultsView.find("li").length).toBeGreaterThan previousOperationCount

    it "renders all operations when core:move-to-bottom is triggered", ->
      atom.workspaceView.height(300)
      projectFindView.findEditor.setText('so')
      projectFindView.confirm()

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.prop('scrollHeight')).toBeGreaterThan resultsView.height()
        previousScrollHeight = resultsView.prop('scrollHeight')
        resultsView.trigger 'core:move-to-bottom'
        expect(resultsView.find("li").length).toBe resultsView.getPathCount() + resultsView.getMatchCount()

  describe "arrowing through the list", ->
    resultsView = null

    it "opens the correct file containing the result when 'core:confirm' is called", ->
      openHandler = null

      waitsForPromise ->
        atom.workspace.open('sample.js')

      runs ->
        projectFindView.findEditor.setText('items')
        projectFindView.trigger 'core:confirm'
        openHandler = jasmine.createSpy("open handler")
        atom.workspaceView.model.on 'uri-opened', openHandler

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()
        resultsView.selectFirstResult()

        # open something in sample.coffee
        _.times 3, -> resultsView.trigger 'core:move-down'
        openHandler.reset()
        resultsView.trigger 'core:confirm'

      waitsFor ->
        openHandler.callCount == 1

      runs ->
        expect(atom.workspace.getActivePaneItem().getPath()).toContain('sample.')

        # open something in sample.js
        resultsView.focus()
        _.times 6, -> resultsView.trigger 'core:move-down'
        openHandler.reset()
        resultsView.trigger 'core:confirm'

      waitsFor ->
        openHandler.callCount == 1

      runs ->
        activePane = atom.workspaceView.getActivePaneView()
        expect(atom.workspace.getActivePaneItem().getPath()).toContain('sample.')

    it "arrows through the entire list without selecting paths and overshooting the boundaries", ->
      waitsForPromise ->
        atom.workspace.open('sample.js')

      runs ->
        projectFindView.findEditor.setText('items')
        projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        lastSelectedItem = null

        length = resultsView.find("li > ul > li").length
        expect(length).toBe 13

        resultsView.selectFirstResult()

        # moves down for 13 results
        _.times length - 1, ->
          resultsView.trigger 'core:move-down'

          selectedItem = resultsView.find('.selected')

          expect(selectedItem).toHaveClass('search-result')
          expect(selectedItem[0]).not.toBe lastSelectedItem

          lastSelectedItem = selectedItem[0]

        # stays at the bottom
        _.times 2, ->
          resultsView.trigger 'core:move-down'

          selectedItem = resultsView.find('.selected')

          expect(selectedItem[0]).toBe lastSelectedItem

          lastSelectedItem = selectedItem[0]

        # moves up to the top
        _.times length - 1, ->
          resultsView.trigger 'core:move-up'

          selectedItem = resultsView.find('.selected')

          expect(selectedItem).toHaveClass('search-result')
          expect(selectedItem[0]).not.toBe lastSelectedItem

          lastSelectedItem = selectedItem[0]

        # stays at the top
        _.times 2, ->
          resultsView.trigger 'core:move-up'

          selectedItem = resultsView.find('.selected')

          expect(selectedItem[0]).toBe lastSelectedItem

          lastSelectedItem = selectedItem[0]

    describe "when there are a list of items", ->
      beforeEach ->
        projectFindView.findEditor.setText('items')
        projectFindView.trigger 'core:confirm'
        waitsForPromise -> searchPromise
        runs -> resultsView = getResultsView()

      it "collapses the selected results view", ->
        # select item in first list
        resultsView.find('.selected').removeClass('selected')
        resultsView.find('.path:eq(0) .search-result:first').addClass('selected')

        resultsView.trigger 'core:move-left'

        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('collapsed')
        expect(selectedItem[0]).toBe resultsView.find('.path:eq(0)')[0]

      it "expands the selected results view", ->
        # select item in first list
        resultsView.find('.selected').removeClass('selected')
        resultsView.find('.path:eq(0)').addClass('selected').addClass('collapsed')

        resultsView.trigger 'core:move-right'

        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('search-result')
        expect(selectedItem[0]).toBe resultsView.find('.path:eq(0) .search-result:first')[0]

      describe "when nothing is selected", ->
        it "doesnt error when the user arrows down", ->
          resultsView.find('.selected').removeClass('selected')
          expect(resultsView.find('.selected')).not.toExist()
          resultsView.trigger 'core:move-down'
          expect(resultsView.find('.selected')).toExist()

        it "doesnt error when the user arrows up", ->
          resultsView.find('.selected').removeClass('selected')
          expect(resultsView.find('.selected')).not.toExist()
          resultsView.trigger 'core:move-up'
          expect(resultsView.find('.selected')).toExist()

      describe "when there are collapsed results", ->
        it "moves to the correct next result when a path is selected", ->
          resultsView.find('.selected').removeClass('selected')
          resultsView.find('.path:eq(0) .search-result:last').addClass('selected')
          resultsView.find('.path:eq(1)').view().expand(false)

          resultsView.trigger 'core:move-down'

          selectedItem = resultsView.find('.selected')
          expect(selectedItem).toHaveClass('path')
          expect(selectedItem[0]).toBe resultsView.find('.path:eq(1)')[0]

        it "moves to the correct previous result when a path is selected", ->
          resultsView.find('.selected').removeClass('selected')
          resultsView.find('.path:eq(1) .search-result:first').addClass('selected')
          resultsView.find('.path:eq(0)').view().expand(false)

          resultsView.trigger 'core:move-up'

          selectedItem = resultsView.find('.selected')
          expect(selectedItem).toHaveClass('path')
          expect(selectedItem[0]).toBe resultsView.find('.path:eq(0)')[0]

  describe "when the results view is empty", ->
    it "ignores core:confirm events", ->
      projectFindView.findEditor.setText('thiswillnotmatchanythingintheproject')
      projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()
        expect(-> resultsView.trigger('core:confirm')).not.toThrow()
