RootView = require 'root-view'
BufferFindAndReplaceView = require 'buffer-find-and-replace/lib/buffer-find-and-replace-view'
BufferFindAndReplace = require 'buffer-find-and-replace/lib/buffer-find-and-replace'

describe 'BufferFindAndReplaceView', ->
  [subject, editor] = []
  beforeEach ->
    window.rootView = new RootView

  describe "with no editor", ->
    beforeEach ->
      subject = BufferFindAndReplace.activate()

    describe "when find-and-replace:display-find is triggered", ->
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

      subject = BufferFindAndReplace.activate()

    describe "when find-and-replace:display-find is triggered", ->
      it "attaches to the root view", ->
        editor.trigger 'find-and-replace:display-find'
        expect(subject.hasParent()).toBeTruthy()

    describe "when core:cancel is triggered", ->
      beforeEach ->
        editor.trigger 'find-and-replace:display-find'

      it "detaches from the root view when cancel on findEditor", ->
        subject.findEditor.trigger 'core:cancel'
        expect(subject.hasParent()).toBeFalsy()

      it "detaches from the root view when cancel on replaceEditor", ->
        subject.replaceEditor.trigger 'core:cancel'
        expect(subject.hasParent()).toBeFalsy()

    describe "option buttons", ->
      beforeEach ->
        editor.trigger 'find-and-replace:display-find'
        editor.attachToDom()

      it "clicking an option button toggles its enabled class", ->
        subject.toggleRegexOption()
        expect(subject.searchModel.getOption('regex')).toEqual true
        expect(subject.regexOptionButton).toHaveClass('enabled')

      it "clicking inSelection option button toggles its enabled class", ->
        subject.toggleInSelectionOption()
        expect(subject.searchModel.getOption('inSelection')).toEqual true
        expect(subject.inSelectionOptionButton).toHaveClass('enabled')

    describe "running a search", ->
      beforeEach ->
        editor.trigger 'find-and-replace:display-find'

        rootView.attachToDom()
        subject.findEditor.textInput 'items'
        subject.findEditor.trigger 'core:confirm'

      it "shows correct message in results view", ->
        expect(subject.resultCounter.text()).toEqual('1 of 6')
        expect(editor.getSelectedBufferRange()).toEqual [[1, 22], [1, 27]]

      it "editor deletion is handled properly", ->
        editor.getPane().remove()
        expect(subject.resultCounter.text()).toEqual('')

        # should not die on new search!
        subject.findEditor.textInput 'items'

      # FIXME: when the cursor moves, I want this to pass. cursor:moved never
      # gets called in tests
      xit "removes the '# of' when user moves cursor", ->
        editor.setCursorBufferPosition([10,1])
        editor.setCursorBufferPosition([12,1])

        waits 1000
        runs ->
          expect(subject.resultCounter.text()).toEqual('6 found')

    describe "running a replace", ->
      beforeEach ->
        editor.trigger 'find-and-replace:display-replace'
        editor.attachToDom()
        subject.findEditor.textInput 'items'
        subject.replaceEditor.textInput 'cats'

      it "replaces one and finds next", ->
        subject.replaceEditor.trigger 'core:confirm'
        expect(subject.resultCounter.text()).toEqual('1 of 5')
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]
        expect(editor.activeEditSession.getTextInBufferRange([[1, 22], [1, 27]])).toEqual 'cats)'

      it "replaces all", ->
        subject.replaceAll()
        expect(subject.resultCounter.text()).toEqual('0 found')
        expect(editor.activeEditSession.getTextInBufferRange([[1, 22], [1, 27]])).toEqual 'cats)'

    describe "removing the results model", ->
      beforeEach ->

      it "replaces one and finds next", ->
        editor.searchResults.destroy()
        expect(subject.searchResultsViews.length).toEqual 0

        editor.trigger 'find-and-replace:display-replace'

    describe "history", ->
      beforeEach ->
        subject.attach()

        subject.searchModel.setPattern('one')
        subject.searchModel.setPattern('two')
        subject.searchModel.setPattern('three')

        expect(subject.searchModel.history.length).toEqual 3
        expect(subject.searchModel.historyIndex).toEqual 2

      it "can navigate back to the first thing in the history stack then back to the last thing in the history", ->
        subject.findEditor.trigger 'find-and-replace:search-previous-in-history'
        expect(subject.findEditor.getText()).toEqual 'two'

        subject.findEditor.trigger 'find-and-replace:search-previous-in-history'
        expect(subject.findEditor.getText()).toEqual 'one'

        subject.findEditor.trigger 'find-and-replace:search-previous-in-history'
        expect(subject.findEditor.getText()).toEqual 'one'

        subject.findEditor.trigger 'find-and-replace:search-next-in-history'
        expect(subject.findEditor.getText()).toEqual 'two'

        subject.findEditor.trigger 'find-and-replace:search-next-in-history'
        expect(subject.findEditor.getText()).toEqual 'three'

        subject.findEditor.trigger 'find-and-replace:search-next-in-history'
        expect(subject.findEditor.getText()).toEqual ''

        subject.findEditor.trigger 'find-and-replace:search-next-in-history'
        expect(subject.findEditor.getText()).toEqual ''

      it "keeps text I havent searched for yet so i can come back to it", ->
        text = 'something I want to search for but havent yet'
        subject.unsearchedPattern = text

        subject.findEditor.trigger 'find-and-replace:search-previous-in-history'
        expect(subject.findEditor.getText()).toEqual 'two'

        subject.findEditor.trigger 'find-and-replace:search-next-in-history'
        expect(subject.findEditor.getText()).toEqual 'three'

        subject.findEditor.trigger 'find-and-replace:search-next-in-history'
        expect(subject.findEditor.getText()).toEqual text

        subject.findEditor.trigger 'find-and-replace:search-next-in-history'
        expect(subject.findEditor.getText()).toEqual text

        subject.findEditor.trigger 'find-and-replace:search-previous-in-history'
        expect(subject.findEditor.getText()).toEqual 'three'
        subject.findEditor.trigger 'find-and-replace:search-previous-in-history'
        expect(subject.findEditor.getText()).toEqual 'two'
        subject.findEditor.trigger 'find-and-replace:search-previous-in-history'
        expect(subject.findEditor.getText()).toEqual 'one'
        subject.findEditor.trigger 'find-and-replace:search-previous-in-history'
        expect(subject.findEditor.getText()).toEqual 'one'

        subject.findEditor.trigger 'find-and-replace:search-next-in-history'
        expect(subject.findEditor.getText()).toEqual 'two'
        subject.findEditor.trigger 'find-and-replace:search-next-in-history'
        expect(subject.findEditor.getText()).toEqual 'three'
        subject.findEditor.trigger 'find-and-replace:search-next-in-history'
        expect(subject.findEditor.getText()).toEqual text

      it "adds the previous search into the history when search is run", ->
        subject.findEditor.trigger 'find-and-replace:search-previous-in-history'
        expect(subject.findEditor.getText()).toEqual 'two'

        subject.findEditor.trigger 'find-and-replace:search-previous-in-history'
        expect(subject.findEditor.getText()).toEqual 'one'

        subject.findEditor.trigger 'core:confirm'

        expect(subject.searchModel.history.length).toEqual 4
        expect(_.last(subject.searchModel.history)).toEqual 'one'
