path = require 'path'
{WorkspaceView} = require 'atom'
SelectNext = require '../lib/select-next'

describe "SelectNext", ->
  [editorView, editor, promise] = []

  beforeEach ->
    atom.workspaceView = new WorkspaceView()
    atom.project.setPath(path.join(__dirname, 'fixtures'))

    waitsForPromise ->
      atom.workspace.open('sample.js')

    runs ->
      atom.workspaceView.attachToDom()
      editorView = atom.workspaceView.getActiveView()
      editor = editorView.getEditor()
      promise = atom.packages.activatePackage("find-and-replace")
      editorView.trigger 'find-and-replace:show'

    waitsForPromise ->
      promise

  describe "find-and-replace:select-next", ->
    describe "when nothing is selected", ->
      it "selects the word under the cursor", ->
        editor.setCursorBufferPosition([1, 3])
        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [[[1, 2], [1, 5]]]

    describe "when a word is selected", ->
      it "selects the next occurrence of the selected word skipping any non-word matches", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[0, 0], [0, 3]])

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[3, 8], [3, 11]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[3, 8], [3, 11]]
          [[5, 6], [5, 9]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[3, 8], [3, 11]]
          [[5, 6], [5, 9]]
        ]

        editor.setText "Testing reallyTesting"
        editor.setCursorBufferPosition([0, 0])

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 7]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 7]]
        ]

    describe "when part of a word is selected", ->
      it "selects the next occurrence of the selected text", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[1, 2], [1, 5]])

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[1, 2], [1, 5]]
          [[2, 0], [2, 3]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[1, 2], [1, 5]]
          [[2, 0], [2, 3]]
          [[3, 8], [3, 11]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[1, 2], [1, 5]]
          [[2, 0], [2, 3]]
          [[3, 8], [3, 11]]
          [[4, 0], [4, 3]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[1, 2], [1, 5]]
          [[2, 0], [2, 3]]
          [[3, 8], [3, 11]]
          [[4, 0], [4, 3]]
          [[5, 6], [5, 9]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[1, 2], [1, 5]]
          [[2, 0], [2, 3]]
          [[3, 8], [3, 11]]
          [[4, 0], [4, 3]]
          [[5, 6], [5, 9]]
        ]

    describe "when a non-word is selected", ->
      it "selects the next occurrence of the selected text", ->
        editor.setText """
          <!
          <a
        """
        editor.setSelectedBufferRange([[0, 0], [0, 1]])
        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 1]]
          [[1, 0], [1, 1]]
        ]

    describe "when the word is at a line boundary", ->
      it "does not select the newlines", ->
        editor.setText """
          a

          a
        """

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 1]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 1]]
          [[2, 0], [2, 1]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 1]]
          [[2, 0], [2, 1]]
        ]

  describe "find-and-replace:select-all", ->
    describe "when there is no selection", ->
      it "find and selects all occurrences of the word under the cursor", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editorView.trigger 'find-and-replace:select-all'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[3, 8], [3, 11]]
          [[5, 6], [5, 9]]
        ]

        editorView.trigger 'find-and-replace:select-all'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[3, 8], [3, 11]]
          [[5, 6], [5, 9]]
        ]

    describe "when a word is selected", ->
      it "find and selects all occurrences", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[3, 8], [3, 11]])

        editorView.trigger 'find-and-replace:select-all'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[3, 8], [3, 11]]
          [[5, 6], [5, 9]]
        ]

        editorView.trigger 'find-and-replace:select-all'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[3, 8], [3, 11]]
          [[5, 6], [5, 9]]
        ]

    describe "when a non-word is selected", ->
      it "selects the next occurrence of the selected text", ->
        editor.setText """
          <!
          <a
        """
        editor.setSelectedBufferRange([[0, 0], [0, 1]])
        editorView.trigger 'find-and-replace:select-all'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 1]]
          [[1, 0], [1, 1]]
        ]
