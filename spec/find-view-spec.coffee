_ = require 'underscore-plus'
{$, EditorView, WorkspaceView} = require 'atom'

path = require 'path'

describe 'FindView', ->
  [editorView, editor, findView, activationPromise] = []

  beforeEach ->
    spyOn(atom, 'beep')
    atom.workspaceView = new WorkspaceView()
    atom.project.setPath(path.join(__dirname, 'fixtures'))

    waitsForPromise ->
      atom.workspace.open('sample.js')

    runs ->
      atom.workspaceView.attachToDom()
      editorView = atom.workspaceView.getActiveView()
      editor = editorView.getEditor()

      activationPromise = atom.packages.activatePackage("find-and-replace").then ({mainModule}) ->
        mainModule.createFindView()
        {findView} = mainModule

  describe "when find-and-replace:show is triggered", ->
    it "attaches FindView to the root view", ->
      editorView.trigger 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.find-and-replace')).toExist()

    it "populates the findEditor with selection when there is a selection", ->
      editor.setSelectedBufferRange([[2, 8], [2, 13]])
      editorView.trigger 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.find-and-replace')).toExist()
        expect(findView.findEditor.getText()).toBe('items')

        findView.findEditor.setText('')

        editor.setSelectedBufferRange([[2, 14], [2, 20]])
        editorView.trigger 'find-and-replace:show'
        expect(atom.workspaceView.find('.find-and-replace')).toExist()
        expect(findView.findEditor.getText()).toBe('length')

    it "does not change the findEditor text when there is no selection", ->
      editor.setSelectedBufferRange([[2, 8], [2, 8]])
      editorView.trigger 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        findView.findEditor.setText 'kitten'
        editorView.trigger 'find-and-replace:show'
        expect(findView.findEditor.getText()).toBe('kitten')

    it "does not change the findEditor text when there is a multiline selection", ->
      editor.setSelectedBufferRange([[2, 8], [3, 12]])
      editorView.trigger 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.find-and-replace')).toExist()
        expect(findView.findEditor.getText()).toBe('')

  describe "when find-and-replace:toggle is triggered", ->
    it "toggles the visibility of the FindView", ->
      atom.workspaceView.trigger 'find-and-replace:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.find-and-replace')).toExist()
        atom.workspaceView.trigger 'find-and-replace:toggle'
        expect(atom.workspaceView.find('.find-and-replace')).not.toExist()

  describe "when FindView's replace editor is visible", ->
    it "keeps the replace editor visible when find-and-replace:show is triggered", ->
      editorView.trigger 'find-and-replace:show-replace'

      waitsForPromise ->
        activationPromise

      runs ->
        editorView.trigger 'find-and-replace:show'
        expect(findView.replaceEditor).toBeVisible()

  describe "core:cancel", ->
    beforeEach ->
      editorView.trigger 'find-and-replace:show'
      waitsForPromise ->
        activationPromise

      runs ->
        findView.findEditor.setText 'items'
        findView.findEditor.trigger 'core:confirm'
        findView.focus()

    describe "when core:cancel is triggered on the find view", ->
      it "detaches from the workspace view", ->
        $(document.activeElement).trigger 'core:cancel'
        expect(atom.workspaceView.find('.find-and-replace')).not.toExist()

      it "removes highlighted matches", ->
        findResultsView = editorView.find('.search-results')

        $(document.activeElement).trigger 'core:cancel'
        expect(findResultsView.parent()).not.toExist()

    describe "when core:cancel is triggered on an empty pane", ->
      it "detaches from the workspace view", ->
        atom.workspaceView.getActivePaneView().focus()
        $(atom.workspaceView.getActivePaneView()).trigger 'core:cancel'
        expect(atom.workspaceView.find('.find-and-replace')).not.toExist()

    describe "when core:cancel is triggered on an editor", ->
      it "detaches from the workspace view", ->
        waitsForPromise ->
          atom.workspace.open()

        runs ->
          $(atom.workspaceView.getActiveView().hiddenInput).trigger 'core:cancel'
          expect(atom.workspaceView.find('.find-and-replace')).not.toExist()

    describe "when core:cancel is triggered on a mini editor", ->
      it "leaves the find view attached", ->
        editorView = new EditorView(mini: true)
        atom.workspaceView.appendToTop(editorView)
        editorView.focus()
        $(editorView.hiddenInput).trigger 'core:cancel'
        expect(atom.workspaceView.find('.find-and-replace')).toExist()

  describe "serialization", ->
    it "serializes find and replace history", ->
      editorView.trigger 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        findView.findEditor.setText("items")
        findView.replaceEditor.setText("cat")
        findView.replaceAll()

        findView.findEditor.setText("sort")
        findView.replaceEditor.setText("dog")
        findView.replaceNext()

        findView.findEditor.setText("shift")
        findView.replaceEditor.setText("ok")
        findView.findNext(false)

        atom.packages.deactivatePackage("find-and-replace")

        activationPromise = atom.packages.activatePackage("find-and-replace").then ({mainModule}) ->
          mainModule.createFindView()
          {findView} = mainModule

        editorView.trigger 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        findView.findEditor.trigger('core:move-up')
        expect(findView.findEditor.getText()).toBe 'shift'
        findView.findEditor.trigger('core:move-up')
        expect(findView.findEditor.getText()).toBe 'sort'
        findView.findEditor.trigger('core:move-up')
        expect(findView.findEditor.getText()).toBe 'items'

        findView.replaceEditor.trigger('core:move-up')
        expect(findView.replaceEditor.getText()).toBe 'dog'
        findView.replaceEditor.trigger('core:move-up')
        expect(findView.replaceEditor.getText()).toBe 'cat'

    it "serializes find options ", ->
      editorView.trigger 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(findView.caseOptionButton).not.toHaveClass 'selected'
        expect(findView.regexOptionButton).not.toHaveClass 'selected'
        expect(findView.selectionOptionButton).not.toHaveClass 'selected'

        findView.caseOptionButton.click()
        findView.regexOptionButton.click()
        findView.selectionOptionButton.click()

        expect(findView.caseOptionButton).toHaveClass 'selected'
        expect(findView.regexOptionButton).toHaveClass 'selected'
        expect(findView.selectionOptionButton).toHaveClass 'selected'

        atom.packages.deactivatePackage("find-and-replace")

        activationPromise = atom.packages.activatePackage("find-and-replace").then ({mainModule}) ->
          mainModule.createFindView()
          {findView} = mainModule

        editorView.trigger 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(findView.caseOptionButton).toHaveClass 'selected'
        expect(findView.regexOptionButton).toHaveClass 'selected'
        expect(findView.selectionOptionButton).toHaveClass 'selected'

  describe "finding", ->
    beforeEach ->
      atom.config.set('find-and-replace.focusEditorAfterSearch', false)
      editor.setCursorBufferPosition([2,0])
      editorView.trigger 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        findView.findEditor.setText 'items'
        findView.findEditor.trigger 'core:confirm'

    describe "when the find string contains an escaped char", ->
      beforeEach ->
        editor.setText("\t\n\\t\\\\")
        editor.setCursorBufferPosition([0,0])

      describe "when regex seach is enabled", ->
        beforeEach ->
          findView.findEditor.trigger 'find-and-replace:toggle-regex-option'

        it "finds a backslash", ->
          findView.findEditor.setText('\\\\')
          findView.findEditor.trigger 'core:confirm'
          expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 1]]

        it "finds a newline", ->
          findView.findEditor.setText('\\n')
          findView.findEditor.trigger 'core:confirm'
          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [1, 0]]

        it "finds a tab character", ->
          findView.findEditor.setText('\\t')
          findView.findEditor.trigger 'core:confirm'
          expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 1]]

      describe "when regex seach is disabled", ->
        it "finds the literal backslash t", ->
          findView.findEditor.setText('\\t')
          findView.findEditor.trigger 'core:confirm'
          expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 2]]

        it "finds a backslash", ->
          findView.findEditor.setText('\\')
          findView.findEditor.trigger 'core:confirm'
          expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 1]]

        it "finds two backslashes", ->
          findView.findEditor.setText('\\\\')
          findView.findEditor.trigger 'core:confirm'
          expect(editor.getSelectedBufferRange()).toEqual [[1, 2], [1, 4]]

        it "doesn't find when escaped", ->
          findView.findEditor.setText('\\\\t')
          findView.findEditor.trigger 'core:confirm'
          expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 0]]

    describe "when focusEditorAfterSearch is set", ->
      beforeEach ->
        atom.config.set('find-and-replace.focusEditorAfterSearch', true)
        findView.findEditor.trigger 'core:confirm'

      it "selects the first match following the cursor and correctly focuses the editor", ->
        expect(findView.resultCounter.text()).toEqual('3 of 6')
        expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]
        expect(editorView).toHaveFocus()

    it "doesn't change the selection, beeps if there are no matches and keeps focus on the find view", ->
      editor.setCursorBufferPosition([2,0])
      findView.findEditor.setText 'notinthefilebro'
      findView.findEditor.focus()

      findView.findEditor.trigger 'core:confirm'
      expect(editor.getCursorBufferPosition()).toEqual [2,0]
      expect(atom.beep).toHaveBeenCalled()
      expect(findView).toHaveFocus()

      expect(findView.descriptionLabel.text()).toEqual "No results found for 'notinthefilebro'"

    describe "updating the descriptionLabel", ->
      it "properly updates the info message", ->
        findView.findEditor.setText 'item'
        findView.findEditor.trigger 'core:confirm'
        expect(findView.descriptionLabel.text()).toEqual "6 results found for 'item'"

        findView.findEditor.setText 'notinthefilenope'
        findView.findEditor.trigger 'core:confirm'
        expect(findView.descriptionLabel.text()).toEqual "No results found for 'notinthefilenope'"

        findView.findEditor.setText 'item'
        findView.findEditor.trigger 'core:confirm'
        expect(findView.descriptionLabel.text()).toEqual "6 results found for 'item'"

        findView.findEditor.setText ''
        findView.findEditor.trigger 'core:confirm'
        expect(findView.descriptionLabel.text()).toContain "Find in Current Buffer"

      describe "when there is a find-error", ->
        beforeEach ->
          editor.setCursorBufferPosition([2,0])
          findView.findEditor.trigger 'find-and-replace:toggle-regex-option'

        it "displays the error", ->
          findView.findEditor.setText 'i[t'
          findView.findEditor.trigger 'core:confirm'
          expect(findView.descriptionLabel).toHaveClass 'text-error'
          expect(findView.descriptionLabel.text()).toContain 'Invalid regular expression'

        it "will be reset when there is no longer an error", ->
          findView.findEditor.setText 'i[t'
          findView.findEditor.trigger 'core:confirm'
          expect(findView.descriptionLabel).toHaveClass 'text-error'

          findView.findEditor.setText ''
          findView.findEditor.trigger 'core:confirm'
          expect(findView.descriptionLabel).not.toHaveClass 'text-error'
          expect(findView.descriptionLabel.text()).toContain "Find in Current Buffer"

          findView.findEditor.setText 'item'
          findView.findEditor.trigger 'core:confirm'
          expect(findView.descriptionLabel).not.toHaveClass 'text-error'
          expect(findView.descriptionLabel.text()).toContain "6 results"

    it "selects the first match following the cursor", ->
      expect(findView.resultCounter.text()).toEqual('2 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      findView.findEditor.trigger 'core:confirm'
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]
      expect(findView.findEditor).toHaveFocus()

    it "selects the next match when the next match button is pressed", ->
      findView.nextButton.click()
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]

    it "selects the next match when the 'find-and-replace:find-next' event is triggered and correctly focuses the editor", ->
      expect(findView).toHaveFocus()
      editorView.trigger('find-and-replace:find-next')
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]
      expect(editorView).toHaveFocus()

    it "selects the previous match before the cursor when the 'find-and-replace:show-previous' event is triggered", ->
      expect(findView.resultCounter.text()).toEqual('2 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      findView.findEditor.trigger 'find-and-replace:show-previous'
      expect(findView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 22], [1, 27]]
      expect(findView.findEditor).toHaveFocus()

    it "will re-run search if 'find-and-replace:find-next' is triggered after changing the findEditor's text", ->
      findView.findEditor.setText 'sort'
      findView.findEditor.trigger 'find-and-replace:find-next'

      expect(findView.resultCounter.text()).toEqual('3 of 5')
      expect(editor.getSelectedBufferRange()).toEqual [[8, 11], [8, 15]]

    it "'find-and-replace:find-next' adds to the findEditor's history", ->
      findView.findEditor.setText 'sort'
      findView.findEditor.trigger 'find-and-replace:find-next'

      expect(findView.resultCounter.text()).toEqual('3 of 5')

      findView.findEditor.setText 'nope'
      findView.findEditor.trigger 'core:move-up'
      expect(findView.findEditor.getText()).toEqual 'sort'

    it "selects the previous match when the previous match button is pressed", ->
      findView.previousButton.click()
      expect(findView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 27], [1, 22]]

    it "selects the previous match when the 'find-and-replace:find-previous' event is triggered and correctly focuses the editor", ->
      expect(findView).toHaveFocus()
      editorView.trigger('find-and-replace:find-previous')
      expect(findView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 27], [1, 22]]
      expect(editorView).toHaveFocus()

    it "will re-run search if 'find-and-replace:find-previous' is triggered after changing the findEditor's text", ->
      findView.findEditor.setText 'sort'
      findView.findEditor.trigger 'find-and-replace:find-previous'

      expect(findView.resultCounter.text()).toEqual('2 of 5')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

    it "replaces results counter with number of results found when user moves the cursor", ->
      editor.moveCursorDown()
      expect(findView.resultCounter.text()).toBe '6 found'

    it "replaces results counter x of y text when user selects a marked range", ->
      editor.moveCursorDown()
      editor.setSelectedBufferRange([[2, 34], [2, 39]])
      expect(findView.resultCounter.text()).toEqual('3 of 6')

    it "places the selected text into the find editor when find-and-replace:set-find-pattern is triggered", ->
      editor.setSelectedBufferRange([[1,6],[1,10]])
      atom.workspaceView.trigger 'find-and-replace:use-selection-as-find-pattern'

      expect(findView.findEditor.getText()).toBe 'sort'
      expect(editor.getSelectedBufferRange()).toEqual [[1,6],[1,10]]

      atom.workspaceView.trigger 'find-and-replace:find-next'
      expect(editor.getSelectedBufferRange()).toEqual [[8,11],[8,15]]

    it "does not highlight the found text when the find view is hidden", ->
      findView.findEditor.trigger 'core:cancel'
      findView.findEditor.trigger 'find-and-replace:find-next'

      findResultsView = editorView.find('.search-results')
      expect(findResultsView.parent()).not.toExist()

    describe "when the active pane item changes", ->
      describe "when a new edit session is activated", ->
        it "reruns the search on the new edit session", ->
          waitsForPromise ->
            atom.workspace.open('sample.coffee')

          runs ->
            editor = atom.workspace.getActivePaneItem()
            expect(findView.resultCounter.text()).toEqual('7 found')
            expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 0]]

        it "initially highlights the found text in the new edit session", ->
          expect(editorView.find('.highlight.find-result')).toHaveLength 6

          waitsForPromise ->
            atom.workspace.open('sample.coffee')

          runs ->
            # old editor has no more results
            expect(editorView.find('.highlight.find-result')).toHaveLength 0

            # new one has 7 results
            expect(atom.workspaceView.getActiveView().find('.highlight.find-result')).toHaveLength 7

        it "highlights the found text in the new edit session when find next is triggered", ->
          waitsForPromise ->
            atom.workspace.open('sample.coffee')

          runs ->
            findView.findEditor.trigger 'find-and-replace:find-next'
            expect(atom.workspaceView.getActiveView().find('.highlight.find-result')).toHaveLength 7

      describe "when all active pane items are closed", ->
        it "updates the result count", ->
          editorView.trigger 'core:close'
          expect(findView.resultCounter.text()).toEqual('no results')

      describe "when the active pane item is not an edit session", ->
        [anotherOpener] = []

        beforeEach ->
          anotherOpener = (pathToOpen, options) -> $('another')
          atom.workspace.registerOpener(anotherOpener)

        afterEach ->
          atom.workspace.unregisterOpener(anotherOpener)

        it "updates the result view", ->
          waitsForPromise ->
            atom.workspace.open "another"

          runs ->
            expect(findView.resultCounter.text()).toEqual('no results')

        it "removes all highlights", ->
          findResultsView = editorView.find('.search-results')

          waitsForPromise ->
            atom.workspace.open "another"

          runs ->
            expect(findResultsView.children()).toHaveLength 0

      describe "when a new edit session is activated on a different pane", ->
        it "initially highlights all the sample.js results", ->
          expect(editorView.find('.find-result')).toHaveLength 6

        it "reruns the search on the new editSession", ->
          newEditor = null

          waitsForPromise ->
            atom.project.open('sample.coffee').then (o) -> newEditor = o

          runs ->
            newEditorView = editorView.getPane().splitRight(newEditor).activeView
            expect(findView.resultCounter.text()).toEqual('7 found')
            expect(newEditorView.getEditor().getSelectedBufferRange()).toEqual [[0, 0], [0, 0]]

            findView.findEditor.trigger 'find-and-replace:find-next'
            expect(findView.resultCounter.text()).toEqual('1 of 7')
            expect(newEditorView.getEditor().getSelectedBufferRange()).toEqual [[1, 9], [1, 14]]

        it "highlights the found text in the new edit session (and removes the highlights from the other)", ->
          [newEditor, newEditorView] = []

          waitsForPromise ->
            atom.project.open('sample.coffee').then (o) -> newEditor = o

          runs ->
            newEditorView = editorView.getPane().splitRight(newEditor)

          runs ->
            # old editor has no more results
            expect(editorView.find('.find-result')).toHaveLength 0

            # new one has 7 results
            expect(newEditorView.find('.find-result')).toHaveLength 7

        it "will still highlight results after the split pane has been destroyed", ->
          [newEditor, newEditorView] = []

          waitsForPromise ->
            atom.project.open('sample.coffee').then (o) -> newEditor = o

          runs ->
            newEditorView = editorView.getPane().splitRight(newEditor)
            expect(newEditorView.find('.find-result')).toHaveLength 7

            newEditorView.focus()
            newEditorView.trigger('core:close')
            editorView.focus()

          runs ->
            expect(editorView.find('.find-result')).toHaveLength 6

    describe "when the buffer contents change", ->
      it "re-runs the search", ->
        findResultsView = editorView.find('.search-results')
        editor.setSelectedBufferRange([[1, 26], [1, 27]])
        editor.insertText("")

        window.advanceClock(1000)
        expect(findView.resultCounter.text()).toEqual('5 found')

        editor.insertText("s")
        window.advanceClock(1000)
        expect(findView.resultCounter.text()).toEqual('6 found')

      it "does not beep if no matches were found", ->
        editor.setCursorBufferPosition([2,0])
        findView.findEditor.setText 'notinthefilebro'
        findView.findEditor.trigger 'core:confirm'
        atom.beep.reset()

        editor.insertText("blah blah")
        expect(atom.beep).not.toHaveBeenCalled()

    describe "when finding within a selection", ->
      beforeEach ->
        editor.setSelectedBufferRange [[2, 0], [4, 0]]

      it "toggles find within a selction via and event and only finds matches within the selection", ->
        findView.findEditor.setText 'items'
        findView.findEditor.trigger 'find-and-replace:toggle-selection-option'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]
        expect(findView.resultCounter.text()).toEqual('1 of 3')

      it "toggles find within a selction via and button and only finds matches within the selection", ->
        findView.findEditor.setText 'items'
        findView.selectionOptionButton.click()
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]
        expect(findView.resultCounter.text()).toEqual('1 of 3')

    describe "when regex is toggled", ->
      it "toggles regex via an event and finds text matching the pattern", ->
        editor.setCursorBufferPosition([2,0])
        findView.findEditor.trigger 'find-and-replace:toggle-regex-option'
        findView.findEditor.setText 'i[t]em+s'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      it "toggles regex via a button and finds text matching the pattern", ->
        editor.setCursorBufferPosition([2,0])
        findView.regexOptionButton.click()
        findView.findEditor.setText 'i[t]em+s'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      it "re-runs the search using the new find text when toggled", ->
        editor.setCursorBufferPosition([1,0])
        findView.findEditor.setText 's(o)rt'
        findView.findEditor.trigger 'find-and-replace:toggle-regex-option'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

      describe "when an invalid regex is entered", ->
        it "displays an error", ->
          editor.setCursorBufferPosition([2,0])
          findView.findEditor.trigger 'find-and-replace:toggle-regex-option'
          findView.findEditor.setText 'i[t'
          findView.findEditor.trigger 'core:confirm'
          expect(findView.descriptionLabel).toHaveClass 'text-error'

    describe "when case sensitivity is toggled", ->
      beforeEach ->
        editor.setText "-----\nwords\nWORDs\n"
        editor.setCursorBufferPosition([0,0])

      it "toggles case sensitivity via an event and finds text matching the pattern", ->
        findView.findEditor.setText 'WORDs'
        findView.findEditor.trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 5]]

        editor.setCursorBufferPosition([0,0])
        findView.findEditor.trigger 'find-and-replace:toggle-case-option'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 5]]

      it "toggles case sensitivity via a button and finds text matching the pattern", ->
        findView.findEditor.setText 'WORDs'
        findView.findEditor.trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 5]]

        editor.setCursorBufferPosition([0,0])
        findView.caseOptionButton.click()
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 5]]

    describe "highlighting search results", ->
      resultPosition = (result) ->
        {top: result.children()[0].style.top, left: result.children()[0].style.left}

      it "only highlights matches", ->
        expect(editorView.find('.find-result')).toHaveLength 6

        findView.findEditor.setText 'notinthefilebro'
        findView.findEditor.trigger 'core:confirm'

        runs ->
          expect(editorView.find('.find-result')).toHaveLength 0

      it "adds a class to the current match indicating it is the current match", ->
        position = (result) ->
          {top: result.children()[0].style.top, left: result.children()[0].style.left}

        firstResult = editorView.find('.current-result')
        firstPosition = resultPosition(firstResult)
        expect(editorView.find('.find-result')).toHaveLength 6
        expect(firstResult).toHaveLength 1

        findView.findEditor.trigger 'core:confirm'
        findView.findEditor.trigger 'core:confirm'

        nextResult = editorView.find('.current-result')
        nextPosition = resultPosition(nextResult)
        expect(nextResult).toHaveLength 1
        expect(nextPosition).not.toEqual firstPosition

        findView.findEditor.trigger 'find-and-replace:find-previous'
        findView.findEditor.trigger 'find-and-replace:find-previous'

        originalResult = editorView.find('.current-result')
        originalPosition = resultPosition(originalResult)
        expect(originalResult).toHaveLength 1
        expect(originalPosition).toEqual firstPosition

      it "adds a class to the result when the current selection equals the result's range", ->
        originalResult = editorView.find('.current-result')
        originalPosition = resultPosition(originalResult)
        expect(originalResult).toHaveLength 1

        editor.setSelectedBufferRange([[5, 16], [5, 20]])

        expect(editorView.find('.current-result')).toHaveLength 0
        editor.setSelectedBufferRange([[5, 16], [5, 21]])

        newResult = editorView.find('.current-result')
        newPosition = resultPosition(newResult)
        expect(newResult).toHaveLength 1
        expect(newPosition).not.toBe originalPosition

    describe "when user types in the find editor", ->
      advance = ->
        advanceClock(findView.findEditor.getEditor().getBuffer().stoppedChangingDelay + 1)

      beforeEach ->
        findView.findEditor.focus()

      it "updates the search results", ->
        expect(findView.descriptionLabel.text()).toContain "6 results"

        findView.findEditor.setText 'why do I need these 2 lines? The editor does not trigger contents-modified without them'
        advance()

        findView.findEditor.setText ''
        advance()
        expect(findView.descriptionLabel.text()).toContain "Find in Current Buffer"
        expect(findView).toHaveFocus()

        findView.findEditor.setText 'sort'
        advance()
        expect(findView.descriptionLabel.text()).toContain "5 results"
        expect(findView).toHaveFocus()

        findView.findEditor.setText 'items'
        advance()
        expect(findView.descriptionLabel.text()).toContain "6 results"
        expect(findView).toHaveFocus()

    describe "when another find is called", ->
      previousMarkers = null

      beforeEach ->
        previousMarkers = _.clone(editor.getMarkers())

      it "clears existing markers for another search", ->
        findView.findEditor.setText('notinthefile')
        findView.findEditor.trigger 'core:confirm'
        expect(editor.getMarkers().length).toEqual 1

      it "clears existing markers for an empty search", ->
        findView.findEditor.setText('')
        findView.findEditor.trigger 'core:confirm'
        expect(editor.getMarkers().length).toEqual 1

  describe "replacing", ->
    beforeEach ->
      editor.setCursorBufferPosition([2,0])
      editorView.trigger 'find-and-replace:show-replace'

      waitsForPromise ->
        activationPromise

      runs ->
        findView.findEditor.setText('items')
        findView.replaceEditor.setText('cats')

    describe "when the replacement string contains an escaped char", ->
      describe "when the regex option is chosen", ->
        beforeEach ->
          findView.findEditor.trigger 'find-and-replace:toggle-regex-option'

        it "inserts tabs and newlines", ->
          findView.replaceEditor.setText('\\t\\n')
          findView.replaceEditor.trigger 'core:confirm'
          expect(editor.getText()).toMatch(/\t\n/)

        it "doesn't insert a escaped char if there are multiple backslashs in front of the char", ->
          findView.replaceEditor.setText('\\\\t\\\t')
          findView.replaceEditor.trigger 'core:confirm'
          expect(editor.getText()).toMatch(/\\t\\\t/)

      describe "when in normal mode", ->
        it "inserts backslach n and t", ->
          findView.replaceEditor.setText('\\t\\n')
          findView.replaceEditor.trigger 'core:confirm'
          expect(editor.getText()).toMatch(/\\t\\n/)

        it "inserts carriage returns", ->
          textWithCarriageReturns = editor.getText().replace(/\n/g, "\r")
          editor.setText(textWithCarriageReturns)

          findView.replaceEditor.setText('\\t\\r')
          findView.replaceEditor.trigger 'core:confirm'
          expect(editor.getText()).toMatch(/\\t\\r/)

    describe "replace next", ->
      describe "when core:confirm is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          findView.replaceEditor.trigger 'core:confirm'
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

        it "replaceEditor maintains focus after core:confirm is run", ->
          findView.replaceEditor.focus()
          findView.replaceEditor.trigger 'core:confirm'
          expect(findView.replaceEditor).toHaveFocus()

        it "replaces the _current_ match and selects the next match", ->
          findView.findEditor.trigger 'core:confirm'
          editor.setSelectedBufferRange([[2, 8], [2, 13]])
          expect(findView.resultCounter.text()).toEqual('2 of 6')

          findView.replaceEditor.trigger 'core:confirm'
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

          findView.replaceEditor.trigger 'core:confirm'
          expect(findView.resultCounter.text()).toEqual('2 of 4')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return cats;"
          expect(editor.getSelectedBufferRange()).toEqual [[3, 16], [3, 21]]

      describe "when the replace next button is pressed", ->
        it "replaces the match after the cursor and selects the next match", ->
          $('.find-and-replace .btn-next').click()
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

      describe "when the 'find-and-replace:replace-next' event is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          editorView.trigger 'find-and-replace:replace-next'
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

    describe "replace previous", ->
      describe "when button is clicked", ->
        it "replaces the match after the cursor and selects the previous match", ->
          findView.findEditor.trigger 'core:confirm'
          findView.replacePreviousButton.click()
          expect(findView.resultCounter.text()).toEqual('1 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[1, 22], [1, 27]]

      describe "when command is triggered", ->
        it "replaces the match after the cursor and selects the previous match", ->
          findView.findEditor.trigger 'core:confirm'
          findView.trigger 'find-and-replace:replace-previous'
          expect(findView.resultCounter.text()).toEqual('1 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[1, 22], [1, 27]]

    describe "replace all", ->
      describe "when the replace all button is pressed", ->
        it "replaces all matched text", ->
          $('.find-and-replace .btn-all').click()
          expect(findView.resultCounter.text()).toEqual('no results')
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getText().match(/\bcats\b/g)).toHaveLength 6
          expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 0]]

        it "all changes are undoable in one transaction", ->
          $('.find-and-replace .btn-all').click()
          editor.undo()
          expect(editor.getText()).not.toMatch /\bcats\b/g

      describe "when the 'find-and-replace:replace-all' event is triggered", ->
        it "replaces all matched text", ->
          editorView.trigger 'find-and-replace:replace-all'
          expect(findView.resultCounter.text()).toEqual('no results')
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getText().match(/\bcats\b/g)).toHaveLength 6
          expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 0]]

    describe "replacement patterns", ->
      describe "when the regex option is true", ->
        it "replaces $1, $2, etc... with substring matches", ->
          findView.findEditor.trigger 'find-and-replace:toggle-regex-option'
          findView.findEditor.setText('(items)([\\.;])')
          findView.replaceEditor.setText('$2$1')
          editorView.trigger 'find-and-replace:replace-all'
          expect(editor.getText()).toMatch /;items/
          expect(editor.getText()).toMatch /\.items/

      describe "when the regex option is false", ->
        it "replaces the matches with without any regex subsitions", ->
          findView.findEditor.setText('items')
          findView.replaceEditor.setText('$&cats')
          editorView.trigger 'find-and-replace:replace-all'
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getText().match(/\$&cats\b/g)).toHaveLength 6

  describe "history", ->
    beforeEach ->
      editorView.trigger 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

    describe "when there is no history", ->
      it "retains unsearched text", ->
        text = 'something I want to search for but havent yet'
        findView.findEditor.setText(text)

        findView.findEditor.trigger 'core:move-up'
        expect(findView.findEditor.getText()).toEqual ''

        findView.findEditor.trigger 'core:move-down'
        expect(findView.findEditor.getText()).toEqual text

    describe "when there is history", ->
      [oneRange, twoRange, threeRange] = []

      beforeEach ->
        editorView.trigger 'find-and-replace:show'
        editor.setText("zero\none\ntwo\nthree\n")
        findView.findEditor.setText('one')
        findView.findEditor.trigger 'core:confirm'
        findView.findEditor.setText('two')
        findView.findEditor.trigger 'core:confirm'
        findView.findEditor.setText('three')
        findView.findEditor.trigger 'core:confirm'

      it "can navigate the entire history stack", ->
        expect(findView.findEditor.getText()).toEqual 'three'

        findView.findEditor.trigger 'core:move-down'
        expect(findView.findEditor.getText()).toEqual ''

        findView.findEditor.trigger 'core:move-down'
        expect(findView.findEditor.getText()).toEqual ''

        findView.findEditor.trigger 'core:move-up'
        expect(findView.findEditor.getText()).toEqual 'three'

        findView.findEditor.trigger 'core:move-up'
        expect(findView.findEditor.getText()).toEqual 'two'

        findView.findEditor.trigger 'core:move-up'
        expect(findView.findEditor.getText()).toEqual 'one'

        findView.findEditor.trigger 'core:move-up'
        expect(findView.findEditor.getText()).toEqual 'one'

        findView.findEditor.trigger 'core:move-down'
        expect(findView.findEditor.getText()).toEqual 'two'

      it "retains the current unsearched text", ->
        text = 'something I want to search for but havent yet'
        findView.findEditor.setText(text)

        findView.findEditor.trigger 'core:move-up'
        expect(findView.findEditor.getText()).toEqual 'three'

        findView.findEditor.trigger 'core:move-down'
        expect(findView.findEditor.getText()).toEqual text

        findView.findEditor.trigger 'core:move-up'
        expect(findView.findEditor.getText()).toEqual 'three'

        findView.findEditor.trigger 'core:move-down'
        findView.findEditor.trigger 'core:confirm'

        findView.findEditor.trigger 'core:move-down'
        expect(findView.findEditor.getText()).toEqual ''

      it "adds confirmed patterns to the history", ->
        findView.findEditor.setText("cool stuff")
        findView.findEditor.trigger 'core:confirm'

        findView.findEditor.setText("cooler stuff")
        findView.findEditor.trigger 'core:move-up'
        expect(findView.findEditor.getText()).toEqual 'cool stuff'

        findView.findEditor.trigger 'core:move-up'
        expect(findView.findEditor.getText()).toEqual 'three'

      describe "when user types in the find editor", ->
        advance = ->
          advanceClock(findView.findEditor.getEditor().getBuffer().stoppedChangingDelay + 1)

        beforeEach ->
          findView.findEditor.focus()

        it "does not add live searches to the history", ->
          expect(findView.descriptionLabel.text()).toContain "1 result"

          # I really do not understand why this are necessary...
          findView.findEditor.setText 'FIXME: necessary search for some reason??'
          advance()

          findView.findEditor.setText 'nope'
          advance()
          expect(findView.descriptionLabel.text()).toContain 'nope'
          findView.findEditor.setText 'zero'
          advance()
          expect(findView.descriptionLabel.text()).toContain "zero"

          findView.findEditor.trigger 'core:move-up'
          expect(findView.findEditor.getText()).toEqual 'three'
