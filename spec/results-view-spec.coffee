{RootView} = require 'atom'

describe 'ResultsView', ->
  [projectFindView, resultsView, searchPromise] = []

  beforeEach ->
    window.rootView = new RootView()
    rootView.attachToDom()
    pack = atom.activatePackage("find-and-replace")
    projectFindView = pack.mainModule.projectFindView
    resultsView = projectFindView.resultsView

    spy = spyOn(projectFindView, 'confirm').andCallFake ->
      searchPromise = spy.originalValue.call(projectFindView)


    rootView.trigger 'project-find:show'

  describe "when list is scrollable", ->
    it "adds more operations to the DOM when `scrollBottom` nears the `pixelOverdraw`", ->
      projectFindView.findEditor.setText(' ')
      projectFindView.trigger 'core:confirm'

      waitsForPromise ->
        searchPromise

      runs ->
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
      projectFindView.findEditor.setText('so')
      projectFindView.confirm()

      waitsForPromise ->
        searchPromise

      runs ->
        expect(resultsView.prop('scrollHeight')).toBeGreaterThan resultsView.height()
        previousScrollHeight = resultsView.prop('scrollHeight')
        resultsView.trigger 'core:move-to-bottom'
        expect(resultsView.find("li").length).toBe resultsView.getPathCount() + resultsView.getMatchCount()
