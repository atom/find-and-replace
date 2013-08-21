RootView = require 'root-view'

describe 'PreviewList', ->
  [subject, previewList] = []
  beforeEach ->
    window.rootView = new RootView
    rootView.attachToDom()
    FindAndReplace = atom.activatePackage('find-and-replace', immediate: true).mainModule

    subject = FindAndReplace.projectFindAndReplaceView
    previewList = subject.previewList

    rootView.trigger 'find-and-replace:display-find-in-project'

  describe "when list is scrollable", ->
    it "adds more operations to the DOM when `scrollBottom` nears the `pixelOverdraw`", ->
      waitsForPromise ->
        subject.findEditor.setText('so')
        subject.searchAndDisplayResults()

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

    it "renders all operations if the preview items are collapsed", ->
      waitsForPromise ->
        subject.findEditor.setText('so')
        subject.searchAndDisplayResults()

      runs ->
        expect(previewList.prop('scrollHeight')).toBeGreaterThan previewList.height()
        previousScrollHeight = previewList.prop('scrollHeight')
        previousOperationCount = previewList.find("li").length
        previewList.collapseAllPaths()
        expect(previewList.find("li").length).toBeGreaterThan previousOperationCount

    it "renders more operations when a preview item is collapsed", ->
      waitsForPromise ->
        subject.findEditor.setText('so')
        subject.searchAndDisplayResults()

      runs ->
        expect(previewList.prop('scrollHeight')).toBeGreaterThan previewList.height()
        previousScrollHeight = previewList.prop('scrollHeight')
        previousOperationCount = previewList.find("li").length
        previewList.trigger 'command-panel:collapse-result'
        expect(previewList.find("li").length).toBeGreaterThan previousOperationCount

    it "renders all operations when core:move-to-bottom is triggered", ->
      waitsForPromise ->
        subject.findEditor.setText('so')
        subject.searchAndDisplayResults()

      runs ->
        expect(previewList.prop('scrollHeight')).toBeGreaterThan previewList.height()
        previousScrollHeight = previewList.prop('scrollHeight')
        previewList.trigger 'core:move-to-bottom'
        liCount = previewList.getPathCount() + previewList.getResults().length
        expect(previewList.find("li").length).toBe liCount