RootView = require 'root-view'
FindAndReplace = require 'find-and-replace/lib/find'

describe 'FindAndReplace', ->
  [subject, editor] = []
  beforeEach ->
    window.rootView = new RootView

  describe "Serialization", ->
    describe "for buffer find and replace", ->
      beforeEach ->

      it "loads with no state and serializes the search model", ->
        FindAndReplace.activate()
        FindAndReplace.findModel.setPattern('one')
        FindAndReplace.findModel.setOption('regex', true)

        state = FindAndReplace.serialize()
        expect(state.buffer).toEqual
          history: ['one']
          options:
            regex: true
            inWord: false
            inSelection: false
            caseSensitive: false

      it "loads with state and populates the findModel", ->
        FindAndReplace.activate
          buffer:
            history: ['one']
            options:
              regex: true
              inWord: false
              inSelection: false
              caseSensitive: false

        expect(FindAndReplace.findModel.history).toEqual ['one']
        expect(FindAndReplace.findModel.options.regex).toEqual true

    describe "Project find and replace", ->
      beforeEach ->

      it "loads with no state and serializes the search model", ->
        FindAndReplace.activate()
        FindAndReplace.projectFindAndReplaceSearchModel.setPattern('two')
        FindAndReplace.projectFindAndReplaceSearchModel.setOption('regex', true)

        state = FindAndReplace.serialize()
        expect(state.project).toEqual
          history: ['two']
          options:
            regex: true
            inWord: false
            inSelection: false
            caseSensitive: false

      it "loads with state and populates the findModel", ->
        FindAndReplace.activate
          project:
            history: ['two']
            options:
              regex: true
              inWord: false
              inSelection: false
              caseSensitive: false

        expect(FindAndReplace.projectFindAndReplaceSearchModel.history).toEqual ['two']
        expect(FindAndReplace.projectFindAndReplaceSearchModel.options.regex).toEqual true
