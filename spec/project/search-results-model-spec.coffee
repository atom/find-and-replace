shell = require 'shell'
path = require 'path'

{fs, $, RootView} = require 'atom'

SearchResultsModel = require '../../lib/project/search-results-model.coffee'

# Default to 30 second promises
waitsForPromise = (fn) -> window.waitsForPromise timeout: 30000, fn

fdescribe 'SearchResultsModel', ->
  [editSession, searchPromise, resultsModel, searchPromise] = []

  beforeEach ->
    window.rootView = new RootView()
    project.setPath(path.join(__dirname, '..', 'fixtures'))
    rootView.open('sample.js')
    rootView.attachToDom()

    editor = rootView.getActiveView()
    editSession = editor.activeEditSession

    resultsModel = new SearchResultsModel()

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

        # updates when we change the buffer
        editSession.setText('there are some items in here')
        editSession.buffer.trigger('contents-modified')

        expect(resultAddedSpy.callCount).toBe 2

        result = resultsModel.getResult(editSession.getPath())
        expect(result.length).toBe 1

        expect(result[0].lineText).toBe 'there are some items in here'

        # updates when there are no matches
        editSession.setText('no matches in here')
        editSession.buffer.trigger('contents-modified')

        expect(resultAddedSpy.callCount).toBe 2
        expect(resultRemovedSpy.callCount).toBe 1

        result = resultsModel.getResult(editSession.getPath())
        expect(result).not.toBeDefined()

        # after clear, contents modified is not called
        resultsModel.clear()
        spyOn(editSession, 'scan').andCallThrough()

        editSession.setText('no matches in here')
        editSession.buffer.trigger('contents-modified')

        expect(editSession.scan).not.toHaveBeenCalled()
