path = require 'path'
_ = require 'underscore-plus'
temp = require "temp"

ResultsPaneView = require '../lib/project/results-pane'

# Default to 30 second promises
waitsForPromise = (fn) -> window.waitsForPromise timeout: 30000, fn

describe 'ResultsView', ->
  [pack, projectFindView, resultsView, searchPromise, workspaceElement] = []

  getExistingResultsPane = ->
    pane = atom.workspace.paneForURI(ResultsPaneView.URI)
    return pane.itemForURI(ResultsPaneView.URI) if pane?
    null

  getResultsView = ->
    resultsView = getExistingResultsPane().resultsView

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.style.height = '1000px'
    jasmine.attachToDOM(workspaceElement)
    atom.project.setPaths([path.join(__dirname, 'fixtures')])
    promise = atom.packages.activatePackage("find-and-replace").then ({mainModule}) ->
      mainModule.createViews()
      {projectFindView} = mainModule
      spy = spyOn(projectFindView, 'confirm').andCallFake ->
        searchPromise = spy.originalValue.call(projectFindView)

    atom.commands.dispatch workspaceElement, 'project-find:show'

    waitsForPromise ->
      promise

  describe "when the result is for a long line", ->
    it "renders the context around the match", ->
      projectFindView.findEditor.setText('ghijkl')
      atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.find('.path-name').text()).toBe "one-long-line.coffee"
        expect(resultsView.find('.preview').length).toBe 1
        expect(resultsView.find('.preview').text()).toBe 'test test test test test test test test test test test a b c d e f g h i j k l abcdefghijklmnopqrstuvwxyz'
        expect(resultsView.find('.match').text()).toBe 'ghijkl'

  describe "when there are multiple project paths", ->
    beforeEach ->
      atom.project.addPath(temp.mkdirSync("another-project-path"))

    it "includes the basename of the project path that contains the match", ->
      projectFindView.findEditor.setText('ghijkl')
      atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()
        expect(resultsView.find('.path-name').text()).toBe path.join("fixtures", "one-long-line.coffee")

  describe "rendering replacement text", ->
    modifiedDelay = null
    beforeEach ->
      projectFindView.findEditor.setText('ghijkl')
      modifiedDelay = projectFindView.replaceEditor.getModel().getBuffer().stoppedChangingDelay

    it "renders the replacement when doing a search and there is a replacement pattern", ->
      projectFindView.replaceEditor.setText('cats')
      atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.find('.path-name').text()).toBe "one-long-line.coffee"
        expect(resultsView.find('.preview').length).toBe 1
        expect(resultsView.find('.match').text()).toBe 'ghijkl'
        expect(resultsView.find('.replacement').text()).toBe 'cats'

    it "renders the replacement when changing the text in the replacement field", ->
      atom.commands.dispatch projectFindView.element, 'core:confirm'

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
    it "adds more results to the DOM when scrolling", ->
      projectFindView.findEditor.setText(' ')
      atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.prop('scrollHeight')).toBeGreaterThan resultsView.height()
        previousScrollHeight = resultsView.prop('scrollHeight')
        previousOperationCount = resultsView.find("li").length

        resultsView.scrollTop(resultsView.pixelOverdraw * 2)
        resultsView.trigger('scroll') # Not sure why scroll event isn't being triggered on it's own
        expect(resultsView.prop('scrollHeight')).toBeGreaterThan previousScrollHeight
        expect(resultsView.find("li").length).toBeGreaterThan previousOperationCount

    it "adds more results to the DOM when scrolled to bottom", ->
      projectFindView.findEditor.setText(' ')
      atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.prop('scrollHeight')).toBeGreaterThan resultsView.height()
        previousScrollHeight = resultsView.prop('scrollHeight')
        previousOperationCount = resultsView.find("li").length

        resultsView.scrollToBottom()
        resultsView.trigger('scroll') # Not sure why scroll event isn't being triggered on it's own
        expect(resultsView.prop('scrollHeight')).toBeGreaterThan previousScrollHeight
        expect(resultsView.find("li").length).toBeGreaterThan previousOperationCount

    it "renders more results when a result is collapsed via core:move-left", ->
      projectFindView.findEditor.setText(' ')
      projectFindView.confirm()

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.find(".path").length).toBe 1

        pathNode = resultsView.find(".path")[0]
        pathNode.dispatchEvent(buildMouseEvent('mousedown', target: pathNode, which: 1))
        expect(resultsView.find(".path").length).toBe 2

        pathNode = resultsView.find(".path")[1]
        pathNode.dispatchEvent(buildMouseEvent('mousedown', target: pathNode, which: 1))
        expect(resultsView.find(".path").length).toBe 3

    it "renders more results when a result is collapsed via click", ->
      projectFindView.findEditor.setText(' ')
      projectFindView.confirm()

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.find(".path-details").length).toBe 1

        atom.commands.dispatch resultsView.element, 'core:move-down'
        atom.commands.dispatch resultsView.element, 'core:move-left'

        expect(resultsView.find(".path-details").length).toBe 2

        atom.commands.dispatch resultsView.element, 'core:move-down'
        atom.commands.dispatch resultsView.element, 'core:move-left'

        expect(resultsView.find(".path-details").length).toBe 3

    it "renders all results when core:move-to-bottom is triggered", ->
      workspaceElement.style.height = '300px'
      projectFindView.findEditor.setText('so')
      projectFindView.confirm()

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.prop('scrollHeight')).toBeGreaterThan resultsView.height()
        previousScrollHeight = resultsView.prop('scrollHeight')
        atom.commands.dispatch resultsView.element, 'core:move-to-bottom'
        expect(resultsView.find("li").length).toBe resultsView.getPathCount() + resultsView.getMatchCount()

  describe "arrowing through the list", ->
    resultsView = null

    it "opens the correct file containing the result when 'core:confirm' is called", ->
      openHandler = null

      waitsForPromise ->
        atom.workspace.open('sample.js')

      runs ->
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch projectFindView.element, 'core:confirm'
        openHandler = jasmine.createSpy("open handler")
        atom.workspace.onDidOpen openHandler

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()
        resultsView.selectFirstResult()

        # open something in sample.coffee
        _.times 3, -> atom.commands.dispatch resultsView.element, 'core:move-down'
        openHandler.reset()
        atom.commands.dispatch resultsView.element, 'core:confirm'

      waitsFor ->
        openHandler.callCount is 1

      runs ->
        expect(atom.workspace.getActivePaneItem().getPath()).toContain('sample.')

        # open something in sample.js
        resultsView.focus()
        _.times 6, -> atom.commands.dispatch resultsView.element, 'core:move-down'
        openHandler.reset()
        atom.commands.dispatch resultsView.element, 'core:confirm'

      waitsFor ->
        openHandler.callCount is 1

      runs ->
        expect(atom.workspace.getActivePaneItem().getPath()).toContain('sample.')

    it "arrows through the entire list without selecting paths and overshooting the boundaries", ->
      waitsForPromise ->
        atom.workspace.open('sample.js')

      runs ->
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch projectFindView.element, 'core:confirm'

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
          atom.commands.dispatch resultsView.element, 'core:move-down'

          selectedItem = resultsView.find('.selected')

          expect(selectedItem).toHaveClass('search-result')
          expect(selectedItem[0]).not.toBe lastSelectedItem

          lastSelectedItem = selectedItem[0]

        # stays at the bottom
        _.times 2, ->
          atom.commands.dispatch resultsView.element, 'core:move-down'

          selectedItem = resultsView.find('.selected')
          expect(selectedItem[0]).toBe lastSelectedItem

          lastSelectedItem = selectedItem[0]

        # moves up to the top
        _.times length - 1, ->
          atom.commands.dispatch resultsView.element, 'core:move-up'

          selectedItem = resultsView.find('.selected')

          expect(selectedItem).toHaveClass('search-result')
          expect(selectedItem[0]).not.toBe lastSelectedItem

          lastSelectedItem = selectedItem[0]

        # stays at the top
        _.times 2, ->
          atom.commands.dispatch resultsView.element, 'core:move-up'

          selectedItem = resultsView.find('.selected')

          expect(selectedItem[0]).toBe lastSelectedItem

          lastSelectedItem = selectedItem[0]

    describe "when there are a list of items", ->
      beforeEach ->
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch projectFindView.element, 'core:confirm'
        waitsForPromise -> searchPromise
        runs -> resultsView = getResultsView()

      it "collapses the selected results view", ->
        # select item in first list
        resultsView.find('.selected').removeClass('selected')
        resultsView.find('.path:eq(0) .search-result:first').addClass('selected')

        atom.commands.dispatch resultsView.element, 'core:move-left'

        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('collapsed')
        expect(selectedItem.element).toBe resultsView.find('.path:eq(0)').element

      it "expands the selected results view", ->
        # select item in first list
        resultsView.find('.selected').removeClass('selected')
        resultsView.find('.path:eq(0)').addClass('selected').addClass('collapsed')

        atom.commands.dispatch resultsView.element, 'core:move-right'

        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('search-result')
        expect(selectedItem[0]).toBe resultsView.find('.path:eq(0) .search-result:first')[0]

      describe "when nothing is selected", ->
        it "doesnt error when the user arrows down", ->
          resultsView.find('.selected').removeClass('selected')
          expect(resultsView.find('.selected')).not.toExist()
          atom.commands.dispatch resultsView.element, 'core:move-down'
          expect(resultsView.find('.selected')).toExist()

        it "doesnt error when the user arrows up", ->
          resultsView.find('.selected').removeClass('selected')
          expect(resultsView.find('.selected')).not.toExist()
          atom.commands.dispatch resultsView.element, 'core:move-up'
          expect(resultsView.find('.selected')).toExist()

      describe "when there are collapsed results", ->
        it "moves to the correct next result when a path is selected", ->
          resultsView.find('.selected').removeClass('selected')
          resultsView.find('.path:eq(0) .search-result:last').addClass('selected')
          resultsView.find('.path:eq(1)').view().expand(false)

          atom.commands.dispatch resultsView.element, 'core:move-down'

          selectedItem = resultsView.find('.selected')
          expect(selectedItem).toHaveClass('path')
          expect(selectedItem[0]).toBe resultsView.find('.path:eq(1)')[0]

        it "moves to the correct previous result when a path is selected", ->
          resultsView.find('.selected').removeClass('selected')
          resultsView.find('.path:eq(1) .search-result:first').addClass('selected')
          resultsView.find('.path:eq(0)').view().expand(false)

          atom.commands.dispatch resultsView.element, 'core:move-up'

          selectedItem = resultsView.find('.selected')
          expect(selectedItem).toHaveClass('path')
          expect(selectedItem[0]).toBe resultsView.find('.path:eq(0)')[0]

  describe "when the results view is empty", ->
    it "ignores core:confirm events", ->
      projectFindView.findEditor.setText('thiswillnotmatchanythingintheproject')
      atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()
        expect(-> atom.commands.dispatch resultsView.element, 'core:confirm').not.toThrow()

  describe "copying items with core:copy", ->
    [resultsView, openHandler] = []

    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample.js')

      runs ->
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()
        resultsView.selectFirstResult()

    it "copies the selected line onto the clipboard", ->
      _.times 2, -> atom.commands.dispatch resultsView.element, 'core:move-down'
      atom.commands.dispatch resultsView.element, 'core:copy'
      expect(atom.clipboard.read()).toBe '    return items if items.length <= 1'

buildMouseEvent = (type, properties...) ->
  properties = _.extend({bubbles: true, cancelable: true}, properties...)
  properties.detail ?= 1
  event = new MouseEvent(type, properties)
  Object.defineProperty(event, 'which', get: -> properties.which) if properties.which?
  if properties.target?
    Object.defineProperty(event, 'target', get: -> properties.target)
    Object.defineProperty(event, 'srcObject', get: -> properties.target)
  event
