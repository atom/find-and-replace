RootView = require 'root-view'
GoToLineView = require 'go-to-line/lib/go-to-line-view'

describe 'SearchInBufferView', ->
  [goToLine, editor] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    editor = rootView.getActiveView()
    atom.activatePackage('search-in-buffer', immediate: true)

    #goToLine = SearchInBufferView.activate()
    editor.setCursorBufferPosition([1,0])

  describe "when editor:go-to-line is triggered", ->
    it "attaches to the root view", ->
      expect(true).toBeFalsy()

  xdescribe "when entering a line number", ->
    it "only allows 0-9 to be entered in the mini editor", ->
      expect(goToLine.miniEditor.getText()).toBe ''
      goToLine.miniEditor.textInput 'a'
      expect(goToLine.miniEditor.getText()).toBe ''
      goToLine.miniEditor.textInput '40'
      expect(goToLine.miniEditor.getText()).toBe '40'

  xdescribe "when core:confirm is triggered", ->
    describe "when a line number has been entered", ->
      it "moves the cursor to the first character of the line", ->
        goToLine.miniEditor.textInput '3'
        goToLine.miniEditor.trigger 'core:confirm'
        expect(editor.getCursorBufferPosition()).toEqual [2, 4]

    describe "when no line number has been entered", ->
      it "closes the view and does not update the cursor position", ->
        editor.trigger 'editor:go-to-line'
        expect(goToLine.hasParent()).toBeTruthy()
        goToLine.miniEditor.trigger 'core:confirm'
        expect(goToLine.hasParent()).toBeFalsy()
        expect(editor.getCursorBufferPosition()).toEqual [1, 0]

  xdescribe "when core:cancel is triggered", ->
    it "closes the view and does not update the cursor position", ->
      editor.trigger 'editor:go-to-line'
      expect(goToLine.hasParent()).toBeTruthy()
      goToLine.miniEditor.trigger 'core:cancel'
      expect(goToLine.hasParent()).toBeFalsy()
      expect(editor.getCursorBufferPosition()).toEqual [1, 0]
