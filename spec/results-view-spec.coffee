path = require 'path'
{_, WorkspaceView} = require 'atom'
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
    pack = atom.packages.activatePackage("find-and-replace", immediate: true)
    projectFindView = pack.mainModule.projectFindView
    spy = spyOn(projectFindView, 'confirm').andCallFake ->
      searchPromise = spy.originalValue.call(projectFindView)

    atom.workspaceView.trigger 'project-find:show'

  describe "when the result is for a long line", ->
    it "renders the context around the match", ->
      projectFindView.findEditor.setText('ghijkl')
      projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

        expect(resultsView.find('.preview').length).toBe 1
        expect(resultsView.find('.preview').text()).toBe 'a b c d e f g h i j k l abcdefghijklmnopqrstuvwxyz'
        expect(resultsView.find('.match').text()).toBe 'ghijkl'

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
    describe "when nothing is selected", ->
      beforeEach ->
        projectFindView.findEditor.setText('items')
        projectFindView.trigger 'core:confirm'

      it "doesnt error when the user arrows down", ->
        waitsForPromise ->
          searchPromise

        runs ->
          resultsView = getResultsView()
          resultsView.find('.selected').removeClass('selected')
          expect(resultsView.find('.selected')).not.toExist()
          resultsView.trigger 'core:move-down'
          expect(resultsView.find('.selected')).toExist()

      it "doesnt error when the user arrows up", ->
        waitsForPromise ->
          searchPromise

        runs ->
          resultsView = getResultsView()
          resultsView.find('.selected').removeClass('selected')
          expect(resultsView.find('.selected')).not.toExist()
          resultsView.trigger 'core:move-up'
          expect(resultsView.find('.selected')).toExist()

    it "arrows through the list without selecting paths", ->
      atom.workspaceView.openSync('sample.js')
      projectFindView.findEditor.setText('items')
      projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()
        resultsView.selectFirstResult()

        # open something in sample.coffee
        _.times 3, -> resultsView.trigger 'core:move-down'
        resultsView.trigger 'core:confirm'

        activePane = atom.workspaceView.getActivePane()
        expect(activePane[0]).toBe atom.workspaceView.getPanes()[0][0]
        expect(atom.workspaceView.getActiveView().getPath()).toContain('sample.')

        # open something in sample.js
        resultsView.focus()
        _.times 6, -> resultsView.trigger 'core:move-down'
        resultsView.trigger 'core:confirm'

        activePane = atom.workspaceView.getActivePane()
        expect(activePane[0]).toBe atom.workspaceView.getPanes()[0][0]
        expect(atom.workspaceView.getActiveView().getPath()).toContain('sample.')

    it "arrows through the list without selecting paths", ->
      atom.workspaceView.openSync('sample.js')
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

    it "moves to the proper next search-result when a path is selected", ->
      projectFindView.findEditor.setText('items')
      projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()
        resultsView.find('.selected').removeClass('selected')
        resultsView.find('.path:eq(0)').addClass('selected')

        resultsView.trigger 'core:move-up'
        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('path') # it's the same path

        resultsView.trigger 'core:move-down'

        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('search-result')
        expect(selectedItem[0]).toBe resultsView.find('.path:eq(0) .search-result:first')[0]

    it "moves to the proper previous search-result when a path is selected", ->
      projectFindView.findEditor.setText('items')
      projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()
        resultsView.find('.selected').removeClass('selected')
        resultsView.find('.path:eq(1)').addClass('selected')

        resultsView.trigger 'core:move-up'

        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('search-result')
        expect(selectedItem[0]).toBe resultsView.find('.path:eq(0) .search-result:last')[0]
