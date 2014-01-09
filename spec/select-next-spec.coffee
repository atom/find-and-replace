path = require 'path'
{WorkspaceView} = require 'atom'
SelectNext = require '../lib/select-next'

describe "SelectNext", ->
  [editorView] = []

  beforeEach ->
    atom.workspaceView = new WorkspaceView()
    atom.project.setPath(path.join(__dirname, 'fixtures'))
    atom.workspaceView.openSync('sample.js')
    atom.workspaceView.attachToDom()
    editorView = atom.workspaceView.getActiveView()
    atom.packages.activatePackage("find-and-replace", immediate: true)

  describe "find-and-replace:select-next", ->
    describe "when nothing is selected", ->
      it "selects the word under the cursor", ->
        editorView.setCursorBufferPosition([1, 3])
        editorView.trigger 'find-and-replace:select-next'
        expect(editorView.getSelectedBufferRanges()).toEqual [[[1, 2], [1, 5]]]

    describe "when there is selected text", ->
      it "selects the next occurrence of the selected text", ->
        editorView.setSelectedBufferRange([[0, 0], [0, 3]])

        editorView.trigger 'find-and-replace:select-next'
        expect(editorView.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[1, 2], [1, 5]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editorView.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[1, 2], [1, 5]]
          [[3, 4], [3, 7]]
        ]

        editorView.trigger 'find-and-replace:select-next'
        expect(editorView.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[1, 2], [1, 5]]
          [[3, 4], [3, 7]]
        ]
