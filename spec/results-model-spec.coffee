path = require 'path'

{$, WorkspaceView} = require 'atom'

ResultsModel = require '../lib/project/results-model'

# Default to 30 second promises
waitsForPromise = (fn) -> window.waitsForPromise timeout: 30000, fn

describe 'ResultsModel', ->
  [editSession, searchPromise, resultsModel, searchPromise] = []

  beforeEach ->
    atom.workspaceView = new WorkspaceView()
    atom.project.setPath(path.join(__dirname, 'fixtures'))
    atom.workspaceView.openSync('sample.js')
    atom.workspaceView.attachToDom()

    editor = atom.workspaceView.getActiveView()
    editSession = editor.editor

    resultsModel = new ResultsModel()

  describe "searching for a pattern", ->
    beforeEach ->

    it "populates the model with all the results, and updates in response to changes in the buffer", ->
      resultAddedSpy = jasmine.createSpy()
      resultRemovedSpy = jasmine.createSpy()

      runs ->
        resultsModel.on 'result-added', resultAddedSpy
        resultsModel.on 'result-removed', resultRemovedSpy
        searchPromise = resultsModel.search('items', ['*.js'], '')

      waitsForPromise ->
        searchPromise

      runs ->
        expect(resultAddedSpy).toHaveBeenCalled()
        expect(resultAddedSpy.callCount).toBe 1

        result = resultsModel.getResult(editSession.getPath())
        expect(result.matches.length).toBe 6
        expect(resultsModel.getPathCount()).toBe 1
        expect(resultsModel.getMatchCount()).toBe 6
        expect(resultsModel.getPaths()).toEqual [editSession.getPath()]

        # updates when we change the buffer
        editSession.setText('there are some items in here')
        editSession.buffer.emit('contents-modified')

        expect(resultAddedSpy.callCount).toBe 2

        result = resultsModel.getResult(editSession.getPath())
        expect(result.matches.length).toBe 1
        expect(resultsModel.getPathCount()).toBe 1
        expect(resultsModel.getMatchCount()).toBe 1
        expect(resultsModel.getPaths()).toEqual [editSession.getPath()]

        expect(result.matches[0].lineText).toBe 'there are some items in here'

        # updates when there are no matches
        editSession.setText('no matches in here')
        editSession.buffer.emit('contents-modified')

        expect(resultAddedSpy.callCount).toBe 2
        expect(resultRemovedSpy.callCount).toBe 1

        result = resultsModel.getResult(editSession.getPath())
        expect(result).not.toBeDefined()

        expect(resultsModel.getPathCount()).toBe 0
        expect(resultsModel.getMatchCount()).toBe 0

        # after clear, contents modified is not called
        resultsModel.clear()
        spyOn(editSession, 'scan').andCallThrough()

        editSession.setText('no matches in here')
        editSession.buffer.emit('contents-modified')

        expect(editSession.scan).not.toHaveBeenCalled()

        expect(resultsModel.getPathCount()).toBe 0
        expect(resultsModel.getMatchCount()).toBe 0

    it "ignores changes in untitled buffers", ->
      resultAddedSpy = jasmine.createSpy()
      resultRemovedSpy = jasmine.createSpy()

      waitsForPromise ->
        atom.workspaceView.open()

      runs ->
        resultsModel.on 'result-added', resultAddedSpy
        resultsModel.on 'result-removed', resultRemovedSpy
        searchPromise = resultsModel.search('items', ['*.js'], '')

      waitsForPromise ->
        searchPromise

      runs ->
        editSession = atom.workspaceView.getActiveView().editor
        editSession.setText('items\nitems')
        spyOn(editSession, 'scan').andCallThrough()
        editSession.buffer.emit('contents-modified')
        expect(editSession.scan).not.toHaveBeenCalled()

  describe "cancelling a search", ->
    cancelledSpy = null
    beforeEach ->
      cancelledSpy = jasmine.createSpy()
      resultsModel.on 'cancelled-searching', cancelledSpy

    it "populates the model with all the results, and updates in response to changes in the buffer", ->
      runs ->
        searchPromise = resultsModel.search('items', ['*.js'], '')

        expect(resultsModel.inProgressSearchPromise).toBeTruthy()
        resultsModel.clear()
        expect(resultsModel.inProgressSearchPromise).toBeFalsy()

      waitsForPromise ->
        searchPromise

      runs ->
        expect(cancelledSpy).toHaveBeenCalled()

    it "populates the model with all the results, and updates in response to changes in the buffer", ->
      runs ->
        searchPromise = resultsModel.search('items', ['*.js'], '')
        searchPromise = resultsModel.search('sort', ['*.js'], '')

      waitsForPromise ->
        searchPromise

      runs ->
        expect(cancelledSpy).toHaveBeenCalled()
        expect(resultsModel.getPathCount()).toBe 1
        expect(resultsModel.getMatchCount()).toBe 5
