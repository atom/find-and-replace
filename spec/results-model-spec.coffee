path = require 'path'

ResultsModel = require '../lib/project/results-model'
FindOptions = require '../lib/find-options'

# Default to 30 second promises
waitsForPromise = (fn) -> window.waitsForPromise timeout: 30000, fn

describe 'ResultsModel', ->
  [editor, searchPromise, resultsModel, searchPromise] = []

  beforeEach ->
    atom.config.set('core.excludeVcsIgnoredPaths', false)
    atom.project.setPaths([path.join(__dirname, 'fixtures')])

    waitsForPromise ->
      atom.workspace.open('sample.js')

    runs ->
      editor = atom.workspace.getActiveTextEditor()
      findOptions = new FindOptions
      resultsModel = new ResultsModel(findOptions)

  describe "searching for a pattern", ->
    beforeEach ->

    it "populates the model with all the results, and updates in response to changes in the buffer", ->
      resultAddedSpy = jasmine.createSpy()
      resultRemovedSpy = jasmine.createSpy()

      runs ->
        resultsModel.onDidAddResult resultAddedSpy
        resultsModel.onDidRemoveResult resultRemovedSpy
        searchPromise = resultsModel.search('items', '*.js', '')

      waitsForPromise ->
        searchPromise

      runs ->
        expect(resultAddedSpy).toHaveBeenCalled()
        expect(resultAddedSpy.callCount).toBe 1

        result = resultsModel.getResult(editor.getPath())
        expect(result.matches.length).toBe 6
        expect(resultsModel.getPathCount()).toBe 1
        expect(resultsModel.getMatchCount()).toBe 6
        expect(resultsModel.getPaths()).toEqual [editor.getPath()]

        # updates when we change the buffer
        editor.setText('there are some items in here')
        advanceClock(editor.buffer.stoppedChangingDelay)

        expect(resultAddedSpy.callCount).toBe 2

        result = resultsModel.getResult(editor.getPath())
        expect(result.matches.length).toBe 1
        expect(resultsModel.getPathCount()).toBe 1
        expect(resultsModel.getMatchCount()).toBe 1
        expect(resultsModel.getPaths()).toEqual [editor.getPath()]

        expect(result.matches[0].lineText).toBe 'there are some items in here'

        # updates when there are no matches
        editor.setText('no matches in here')
        advanceClock(editor.buffer.stoppedChangingDelay)

        expect(resultAddedSpy.callCount).toBe 2
        expect(resultRemovedSpy.callCount).toBe 1

        result = resultsModel.getResult(editor.getPath())
        expect(result).not.toBeDefined()

        expect(resultsModel.getPathCount()).toBe 0
        expect(resultsModel.getMatchCount()).toBe 0

        # after clear, contents modified is not called
        resultsModel.clear()
        spyOn(editor, 'scan').andCallThrough()

        editor.setText('no matches in here')
        advanceClock(editor.buffer.stoppedChangingDelay)

        expect(editor.scan).not.toHaveBeenCalled()

        expect(resultsModel.getPathCount()).toBe 0
        expect(resultsModel.getMatchCount()).toBe 0

    it "ignores changes in untitled buffers", ->
      resultAddedSpy = jasmine.createSpy()
      resultRemovedSpy = jasmine.createSpy()

      waitsForPromise ->
        atom.workspace.open()

      runs ->
        resultsModel.onDidAddResult resultAddedSpy
        resultsModel.onDidRemoveResult resultRemovedSpy
        searchPromise = resultsModel.search('items', '*.js', '')

      waitsForPromise ->
        searchPromise

      runs ->
        editor = atom.workspace.getActiveTextEditor()
        editor.setText('items\nitems')
        spyOn(editor, 'scan').andCallThrough()
        advanceClock(editor.buffer.stoppedChangingDelay)
        expect(editor.scan).not.toHaveBeenCalled()

    it "contains valid match objects after destroying a buffer (regression)", ->
      waitsForPromise ->
        resultsModel.search('items', '*.js', '')

      runs ->
        advanceClock(editor.buffer.stoppedChangingDelay)
        editor.getBuffer().destroy()
        result = resultsModel.getResult(editor.getPath())
        expect(result.matches[0].lineText).toBe("  var sort = function(items) {")

  describe "cancelling a search", ->
    cancelledSpy = null
    beforeEach ->
      cancelledSpy = jasmine.createSpy()
      resultsModel.onDidCancelSearching cancelledSpy

    it "populates the model with all the results, and updates in response to changes in the buffer", ->
      runs ->
        searchPromise = resultsModel.search('items', '*.js', '')

        expect(resultsModel.inProgressSearchPromise).toBeTruthy()
        resultsModel.clear()
        expect(resultsModel.inProgressSearchPromise).toBeFalsy()

      waitsForPromise ->
        searchPromise

      runs ->
        expect(cancelledSpy).toHaveBeenCalled()

    it "populates the model with all the results, and updates in response to changes in the buffer", ->
      runs ->
        searchPromise = resultsModel.search('items', '*.js', '')
        searchPromise = resultsModel.search('sort', '*.js', '')

      waitsForPromise ->
        searchPromise

      runs ->
        expect(cancelledSpy).toHaveBeenCalled()
        expect(resultsModel.getPathCount()).toBe 1
        expect(resultsModel.getMatchCount()).toBe 5
