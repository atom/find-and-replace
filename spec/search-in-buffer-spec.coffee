RootView = require 'root-view'
SearchInBufferView = require 'search-in-buffer/lib/search-in-buffer'

ffdescribe 'SearchInBufferView', ->
  [subject, editor] = []

  beforeEach ->
    window.rootView = new RootView

  describe "with no editor", ->
    beforeEach ->
      subject = SearchInBufferView.activate()

    describe "when search-in-buffer:display-find is triggered", ->
      it "attaches to the root view", ->
        subject.showFind()
        expect(subject.hasParent()).toBeTruthy()
        expect(subject.resultCounter.text()).toEqual('')

  describe "with an editor", ->
    beforeEach ->
      rootView.open('sample.js')
      rootView.enableKeymap()
      editor = rootView.getActiveView()
      editor.attached = true #hack as I cant get attachToDom() to work

      subject = SearchInBufferView.activate()

    describe "when search-in-buffer:display-find is triggered", ->
      it "attaches to the root view", ->
        editor.trigger 'search-in-buffer:display-find'
        expect(subject.hasParent()).toBeTruthy()

    describe "running a search", ->
      beforeEach ->
        editor.trigger 'search-in-buffer:display-find'

      it "attaches to the root view", ->
        subject.miniEditor.textInput 'items'
        subject.miniEditor.trigger 'core:confirm'

        expect(subject.resultCounter.text()).toEqual('1 of 6')
        expect(editor.getSelectedBufferRange()).toEqual [[1, 22], [1, 27]]

