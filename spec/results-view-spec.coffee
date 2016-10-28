path = require 'path'
_ = require 'underscore-plus'
{$} = require 'atom-space-pen-views'
temp = require "temp"

ResultsPaneView = require '../lib/project/results-pane'
FileIcons = require '../lib/file-icons'

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

  describe "result sorting", ->
    beforeEach ->
      projectFindView.findEditor.setText('i')
      atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()

    describe "when shouldRenderMoreResults is true", ->
      beforeEach ->
        spyOn(resultsView, 'shouldRenderMoreResults').andReturn(true)

      it "displays the results in sorted order", ->
        match =
          range: [[0, 0], [0, 3]]
          lineText: 'abcdef'
          lineTextOffset: 0
          matchText: 'abc'

        pathNames = (el.textContent for el in resultsView.find(".path-name"))
        expect(pathNames).toHaveLength 3
        expect(pathNames[0]).toContain 'one-long-line.coffee'
        expect(pathNames[1]).toContain 'sample.coffee'
        expect(pathNames[2]).toContain 'sample.js'

        expect(resultsView.find('.search-result:first')).toHaveClass 'selected'

        # at the beginning
        firstResult = path.resolve('/a')
        projectFindView.model.addResult(firstResult, matches: [match])
        expect(resultsView.find(".path-name")[0].textContent).toContain firstResult
        expect(resultsView.find('.search-result:first')).toHaveClass 'selected'

        # at the end
        lastResult = path.resolve('/z')
        projectFindView.model.addResult(lastResult, matches: [match])
        expect(resultsView.find(".path-name")[4].textContent).toContain lastResult
        expect(resultsView.find('.search-result:first')).toHaveClass 'selected'

        # 2nd to last
        almostLastResult = path.resolve('/x')
        projectFindView.model.addResult(almostLastResult, matches: [match])
        expect(resultsView.find(".path-name")[4].textContent).toContain almostLastResult
        expect(resultsView.find('.search-result:first')).toHaveClass 'selected'

    describe "when shouldRenderMoreResults is false", ->
      beforeEach ->
        spyOn(resultsView, 'shouldRenderMoreResults').andReturn(false)

      it "only renders new items within the currently displayed results", ->
        dirname = path.dirname(projectFindView.model.getPaths()[0])
        pathNames = (el.textContent for el in resultsView.find(".path-name"))
        expect(pathNames).toHaveLength 3
        expect(pathNames[0]).toContain 'one-long-line.coffee'
        expect(pathNames[1]).toContain 'sample.coffee'
        expect(pathNames[2]).toContain 'sample.js'

        # nope, not at the end
        projectFindView.model.addResult(path.resolve('/z'), matches: [])
        expect(resultsView.find(".path-name")).toHaveLength 3

        # yes, at the beginning
        firstResult = path.resolve('/a')
        projectFindView.model.addResult(firstResult, matches: [])
        expect(resultsView.find(".path-name")).toHaveLength 4
        expect(resultsView.find(".path-name")[0].textContent).toContain firstResult

        # yes, in the middle
        projectFindView.model.addResult(path.resolve("#{dirname}/ppppp"), matches: [])
        expect(resultsView.find(".path-name")).toHaveLength 5
        expect(resultsView.find(".path-name")[2].textContent).toContain 'ppppp'

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

    describe "core:page-up and core:page-down", ->
      beforeEach ->
        workspaceElement.style.height = '300px'
        workspaceElement.style.width = '1024px'
        projectFindView.findEditor.setText(' ')
        projectFindView.confirm()

        waitsForPromise ->
          searchPromise

        runs ->
          resultsView = getResultsView()
          expect(resultsView.prop('scrollTop')).toBe 0
          expect(resultsView.prop('scrollHeight')).toBeGreaterThan resultsView.height()

      it "selects the first result on the next page when core:page-down is triggered", ->
        itemHeight = resultsView.find('.selected').outerHeight()
        pageHeight = Math.round(resultsView.innerHeight() / itemHeight) * itemHeight
        expect(resultsView.find("li").length).toBeLessThan resultsView.getPathCount() + resultsView.getMatchCount()

        resultLis = resultsView.find("li")
        getSelectedIndex = ->
          resultLis.index(resultsView.find('.selected'))

        initialIndex = getSelectedIndex()
        atom.commands.dispatch resultsView.element, 'core:page-down'
        newIndex = getSelectedIndex()
        expect(resultsView.find("li:eq(#{initialIndex})")).not.toHaveClass 'selected'
        expect(resultsView.find("li:eq(#{newIndex})")).toHaveClass 'selected'
        expect(resultsView.prop('scrollTop')).toBe pageHeight
        expect(newIndex).toBeGreaterThan initialIndex

        initialIndex = getSelectedIndex()
        atom.commands.dispatch resultsView.element, 'core:page-down'
        newIndex = getSelectedIndex()
        expect(resultsView.find("li:eq(#{initialIndex})")).not.toHaveClass 'selected'
        expect(resultsView.find("li:eq(#{newIndex})")).toHaveClass 'selected'
        expect(resultsView.prop('scrollTop')).toBe pageHeight * 2
        expect(newIndex).toBeGreaterThan initialIndex

        _.times 60, ->
          atom.commands.dispatch resultsView.element, 'core:page-down'

        expect(resultsView.find("li:last")).toHaveClass 'selected'

      it "selects the first result on the next page when core:page-up is triggered", ->
        atom.commands.dispatch resultsView.element, 'core:move-to-bottom'

        itemHeight = resultsView.find('.selected').outerHeight()
        pageHeight = Math.round(resultsView.innerHeight() / itemHeight) * itemHeight
        initialScrollTop = resultsView.scrollTop()
        itemsPerPage = Math.floor(pageHeight / itemHeight)

        initiallySelectedIndex = Math.floor(initialScrollTop / itemHeight) + itemsPerPage
        expect(resultsView.find("li:eq(#{initiallySelectedIndex})")).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:page-up'
        expect(resultsView.find("li:eq(#{initiallySelectedIndex})")).not.toHaveClass 'selected'
        expect(resultsView.find("li:eq(#{initiallySelectedIndex - itemsPerPage})")).toHaveClass 'selected'
        expect(resultsView.prop('scrollTop')).toBe initialScrollTop - pageHeight

        atom.commands.dispatch resultsView.element, 'core:page-up'
        expect(resultsView.find("li:eq(#{initiallySelectedIndex - itemsPerPage})")).not.toHaveClass 'selected'
        expect(resultsView.find("li:eq(#{initiallySelectedIndex - itemsPerPage * 2})")).toHaveClass 'selected'
        expect(resultsView.prop('scrollTop')).toBe initialScrollTop - pageHeight * 2

        _.times 60, ->
          atom.commands.dispatch resultsView.element, 'core:page-up'

        expect(resultsView.find("li:eq(0)")).toHaveClass 'selected'

    describe "core:move-to-top and core:move-to-bottom", ->
      beforeEach ->
        workspaceElement.style.height = '200px'
        projectFindView.findEditor.setText('so')
        projectFindView.confirm()

        waitsForPromise ->
          searchPromise

        runs ->
          resultsView = getResultsView()

      it "renders all results and selects the last item when core:move-to-bottom is triggered; selects the first item when core:move-to-top is triggered", ->
        expect(resultsView.find("li").length).toBeLessThan resultsView.getPathCount() + resultsView.getMatchCount()

        atom.commands.dispatch resultsView.element, 'core:move-to-bottom'
        expect(resultsView.find("li").length).toBe resultsView.getPathCount() + resultsView.getMatchCount()
        expect(resultsView.find("li:eq(1)")).not.toHaveClass 'selected'
        expect(resultsView.find("li:last")).toHaveClass 'selected'
        expect(resultsView.prop('scrollTop')).not.toBe 0

        atom.commands.dispatch resultsView.element, 'core:move-to-top'
        expect(resultsView.find("li:eq(1)")).toHaveClass 'selected'
        expect(resultsView.prop('scrollTop')).toBe 0

      it "selects the path when when core:move-to-bottom is triggered and last item is collapsed", ->
        atom.commands.dispatch resultsView.element, 'core:move-to-bottom'
        atom.commands.dispatch resultsView.element, 'core:move-left'
        atom.commands.dispatch resultsView.element, 'core:move-to-bottom'

        expect(resultsView.find("li:last").closest('.path')).toHaveClass 'selected'

      it "selects the path when when core:move-to-bottom is triggered and last item is collapsed", ->
        atom.commands.dispatch resultsView.element, 'core:move-to-top'
        atom.commands.dispatch resultsView.element, 'core:move-left'
        atom.commands.dispatch resultsView.element, 'core:move-to-top'

        expect(resultsView.find("li:first").closest('.path')).toHaveClass 'selected'

  describe "opening results", ->
    openHandler = null
    beforeEach ->
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
        openHandler.reset()

    it "opens the correct file containing the result when 'core:confirm' is called", ->
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

    it "opens the file containing the result in non-pending state when the search result is double-clicked", ->
      pathNode = resultsView.find(".search-result")[0]
      pathNode.dispatchEvent(buildMouseEvent('mousedown', target: pathNode, detail: 1))
      pathNode.dispatchEvent(buildMouseEvent('mousedown', target: pathNode, detail: 2))
      editor = null
      waitsFor ->
        editor = atom.workspace.getActiveTextEditor()
      waitsFor ->
        atom.workspace.getActivePane().getPendingItem() is null

      runs ->
        expect(atom.views.getView(editor)).toHaveFocus()

    describe "when `openProjectFindResultsInRightPane` option is true", ->
      beforeEach ->
        atom.config.set('find-and-replace.openProjectFindResultsInRightPane', true)

      it "always opens the file in the left pane", ->
        spyOn(atom.workspace, 'open').andCallThrough()
        atom.commands.dispatch resultsView.element, 'core:move-down'
        atom.commands.dispatch resultsView.element, 'core:confirm'
        expect(atom.workspace.open.mostRecentCall.args[1].split).toBe 'left'

      describe "when a search result is single-clicked", ->
        it "opens the file containing the result in pending state", ->
          pathNode = resultsView.find(".search-result")[0]
          pathNode.dispatchEvent(buildMouseEvent('mousedown', target: pathNode, which: 1))
          editor = null
          waitsFor ->
            editor = atom.workspace.getActiveTextEditor()
          waitsFor ->
            atom.workspace.getActivePane().getPendingItem() is editor

          runs ->
            expect(atom.views.getView(editor)).toHaveFocus()

    describe "when `openProjectFindResultsInRightPane` option is false", ->
      beforeEach ->
        atom.config.set('find-and-replace.openProjectFindResultsInRightPane', false)

      it "does not specify a pane to split", ->
        spyOn(atom.workspace, 'open').andCallThrough()
        atom.commands.dispatch resultsView.element, 'core:move-down'
        atom.commands.dispatch resultsView.element, 'core:confirm'
        expect(atom.workspace.open.mostRecentCall.args[1]).toEqual {}

  describe "arrowing through the list", ->
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

        # moves down for 13 results + 2 files
        _.times length + 1, -> atom.commands.dispatch resultsView.element, 'core:move-down'
        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('search-result')
        expect(selectedItem[0]).not.toBe lastSelectedItem

        lastSelectedItem = selectedItem[0]

        # stays at the bottom
        _.times 2, -> atom.commands.dispatch resultsView.element, 'core:move-down'
        selectedItem = resultsView.find('.selected')
        expect(selectedItem[0]).toBe lastSelectedItem

        lastSelectedItem = selectedItem[0]

        # moves up to the top
        _.times length + 1, -> atom.commands.dispatch resultsView.element, 'core:move-up'
        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('path')
        expect(selectedItem[0]).not.toBe lastSelectedItem

        lastSelectedItem = selectedItem[0]

        # stays at the top
        _.times 2, -> atom.commands.dispatch resultsView.element, 'core:move-up'
        selectedItem = resultsView.find('.selected')
        expect(selectedItem[0]).toBe lastSelectedItem

    describe "when there are hidden .path elements", ->
      beforeEach ->
        projectFindView.findEditor.setText('i')
        atom.commands.dispatch projectFindView.element, 'core:confirm'
        waitsForPromise -> searchPromise
        runs -> resultsView = getResultsView()

      it "ignores the invisible path elements", ->
        resultsView.find('.path:eq(1)').hide()

        atom.commands.dispatch resultsView.element, 'core:move-down'
        expect(resultsView.find('.path:eq(0) .search-result:eq(1)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-down'
        expect(resultsView.find('.path:eq(2)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-down'
        expect(resultsView.find('.path:eq(2) .search-result:eq(0)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-down'
        expect(resultsView.find('.path:eq(2) .search-result:eq(1)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-up'
        expect(resultsView.find('.path:eq(2) .search-result:eq(0)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-up'
        expect(resultsView.find('.path:eq(2)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-up'
        expect(resultsView.find('.path:eq(0) .search-result:eq(1)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-down'
        atom.commands.dispatch resultsView.element, 'core:move-left'
        expect(resultsView.find('.path:eq(2)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-up'
        expect(resultsView.find('.path:eq(0) .search-result:eq(1)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-down'
        expect(resultsView.find('.path:eq(2)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-up'
        atom.commands.dispatch resultsView.element, 'core:move-left'
        expect(resultsView.find('.path:eq(0)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-down'
        expect(resultsView.find('.path:eq(2)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-down'
        expect(resultsView.find('.path:eq(2)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-up'
        expect(resultsView.find('.path:eq(0)')).toHaveClass 'selected'

        atom.commands.dispatch resultsView.element, 'core:move-up'
        expect(resultsView.find('.path:eq(0)')).toHaveClass 'selected'

    describe "when there are a list of items", ->
      beforeEach ->
        projectFindView.findEditor.setText('items')
        atom.commands.dispatch projectFindView.element, 'core:confirm'
        waitsForPromise -> searchPromise
        runs -> resultsView = getResultsView()

      it "shows the preview-controls", ->
        previewControls = resultsView.parentView.previewControls
        expect(previewControls.isVisible()).toBe(true)

      it "collapses the selected results view", ->
        # select item in first list
        resultsView.find('.selected').removeClass('selected')
        resultsView.find('.path:eq(0) .search-result:first').addClass('selected')

        atom.commands.dispatch resultsView.element, 'core:move-left'

        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('collapsed')
        expect(selectedItem.element).toBe resultsView.find('.path:eq(0)').element

      it "collapses all results if collapse All button is pressed", ->
        collapseAll = resultsView.parentView.collapseAll
        results = resultsView.find('.list-nested-item')
        collapseAll.click()
        expect(results).toHaveClass('collapsed')

      it "expands the selected results view", ->
        # select item in first list
        resultsView.find('.selected').removeClass('selected')
        resultsView.find('.path:eq(0)').addClass('selected').addClass('collapsed')

        atom.commands.dispatch resultsView.element, 'core:move-right'

        selectedItem = resultsView.find('.selected')
        expect(selectedItem).toHaveClass('search-result')
        expect(selectedItem[0]).toBe resultsView.find('.path:eq(0) .search-result:first')[0]

      it "expands all results if 'Expand All' button is pressed", ->
        expandAll = resultsView.parentView.expandAll
        results = resultsView.find('.list-nested-item')
        expandAll.click()
        expect(results).not.toHaveClass('collapsed')

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
          expect(resultsView.find('.path:eq(1)')).toHaveClass 'selected'

          atom.commands.dispatch resultsView.element, 'core:move-up'
          expect(resultsView.find('.path:eq(0)')).toHaveClass 'selected'

  describe "when the results view is empty", ->
    it "ignores core:confirm events", ->
      projectFindView.findEditor.setText('thiswillnotmatchanythingintheproject')
      atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        resultsView = getResultsView()
        expect(-> atom.commands.dispatch resultsView.element, 'core:confirm').not.toThrow()

    it "won't show the preview-controls", ->
      projectFindView.findEditor.setText('thiswillnotmatchanythingintheproject')
      atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
        previewControls = getResultsView().parentView.previewControls
        expect(previewControls.isVisible()).toBe(false)

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

  describe "icon-service lifecycle", ->
    it 'renders file icon classes based on the provided file-icons service', ->
      fileIconsDisposable = atom.packages.serviceHub.provide 'atom.file-icons', '1.0.0', {
        iconClassForPath: (path, context) ->
          expect(context).toBe "find-and-replace"
          if path.endsWith('sample.js')
            "first-icon-class second-icon-class"
          else
            ['third-icon-class', 'fourth-icon-class']
      }
      projectFindView.findEditor.setText('i')
      atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise -> searchPromise
      runs ->
        resultsView = getResultsView()
        fileIconClasses = Array.from(resultsView.find('.path-details .icon').map -> @className)
        expect(fileIconClasses).toContain('first-icon-class second-icon-class icon')
        expect(fileIconClasses).toContain('third-icon-class fourth-icon-class icon')
        expect(fileIconClasses).not.toContain('icon-file-text icon')

      runs ->
        fileIconsDisposable.dispose()
        projectFindView.findEditor.setText('e')
        atom.commands.dispatch projectFindView.element, 'core:confirm'

      waitsForPromise -> searchPromise
      runs ->
        resultsView = getResultsView()
        fileIconClasses = Array.from(resultsView.find('.path-details .icon').map -> @className)
        expect(fileIconClasses).not.toContain('first-icon-class second-icon-class icon')
        expect(fileIconClasses).not.toContain('third-icon-class fourth-icon-class icon')
        expect(fileIconClasses).toContain('icon-file-text icon')

  # Keep. Useful for debugging.
  logSelectedIndex = ->
    paths = resultsView.find('.path')
    selectedView = resultsView.find('.selected')

    if selectedView.hasClass('path')
      console.log 'PATH', paths.index(selectedView)
    else
      for pathElement, pathIndex in paths
        index = $(pathElement).find('.search-result').index(selectedView)
        console.log pathIndex, index if index > -1
        break

buildMouseEvent = (type, properties...) ->
  properties = _.extend({bubbles: true, cancelable: true}, properties...)
  properties.detail ?= 1
  event = new MouseEvent(type, properties)
  Object.defineProperty(event, 'which', get: -> properties.which) if properties.which?
  if properties.target?
    Object.defineProperty(event, 'target', get: -> properties.target)
    Object.defineProperty(event, 'srcObject', get: -> properties.target)
  event
