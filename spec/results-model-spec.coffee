path = require 'path'

{fs, $, RootView} = require 'atom'

ResultsModel = require '../lib/project/results-model.coffee'

# Default to 30 second promises
waitsForPromise = (fn) -> window.waitsForPromise timeout: 30000, fn

describe 'ResultsModel', ->
  [editSession, searchPromise, resultsModel, searchPromise] = []

  beforeEach ->
    atom.rootView = new RootView()
    atom.project.setPath(path.join(__dirname, 'fixtures'))
    atom.rootView.openSync('sample.js')
    atom.rootView.attachToDom()

    editor = atom.rootView.getActiveView()
    editSession = editor.activeEditSession

    resultsModel = new ResultsModel()

  describe "searching for a pattern", ->
    beforeEach ->

    it "populates the model with all the results, and updates in response to changes in the buffer", ->
      resultAddedSpy = jasmine.createSpy()
      resultRemovedSpy = jasmine.createSpy()

      runs ->
        resultsModel.on 'result-added', resultAddedSpy
        resultsModel.on 'result-removed', resultRemovedSpy
        searchPromise = resultsModel.search('items', ['*.js'])

      waitsForPromise ->
        searchPromise

      runs ->
        expect(resultAddedSpy).toHaveBeenCalled()
        expect(resultAddedSpy.callCount).toBe 1

        result = resultsModel.getResult(editSession.getPath())
        expect(result.length).toBe 6
        expect(resultsModel.getPathCount()).toBe 1
        expect(resultsModel.getMatchCount()).toBe 6
        expect(resultsModel.getPaths()).toEqual [editSession.getPath()]

        # updates when we change the buffer
        editSession.setText('there are some items in here')
        editSession.buffer.emit('contents-modified')

        expect(resultAddedSpy.callCount).toBe 2

        result = resultsModel.getResult(editSession.getPath())
        expect(result.length).toBe 1
        expect(resultsModel.getPathCount()).toBe 1
        expect(resultsModel.getMatchCount()).toBe 1
        expect(resultsModel.getPaths()).toEqual [editSession.getPath()]

        expect(result[0].lineText).toBe 'there are some items in here'

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
