{RootView} = require 'atom-api'

describe 'PreviewList', ->
  [projectFindView, previewList] = []

  beforeEach ->
    window.rootView = new RootView()
    rootView.attachToDom()
    editor = rootView.getActiveView()
    pack = atom.activatePackage("find-and-replace")
    projectFindView = pack.mainModule.projectFindView
    previewList = projectFindView.previewList

    rootView.trigger 'project-find:show'

  describe "when list is scrollable", ->
    it "adds more operations to the DOM when `scrollBottom` nears the `pixelOverdraw`", ->
      waitsForPromise ->
        projectFindView.findEditor.setText(' ')
        projectFindView.confirm()

      runs ->
        expect(previewList.prop('scrollHeight')).toBeGreaterThan previewList.height()
        previousScrollHeight = previewList.prop('scrollHeight')
        previousOperationCount = previewList.find("li").length

        previewList.scrollTop(previewList.pixelOverdraw / 2)
        previewList.trigger('scroll') # Not sure why scroll event isn't being triggered on it's own
        expect(previewList.prop('scrollHeight')).toBe previousScrollHeight
        expect(previewList.find("li").length).toBe previousOperationCount

        previewList.scrollToBottom()
        previewList.trigger('scroll') # Not sure why scroll event isn't being triggered on it's own
        expect(previewList.prop('scrollHeight')).toBeGreaterThan previousScrollHeight
        expect(previewList.find("li").length).toBeGreaterThan previousOperationCount

    it "renders all operations when core:move-to-bottom is triggered", ->
      waitsForPromise ->
        projectFindView.findEditor.setText('so')
        projectFindView.confirm()

      runs ->
        expect(previewList.prop('scrollHeight')).toBeGreaterThan previewList.height()
        previousScrollHeight = previewList.prop('scrollHeight')
        previewList.trigger 'core:move-to-bottom'
        liCount = previewList.getPathCount() + previewList.getResults().length
        expect(previewList.find("li").length).toBe liCount
