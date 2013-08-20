RootView = require 'root-view'
FindAndReplace = require 'find-and-replace/lib/find-and-replace'

describe 'FindAndReplace', ->
  [subject, editor] = []
  beforeEach ->
    window.rootView = new RootView

  describe "Serialization", ->
    describe "for buffer find and replace", ->
      beforeEach ->

      it "loads with no state and serializes the search model", ->
        FindAndReplace.activate()
        FindAndReplace.bufferFindAndReplaceSearchModel.setPattern('one')
        FindAndReplace.bufferFindAndReplaceSearchModel.setOption('regex', true)

        state = FindAndReplace.serialize()
        expect(state.buffer).toEqual 
          history: ['one']
          options:
            regex: true
            inWord: false
            inSelection: false
            caseSensitive: false

      it "loads with state and populates the searchModel", ->
        FindAndReplace.activate
          buffer: 
            history: ['one']
            options:
              regex: true
              inWord: false
              inSelection: false
              caseSensitive: false

        expect(FindAndReplace.bufferFindAndReplaceSearchModel.history).toEqual ['one']
        expect(FindAndReplace.bufferFindAndReplaceSearchModel.options.regex).toEqual true
