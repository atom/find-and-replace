_ = require 'underscore-plus'
{$} = require 'atom-space-pen-views'

path = require 'path'

# TODO: Remove references to logical display buffer when it gets released.

describe 'FindView', ->
  [workspaceElement, editorView, editor, findView, activationPromise] = []

  getFindAtomPanel = ->
    workspaceElement.querySelector('.find-and-replace').parentNode

  getResultDecorations = (editor, clazz) ->
    if editor.decorationsStateForScreenRowRange?
      resultDecorations = []
      for id, decoration of editor.decorationsStateForScreenRowRange(0, editor.getLineCount())
        if decoration.properties.class is clazz
          resultDecorations.push(decoration)
    else
      markerIdForDecorations = editor.decorationsForScreenRowRange(0, editor.getLineCount())
      resultDecorations = []
      for markerId, decorations of markerIdForDecorations
        for decoration in decorations
          resultDecorations.push decoration if decoration.getProperties().class is clazz
    resultDecorations

  beforeEach ->
    spyOn(atom, 'beep')
    workspaceElement = atom.views.getView(atom.workspace)
    atom.project.setPaths([path.join(__dirname, 'fixtures')])

    waitsForPromise ->
      atom.workspace.open('sample.js')

    runs ->
      jasmine.attachToDOM(workspaceElement)
      editor = atom.workspace.getActiveTextEditor()
      editorView = atom.views.getView(editor)

      activationPromise = atom.packages.activatePackage("find-and-replace").then ({mainModule}) ->
        mainModule.createViews()
        {findView} = mainModule

  describe "when find-and-replace:show is triggered", ->
    it "attaches FindView to the root view", ->
      atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(workspaceElement.querySelector('.find-and-replace')).toBeDefined()

    it "populates the findEditor with selection when there is a selection", ->
      editor.setSelectedBufferRange([[2, 8], [2, 13]])
      atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(getFindAtomPanel()).toBeVisible()
        expect(findView.findEditor.getText()).toBe('items')

        findView.findEditor.setText('')

        editor.setSelectedBufferRange([[2, 14], [2, 20]])
        atom.commands.dispatch editorView, 'find-and-replace:show'
        expect(getFindAtomPanel()).toBeVisible()
        expect(findView.findEditor.getText()).toBe('length')

    it "does not change the findEditor text when there is no selection", ->
      editor.setSelectedBufferRange([[2, 8], [2, 8]])
      atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        findView.findEditor.setText 'kitten'
        atom.commands.dispatch editorView, 'find-and-replace:show'
        expect(findView.findEditor.getText()).toBe('kitten')

    it "does not change the findEditor text when there is a multiline selection", ->
      editor.setSelectedBufferRange([[2, 8], [3, 12]])
      atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(getFindAtomPanel()).toBeVisible()
        expect(findView.findEditor.getText()).toBe('')

    it "honors config settings for find options", ->
      atom.config.set('find-and-replace.useRegex', true)
      atom.config.set('find-and-replace.caseSensitive', true)
      atom.config.set('find-and-replace.inCurrentSelection', true)

      atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(findView.caseOptionButton).toHaveClass 'selected'
        expect(findView.regexOptionButton).toHaveClass 'selected'
        expect(findView.selectionOptionButton).toHaveClass 'selected'

    it "places selected text into the find editor and escapes it when Regex is enabled", ->
      atom.config.set('find-and-replace.useRegex', true)
      editor.setSelectedBufferRange([[6, 6], [6, 65]])
      atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(findView.findEditor.getText()).toBe 'current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);'

  describe "when find-and-replace:toggle is triggered", ->
    it "toggles the visibility of the FindView", ->
      atom.commands.dispatch workspaceElement, 'find-and-replace:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(getFindAtomPanel()).toBeVisible()
        atom.commands.dispatch workspaceElement, 'find-and-replace:toggle'
        expect(getFindAtomPanel()).not.toBeVisible()

  describe "when the find-view is focused and window:focus-next-pane is triggered", ->
    beforeEach ->
      atom.commands.dispatch editorView, 'find-and-replace:show'
      waitsForPromise -> activationPromise

    it "attaches FindView to the root view", ->
      expect(workspaceElement.querySelector('.find-and-replace')).toHaveFocus()
      atom.commands.dispatch(findView.findEditor.element, 'window:focus-next-pane')
      expect(workspaceElement.querySelector('.find-and-replace')).not.toHaveFocus()

  describe "find-and-replace:show-replace", ->
    it "focuses the replace editor", ->
      atom.commands.dispatch editorView, 'find-and-replace:show-replace'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(findView.replaceEditor).toHaveFocus()

    it "places the current selection in the replace editor", ->
      editor.setSelectedBufferRange([[0, 16], [0, 27]])
      atom.commands.dispatch editorView, 'find-and-replace:show-replace'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(findView.replaceEditor.getText()).toBe 'function ()'

    it "does not escape the text when the regex option is enabled", ->
      # it doesnt need to!
      editor.setSelectedBufferRange([[0, 16], [0, 27]])
      atom.commands.dispatch editorView, 'find-and-replace:show'
      atom.commands.dispatch editorView, 'find-and-replace:toggle-regex-option'
      atom.commands.dispatch editorView, 'find-and-replace:show-replace'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(findView.replaceEditor.getText()).toBe 'function ()'

  describe "core:cancel", ->
    beforeEach ->
      atom.commands.dispatch editorView, 'find-and-replace:show'
      waitsForPromise ->
        activationPromise

      runs ->
        findView.findEditor.setText 'items'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        findView.focus()

    describe "when core:cancel is triggered on the find view", ->
      it "detaches from the workspace view", ->
        atom.commands.dispatch(document.activeElement, 'core:cancel')
        expect(getFindAtomPanel()).not.toBeVisible()

      it "removes highlighted matches", ->
        expect(workspaceElement).toHaveClass 'find-visible'
        atom.commands.dispatch(document.activeElement, 'core:cancel')
        expect(workspaceElement).not.toHaveClass 'find-visible'

    describe "when core:cancel is triggered on an empty pane", ->
      it "hides the find panel", ->
        paneElement = atom.views.getView(atom.workspace.getActivePane())
        paneElement.focus()
        atom.commands.dispatch(paneElement, 'core:cancel')
        expect(getFindAtomPanel()).not.toBeVisible()

    describe "when core:cancel is triggered on an editor", ->
      it "detaches from the workspace view", ->
        waitsForPromise ->
          atom.workspace.open()

        runs ->
          atom.commands.dispatch editorView, 'core:cancel'
          expect(getFindAtomPanel()).not.toBeVisible()

    describe "when core:cancel is triggered on a mini editor", ->
      it "leaves the find view attached", ->
        miniEditor = document.createElement('atom-text-editor')
        miniEditor.setAttribute('mini', '')
        atom.workspace.addTopPanel(item: miniEditor)
        miniEditor.focus()
        atom.commands.dispatch(miniEditor, 'core:cancel')
        expect(getFindAtomPanel()).toBeVisible()

  describe "serialization", ->
    it "serializes find and replace history", ->
      atom.commands.dispatch editorView, 'find-and-replace:show'

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
          mainModule.createViews()
          {findView} = mainModule

        atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toBe 'shift'
        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toBe 'sort'
        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toBe 'items'

        atom.commands.dispatch(findView.replaceEditor.element, 'core:move-up')
        expect(findView.replaceEditor.getText()).toBe 'dog'
        atom.commands.dispatch(findView.replaceEditor.element, 'core:move-up')
        expect(findView.replaceEditor.getText()).toBe 'cat'

    it "serializes find options ", ->
      atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(findView.caseOptionButton).not.toHaveClass 'selected'
        expect(findView.regexOptionButton).not.toHaveClass 'selected'
        expect(findView.selectionOptionButton).not.toHaveClass 'selected'
        expect(findView.wholeWordOptionButton).not.toHaveClass 'selected'

        findView.caseOptionButton.click()
        findView.regexOptionButton.click()
        findView.selectionOptionButton.click()
        findView.wholeWordOptionButton.click()

        expect(findView.caseOptionButton).toHaveClass 'selected'
        expect(findView.regexOptionButton).toHaveClass 'selected'
        expect(findView.selectionOptionButton).toHaveClass 'selected'
        expect(findView.wholeWordOptionButton).toHaveClass 'selected'

        atom.packages.deactivatePackage("find-and-replace")

        activationPromise = atom.packages.activatePackage("find-and-replace").then ({mainModule}) ->
          mainModule.createViews()
          {findView} = mainModule

        atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(findView.caseOptionButton).toHaveClass 'selected'
        expect(findView.regexOptionButton).toHaveClass 'selected'
        expect(findView.selectionOptionButton).toHaveClass 'selected'
        expect(findView.wholeWordOptionButton).toHaveClass 'selected'

  describe "finding", ->
    beforeEach ->
      atom.config.set('find-and-replace.focusEditorAfterSearch', false)
      editor.setCursorBufferPosition([2, 0])
      atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

      runs ->
        findView.findEditor.setText 'items'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')

    describe "when find-and-replace:confirm is triggered", ->
      it "runs a search", ->
        findView.findEditor.setText 'notinthefile'
        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:confirm')
        expect(getResultDecorations(editor, 'find-result')).toHaveLength 0

        findView.findEditor.setText 'items'
        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:confirm')
        expect(getResultDecorations(editor, 'find-result')).toHaveLength 5

    describe "when the find string contains an escaped char", ->
      beforeEach ->
        editor.setText("\t\n\\t\\\\")
        editor.setCursorBufferPosition([0, 0])

      describe "when regex seach is enabled", ->
        beforeEach ->
          atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option')

        it "finds a backslash", ->
          findView.findEditor.setText('\\\\')
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 1]]

        it "finds a newline", ->
          findView.findEditor.setText('\\n')
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [1, 0]]

        it "finds a tab character", ->
          findView.findEditor.setText('\\t')
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 1]]

      describe "when regex seach is disabled", ->
        it "finds the literal backslash t", ->
          findView.findEditor.setText('\\t')
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 2]]

        it "finds a backslash", ->
          findView.findEditor.setText('\\')
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 1]]

        it "finds two backslashes", ->
          findView.findEditor.setText('\\\\')
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(editor.getSelectedBufferRange()).toEqual [[1, 2], [1, 4]]

        it "doesn't find when escaped", ->
          findView.findEditor.setText('\\\\t')
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 0]]

    describe "when focusEditorAfterSearch is set", ->
      beforeEach ->
        atom.config.set('find-and-replace.focusEditorAfterSearch', true)
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')

      it "selects the first match following the cursor and correctly focuses the editor", ->
        expect(findView.resultCounter.text()).toEqual('3 of 6')
        expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]
        expect(editorView).toHaveFocus()

    describe "when whole-word search is enabled", ->
      beforeEach ->
        editor.setText("-----\nswhole-wordy\nwhole-word\nword\nwhole-swords")
        editor.setCursorBufferPosition([0, 0])
        atom.commands.dispatch findView.findEditor.element, 'find-and-replace:toggle-whole-word-option'

      it "finds the whole words", ->
        findView.findEditor.setText('word')
        atom.commands.dispatch findView.findEditor.element, 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 6], [2, 10]]

      it "doesn't highlights the search inside words", ->
        findView.findEditor.setText('word')
        atom.commands.dispatch findView.findEditor.element, 'core:confirm'
        expect(getResultDecorations(editor, 'find-result')).toHaveLength 1
        expect(getResultDecorations(editor, 'current-result')).toHaveLength 1

    it "doesn't change the selection, beeps if there are no matches and keeps focus on the find view", ->
      editor.setCursorBufferPosition([2, 0])
      findView.findEditor.setText 'notinthefilebro'
      findView.findEditor.focus()

      atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
      expect(editor.getCursorBufferPosition()).toEqual [2, 0]
      expect(atom.beep).toHaveBeenCalled()
      expect(findView).toHaveFocus()

      expect(findView.descriptionLabel.text()).toEqual "No results found for 'notinthefilebro'"

    describe "updating the replace button enablement", ->
      it "enables the replace buttons when are search results", ->
        findView.findEditor.setText 'item'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(findView.replaceAllButton).not.toHaveClass 'disabled'
        expect(findView.replaceNextButton).not.toHaveClass 'disabled'

        disposable = findView.replaceTooltipSubscriptions
        spyOn(disposable, 'dispose')

        findView.findEditor.setText 'it'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(findView.replaceAllButton).not.toHaveClass 'disabled'
        expect(findView.replaceNextButton).not.toHaveClass 'disabled'
        expect(disposable.dispose).not.toHaveBeenCalled()

        findView.findEditor.setText 'nopenotinthefile'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(findView.replaceAllButton).toHaveClass 'disabled'
        expect(findView.replaceNextButton).toHaveClass 'disabled'
        expect(disposable.dispose).toHaveBeenCalled()

        findView.findEditor.setText 'i'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(findView.replaceAllButton).not.toHaveClass 'disabled'
        expect(findView.replaceNextButton).not.toHaveClass 'disabled'

        findView.findEditor.setText ''
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(findView.replaceAllButton).toHaveClass 'disabled'
        expect(findView.replaceNextButton).toHaveClass 'disabled'

    describe "updating the descriptionLabel", ->
      it "properly updates the info message", ->
        findView.findEditor.setText 'item'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(findView.descriptionLabel.text()).toEqual "6 results found for 'item'"

        findView.findEditor.setText 'notinthefilenope'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(findView.descriptionLabel.text()).toEqual "No results found for 'notinthefilenope'"

        findView.findEditor.setText 'item'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(findView.descriptionLabel.text()).toEqual "6 results found for 'item'"

        findView.findEditor.setText ''
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(findView.descriptionLabel.text()).toContain "Find in Current Buffer"

      describe "when there is a find-error", ->
        beforeEach ->
          editor.setCursorBufferPosition([2, 0])
          atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option')

        it "displays the error", ->
          findView.findEditor.setText 'i[t'
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(findView.descriptionLabel).toHaveClass 'text-error'
          expect(findView.descriptionLabel.text()).toContain 'Invalid regular expression'

        it "will be reset when there is no longer an error", ->
          findView.findEditor.setText 'i[t'
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(findView.descriptionLabel).toHaveClass 'text-error'

          findView.findEditor.setText ''
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(findView.descriptionLabel).not.toHaveClass 'text-error'
          expect(findView.descriptionLabel.text()).toContain "Find in Current Buffer"

          findView.findEditor.setText 'item'
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(findView.descriptionLabel).not.toHaveClass 'text-error'
          expect(findView.descriptionLabel.text()).toContain "6 results"

    it "selects the first match following the cursor", ->
      expect(findView.resultCounter.text()).toEqual('2 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]
      expect(findView.findEditor).toHaveFocus()

    it "selects the next match when the next match button is pressed", ->
      findView.nextButton.click()
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]

    it "selects the previous match when the next match button is pressed while holding shift", ->
      shiftClick = $.Event('click')
      shiftClick.shiftKey = true
      findView.nextButton.trigger shiftClick
      expect(findView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 22], [1, 27]]

    it "selects the next match when the 'find-and-replace:find-next' event is triggered and correctly focuses the editor", ->
      expect(findView).toHaveFocus()
      atom.commands.dispatch editorView, 'find-and-replace:find-next'
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]
      expect(editorView).toHaveFocus()

    it "selects the previous match before the cursor when the 'find-and-replace:show-previous' event is triggered", ->
      expect(findView.resultCounter.text()).toEqual('2 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:show-previous')
      expect(findView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 22], [1, 27]]
      expect(findView.findEditor).toHaveFocus()

    it "will re-run search if 'find-and-replace:find-next' is triggered after changing the findEditor's text", ->
      findView.findEditor.setText 'sort'
      atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:find-next')

      expect(findView.resultCounter.text()).toEqual('3 of 5')
      expect(editor.getSelectedBufferRange()).toEqual [[8, 11], [8, 15]]

    it "'find-and-replace:find-next' adds to the findEditor's history", ->
      findView.findEditor.setText 'sort'
      atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:find-next')

      expect(findView.resultCounter.text()).toEqual('3 of 5')

      findView.findEditor.setText 'nope'
      atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
      expect(findView.findEditor.getText()).toEqual 'sort'

    it "selects the previous match when the 'find-and-replace:find-previous' event is triggered and correctly focuses the editor", ->
      expect(findView).toHaveFocus()
      atom.commands.dispatch editorView, 'find-and-replace:find-previous'
      expect(findView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 27], [1, 22]]
      expect(editorView).toHaveFocus()

    it "will re-run search if 'find-and-replace:find-previous' is triggered after changing the findEditor's text", ->
      findView.findEditor.setText 'sort'
      atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:find-previous')

      expect(findView.resultCounter.text()).toEqual('2 of 5')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

    it "selects all matches when 'find-and-replace:find-all' is triggered and correctly focuses the editor", ->
      expect(findView).toHaveFocus()
      atom.commands.dispatch findView.findEditor.element, 'find-and-replace:find-all'
      expect(editor.getSelectedBufferRanges()).toEqual [[[1, 27], [1, 22]], [[2, 8], [2, 13]], [[2, 34], [2, 39]], [[3, 16], [3, 21]], [[4, 10], [4, 15]], [[5, 16], [5, 21]]]
      expect(editorView).toHaveFocus()

    it "will re-run search if 'find-and-replace:find-all' is triggered after changing the findEditor's text", ->
      findView.findEditor.setText 'sort'
      atom.commands.dispatch findView.findEditor.element, 'find-and-replace:find-all'
      expect(editor.getSelectedBufferRanges()).toEqual [[[0, 9], [0, 13]], [[1, 6], [1, 10]], [[8, 11], [8, 15]], [[8, 43], [8, 47]], [[11, 9], [11, 13]]]

    it "replaces results counter with number of results found when user moves the cursor", ->
      editor.moveDown()
      expect(findView.resultCounter.text()).toBe '6 found'

    it "replaces results counter x of y text when user selects a marked range", ->
      editor.moveDown()
      editor.setSelectedBufferRange([[2, 34], [2, 39]])
      expect(findView.resultCounter.text()).toEqual('3 of 6')

    describe "when find-and-replace:use-selection-as-find-pattern is triggered", ->
      it "places the selected text into the find editor", ->
        editor.setSelectedBufferRange([[1, 6], [1, 10]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'

        expect(findView.findEditor.getText()).toBe 'sort'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

        atom.commands.dispatch workspaceElement, 'find-and-replace:find-next'
        expect(editor.getSelectedBufferRange()).toEqual [[8, 11], [8, 15]]

        atom.workspace.destroyActivePane()
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(findView.findEditor.getText()).toBe 'sort'
        expect(editor.getSelectedBufferRange()).toEqual [[8, 11], [8, 15]]

      it "places the word under the cursor into the find editor", ->
        editor.setSelectedBufferRange([[1, 8], [1, 8]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'

        expect(findView.findEditor.getText()).toBe 'sort'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 8], [1, 8]]

        atom.commands.dispatch workspaceElement, 'find-and-replace:find-next'
        expect(editor.getSelectedBufferRange()).toEqual [[8, 11], [8, 15]]

      it "places the previously selected text into the find editor if no selection", ->
        editor.setSelectedBufferRange([[1, 6], [1, 10]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(findView.findEditor.getText()).toBe 'sort'

        editor.setSelectedBufferRange([[1, 1], [1, 1]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(findView.findEditor.getText()).toBe 'sort'

      it "places selected text into the find editor and escapes it when Regex is enabled", ->
        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option')
        editor.setSelectedBufferRange([[6, 6], [6, 65]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:use-selection-as-find-pattern'
        expect(findView.findEditor.getText()).toBe 'current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);'

    describe "when find-and-replace:find-next-selected is triggered", ->
      it "places the selected text into the find editor and finds the next occurrence", ->
        editor.setSelectedBufferRange([[0, 9], [0, 13]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:find-next-selected'

        expect(findView.findEditor.getText()).toBe 'sort'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

      it "places the word under the cursor into the find editor and finds the next occurrence", ->
        editor.setSelectedBufferRange([[1, 8], [1, 8]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:find-next-selected'

        expect(findView.findEditor.getText()).toBe 'sort'
        expect(editor.getSelectedBufferRange()).toEqual [[8, 11], [8, 15]]

    describe "when find-and-replace:find-previous-selected is triggered", ->
      it "places the selected text into the find editor and finds the previous occurrence ", ->
        editor.setSelectedBufferRange([[0, 9], [0, 13]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:find-previous-selected'

        expect(findView.findEditor.getText()).toBe 'sort'
        expect(editor.getSelectedBufferRange()).toEqual [[11, 9], [11, 13]]

      it "places the word under the cursor into the find editor and finds the previous occurrence", ->
        editor.setSelectedBufferRange([[8, 13], [8, 13]])
        atom.commands.dispatch workspaceElement, 'find-and-replace:find-previous-selected'

        expect(findView.findEditor.getText()).toBe 'sort'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

    it "does not highlight the found text when the find view is hidden", ->
      atom.commands.dispatch(findView.findEditor.element, 'core:cancel')
      atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:find-next')

    describe "when the active pane item changes", ->
      beforeEach ->
        editor.setSelectedBufferRange([[0, 0], [0, 0]])

      describe "when a new edit session is activated", ->
        it "reruns the search on the new edit session", ->
          waitsForPromise ->
            atom.workspace.open('sample.coffee')

          runs ->
            editor = atom.workspace.getActivePaneItem()
            expect(findView.resultCounter.text()).toEqual('7 found')
            expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 0]]

        it "initially highlights the found text in the new edit session", ->
          expect(getResultDecorations(editor, 'find-result')).toHaveLength 6

          waitsForPromise ->
            atom.workspace.open('sample.coffee')

          runs ->
            # old editor has no more results
            expect(getResultDecorations(editor, 'find-result')).toHaveLength 0

            # new one has 7 results
            newEditor = atom.workspace.getActiveTextEditor()
            expect(getResultDecorations(newEditor, 'find-result')).toHaveLength 7

        it "highlights the found text in the new edit session when find next is triggered", ->
          waitsForPromise ->
            atom.workspace.open('sample.coffee')

          runs ->
            atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:find-next')
            newEditor = atom.workspace.getActiveTextEditor()
            expect(getResultDecorations(newEditor, 'find-result')).toHaveLength 6
            expect(getResultDecorations(newEditor, 'current-result')).toHaveLength 1

      describe "when all active pane items are closed", ->
        it "updates the result count", ->
          atom.commands.dispatch editorView, 'core:close'
          expect(findView.resultCounter.text()).toEqual('no results')

      describe "when the active pane item is not an edit session", ->
        [anotherOpener, openerDisposable] = []

        beforeEach ->
          anotherOpener = (pathToOpen, options) -> document.createElement('div')
          openerDisposable = atom.workspace.addOpener(anotherOpener)

        afterEach ->
          openerDisposable.dispose()

        it "updates the result view", ->
          waitsForPromise ->
            atom.workspace.open "another"

          runs ->
            expect(findView.resultCounter.text()).toEqual('no results')

      describe "when a new edit session is activated on a different pane", ->
        it "initially highlights all the sample.js results", ->
          expect(getResultDecorations(editor, 'find-result')).toHaveLength 6

        it "reruns the search on the new editor", ->
          newEditor = null

          waitsForPromise ->
            opener =
              if atom.workspace.buildTextEditor?
                atom.workspace.open('sample.coffee', activateItem: false)
              else
                atom.project.open('sample.coffee')

            opener.then (o) -> newEditor = o

          runs ->
            newEditor = atom.workspace.paneForItem(editor).splitRight(items: [newEditor]).getActiveItem()
            expect(getResultDecorations(newEditor, 'find-result')).toHaveLength 7

            expect(findView.resultCounter.text()).toEqual('7 found')
            expect(newEditor.getSelectedBufferRange()).toEqual [[0, 0], [0, 0]]

            atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:find-next')
            expect(findView.resultCounter.text()).toEqual('1 of 7')
            expect(newEditor.getSelectedBufferRange()).toEqual [[1, 9], [1, 14]]

        it "highlights the found text in the new edit session (and removes the highlights from the other)", ->
          [newEditor, newEditorView] = []

          waitsForPromise ->
            atom.workspace.open('sample.coffee').then (o) -> newEditor = o

          runs ->
            # old editor has no more results
            expect(getResultDecorations(editor, 'find-result')).toHaveLength 0

            # new one has 7 results
            expect(getResultDecorations(newEditor, 'find-result')).toHaveLength 7

        it "will still highlight results after the split pane has been destroyed", ->
          [newEditor, newEditorView] = []

          waitsForPromise ->
            atom.workspace.open('sample.coffee').then (o) -> newEditor = o

          runs ->
            originalPane = atom.workspace.paneForItem(editor)
            splitPane = atom.workspace.paneForItem(editor).splitRight()
            originalPane.moveItemToPane(newEditor, splitPane, 0)
            expect(getResultDecorations(newEditor, 'find-result')).toHaveLength 7

            newEditorView = atom.views.getView(editor)
            atom.commands.dispatch newEditorView, 'core:close'
            editorView.focus()

            expect(atom.workspace.getActiveTextEditor()).toBe editor

          runs ->
            expect(getResultDecorations(editor, 'find-result')).toHaveLength 6

    describe "when the buffer contents change", ->
      it "re-runs the search", ->
        editor.setSelectedBufferRange([[1, 26], [1, 27]])
        editor.insertText("")

        window.advanceClock(1000)
        expect(findView.resultCounter.text()).toEqual('5 found')

        editor.insertText("s")
        window.advanceClock(1000)
        expect(findView.resultCounter.text()).toEqual('6 found')

      it "does not beep if no matches were found", ->
        editor.setCursorBufferPosition([2, 0])
        findView.findEditor.setText 'notinthefilebro'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        atom.beep.reset()

        editor.insertText("blah blah")
        expect(atom.beep).not.toHaveBeenCalled()

    describe "when in current selection is toggled", ->
      beforeEach ->
        editor.setSelectedBufferRange [[2, 0], [4, 0]]

      it "toggles find within a selction via and event and only finds matches within the selection", ->
        findView.findEditor.setText 'items'
        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-selection-option')
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]
        expect(findView.resultCounter.text()).toEqual('1 of 3')

      it "toggles find within a selction via and button and only finds matches within the selection", ->
        findView.findEditor.setText 'items'
        findView.selectionOptionButton.click()
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]
        expect(findView.resultCounter.text()).toEqual('1 of 3')

      describe "when there is no selection", ->
        beforeEach ->
          editor.setSelectedBufferRange [[0, 0], [0, 0]]

        it "toggles find within a selction via and event and only finds matches within the selection", ->
          findView.findEditor.setText 'items'
          atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-selection-option')
          expect(editor.getSelectedBufferRange()).toEqual [[1, 22], [1, 27]]
          expect(findView.resultCounter.text()).toEqual('1 of 6')

    describe "when regex is toggled", ->
      it "toggles regex via an event and finds text matching the pattern", ->
        editor.setCursorBufferPosition([2, 0])
        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option')
        findView.findEditor.setText 'i[t]em+s'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      it "toggles regex via a button and finds text matching the pattern", ->
        editor.setCursorBufferPosition([2, 0])
        findView.regexOptionButton.click()
        findView.findEditor.setText 'i[t]em+s'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      it "re-runs the search using the new find text when toggled", ->
        editor.setCursorBufferPosition([1, 0])
        findView.findEditor.setText 's(o)rt'
        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option')
        expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

      describe "when an invalid regex is entered", ->
        it "displays an error", ->
          editor.setCursorBufferPosition([2, 0])
          atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option')
          findView.findEditor.setText 'i[t'
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          expect(findView.descriptionLabel).toHaveClass 'text-error'

    describe "when whole-word is toggled", ->
      it "toggles whole-word via an event and finds text matching the pattern", ->
        editor.setCursorBufferPosition([0, 0])
        findView.findEditor.setText 'sort'
        atom.commands.dispatch findView.findEditor.element, 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 9], [0, 13]]

        atom.commands.dispatch findView.findEditor.element, 'find-and-replace:toggle-whole-word-option'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

      it "toggles whole-word via a button and finds text matching the pattern", ->
        editor.setCursorBufferPosition([0, 0])
        findView.findEditor.setText 'sort'
        atom.commands.dispatch findView.findEditor.element, 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 9], [0, 13]]

        findView.wholeWordOptionButton.click()
        expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

      it "re-runs the search using the new find text when toggled", ->
        editor.setCursorBufferPosition([8, 0])
        findView.findEditor.setText 'apply'
        atom.commands.dispatch findView.findEditor.element, 'find-and-replace:toggle-whole-word-option'
        expect(editor.getSelectedBufferRange()).toEqual [[11, 20], [11, 25]]

    describe "when case sensitivity is toggled", ->
      beforeEach ->
        editor.setText "-----\nwords\nWORDs\n"
        editor.setCursorBufferPosition([0, 0])

      it "toggles case sensitivity via an event and finds text matching the pattern", ->
        findView.findEditor.setText 'WORDs'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 5]]

        editor.setCursorBufferPosition([0, 0])
        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-case-option')
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 5]]

      it "toggles case sensitivity via a button and finds text matching the pattern", ->
        findView.findEditor.setText 'WORDs'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 5]]

        editor.setCursorBufferPosition([0, 0])
        findView.caseOptionButton.click()
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 5]]

    describe "highlighting search results", ->
      getResultDecoration = (clazz) ->
        getResultDecorations(editor, clazz)[0]

      it "only highlights matches", ->
        expect(getResultDecorations(editor, 'find-result')).toHaveLength 5

        findView.findEditor.setText 'notinthefilebro'
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')

        runs ->
          expect(getResultDecorations(editor, 'find-result')).toHaveLength 0

      it "adds a class to the current match indicating it is the current match", ->
        firstResultMarker = getResultDecoration('current-result')
        expect(getResultDecorations(editor, 'find-result')).toHaveLength 5

        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')

        nextResultMarker = getResultDecoration('current-result')
        expect(nextResultMarker).not.toEqual firstResultMarker

        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:find-previous')
        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:find-previous')

        originalResultMarker = getResultDecoration('current-result')
        expect(originalResultMarker).toEqual firstResultMarker

      it "adds a class to the result when the current selection equals the result's range", ->
        originalResultMarker = getResultDecoration('current-result')
        expect(originalResultMarker).toBeDefined()

        editor.setSelectedBufferRange([[5, 16], [5, 20]])

        expect(getResultDecoration('current-result')).toBeUndefined()
        editor.setSelectedBufferRange([[5, 16], [5, 21]])

        newResultMarker = getResultDecoration('current-result')
        expect(newResultMarker).toBeDefined()
        expect(newResultMarker).not.toBe originalResultMarker

    describe "when user types in the find editor", ->
      advance = ->
        advanceClock(findView.findEditor.getModel().getBuffer().stoppedChangingDelay + 1)

      beforeEach ->
        findView.findEditor.focus()

      it "scrolls to the first match if the settings scrollToResultOnLiveSearch is true", ->
        atom.config.set('find-and-replace.scrollToResultOnLiveSearch', true)
        if editorView.logicalDisplayBuffer
          editorView.setHeight(3)
        else
          editor.setHeight(3)
        editor.moveToTop()
        if editorView.logicalDisplayBuffer
          originalScrollPosition = editorView.getScrollTop()
        else
          originalScrollPosition = editor.getScrollTop()
        findView.findEditor.setText 'Array'
        advance()
        if editorView.logicalDisplayBuffer
          expect(editorView.getScrollTop()).not.toEqual originalScrollPosition
        else
          expect(editor.getScrollTop()).not.toEqual originalScrollPosition
        expect(editor.getSelectedBufferRange()).toEqual [[11, 14], [11, 19]]
        expect(findView.findEditor).toHaveFocus()

      it "doesn't scroll to the first match if the settings scrollToResultOnLiveSearch is false", ->
        atom.config.set('find-and-replace.scrollToResultOnLiveSearch', false)
        if editorView.logicalDisplayBuffer
          editorView.setHeight(3)
        else
          editor.setHeight()
        editor.moveToTop()
        if editorView.logicalDisplayBuffer
          originalScrollPosition = editorView.getScrollTop()
        else
          originalScrollPosition = editor.getScrollTop()
        findView.findEditor.setText 'Array'
        advance()
        if editorView.logicalDisplayBuffer
          expect(editorView.getScrollTop()).toEqual originalScrollPosition
        else
          expect(editor.getScrollTop()).toEqual originalScrollPosition
        expect(editor.getSelectedBufferRange()).toEqual []
        expect(findView.findEditor).toHaveFocus()

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

      it "respects the `liveSearchMinimumCharacters` setting", ->
        expect(findView.descriptionLabel.text()).toContain "6 results"
        atom.config.set('find-and-replace.liveSearchMinimumCharacters', 3)

        findView.findEditor.setText 'why do I need these 2 lines? The editor does not trigger contents-modified without them'
        advance()

        findView.findEditor.setText ''
        advance()
        expect(findView.descriptionLabel.text()).toContain "Find in Current Buffer"
        expect(findView).toHaveFocus()

        findView.findEditor.setText 'ite'
        advance()
        expect(findView.descriptionLabel.text()).toContain "6 results"
        expect(findView).toHaveFocus()

        findView.findEditor.setText 'i'
        advance()
        expect(findView.descriptionLabel.text()).toContain "6 results"
        expect(findView).toHaveFocus()

        findView.findEditor.setText ''
        advance()
        expect(findView.descriptionLabel.text()).toContain "Find in Current Buffer"
        expect(findView).toHaveFocus()

        atom.config.set('find-and-replace.liveSearchMinimumCharacters', 0)

        findView.findEditor.setText 'i'
        advance()
        expect(findView.descriptionLabel.text()).toContain "20 results"
        expect(findView).toHaveFocus()

    describe "when another find is called", ->
      previousMarkers = null

      beforeEach ->
        previousMarkers = _.clone(editor.getMarkers())

      it "clears existing markers for another search", ->
        findView.findEditor.setText('notinthefile')
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(getResultDecorations(editor, 'find-result')).toHaveLength 0


      it "clears existing markers for an empty search", ->
        findView.findEditor.setText('')
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        expect(getResultDecorations(editor, 'find-result')).toHaveLength 0

  describe "replacing", ->
    beforeEach ->
      editor.setCursorBufferPosition([2, 0])
      atom.commands.dispatch editorView, 'find-and-replace:show-replace'

      waitsForPromise ->
        activationPromise

      runs ->
        findView.findEditor.setText('items')
        findView.replaceEditor.setText('cats')

    describe "when the find string is empty", ->
      it "beeps", ->
        findView.findEditor.setText('')
        atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
        expect(atom.beep).toHaveBeenCalled()

    describe "when the replacement string contains an escaped char", ->
      describe "when the regex option is chosen", ->
        beforeEach ->
          atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option')

        it "inserts tabs and newlines", ->
          findView.replaceEditor.setText('\\t\\n')
          atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
          expect(editor.getText()).toMatch(/\t\n/)

        it "doesn't insert a escaped char if there are multiple backslashs in front of the char", ->
          findView.replaceEditor.setText('\\\\t\\\t')
          atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
          expect(editor.getText()).toMatch(/\\t\\\t/)

      describe "when in normal mode", ->
        it "inserts backslach n and t", ->
          findView.replaceEditor.setText('\\t\\n')
          atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
          expect(editor.getText()).toMatch(/\\t\\n/)

        it "inserts carriage returns", ->
          textWithCarriageReturns = editor.getText().replace(/\n/g, "\r")
          editor.setText(textWithCarriageReturns)

          findView.replaceEditor.setText('\\t\\r')
          atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
          expect(editor.getText()).toMatch(/\\t\\r/)

    describe "replace next", ->
      describe "when core:confirm is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineTextForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

        it "replaceEditor maintains focus after core:confirm is run", ->
          findView.replaceEditor.focus()
          atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
          expect(findView.replaceEditor).toHaveFocus()

        it "replaces the _current_ match and selects the next match", ->
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          editor.setSelectedBufferRange([[2, 8], [2, 13]])
          expect(findView.resultCounter.text()).toEqual('2 of 6')

          atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineTextForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

          atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
          expect(findView.resultCounter.text()).toEqual('2 of 4')
          expect(editor.lineTextForBufferRow(2)).toBe "    if (cats.length <= 1) return cats;"
          expect(editor.getSelectedBufferRange()).toEqual [[3, 16], [3, 21]]

        it "replaces the _current_ match and selects the next match", ->
          editor.setText "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s"
          editor.setSelectedBufferRange([[0, 0], [0, 5]])
          findView.findEditor.setText('Lorem')
          findView.replaceEditor.setText('replacement')

          atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm')
          expect(editor.lineTextForBufferRow(0)).toBe "replacement Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s"
          expect(editor.getSelectedBufferRange()).toEqual [[0, 81], [0, 86]]

      describe "when the replace next button is pressed", ->
        it "replaces the match after the cursor and selects the next match", ->
          $('.find-and-replace .btn-next').click()
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineTextForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]
          expect(editorView).toHaveFocus()

      describe "when the 'find-and-replace:replace-next' event is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          atom.commands.dispatch editorView, 'find-and-replace:replace-next'
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineTextForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

    describe "replace previous", ->
      describe "when command is triggered", ->
        it "replaces the match after the cursor and selects the previous match", ->
          atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
          atom.commands.dispatch(findView.element, 'find-and-replace:replace-previous')
          expect(findView.resultCounter.text()).toEqual('1 of 5')
          expect(editor.lineTextForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
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
          atom.commands.dispatch editorView, 'find-and-replace:replace-all'
          expect(findView.resultCounter.text()).toEqual('no results')
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getText().match(/\bcats\b/g)).toHaveLength 6
          expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 0]]

    describe "replacement patterns", ->
      describe "when the regex option is true", ->
        it "replaces $1, $2, etc... with substring matches", ->
          atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option')
          findView.findEditor.setText('(items)([\\.;])')
          findView.replaceEditor.setText('$2$1')
          atom.commands.dispatch editorView, 'find-and-replace:replace-all'
          expect(editor.getText()).toMatch /;items/
          expect(editor.getText()).toMatch /\.items/

      describe "when the regex option is false", ->
        it "replaces the matches with without any regex subsitions", ->
          findView.findEditor.setText('items')
          findView.replaceEditor.setText('$&cats')
          atom.commands.dispatch editorView, 'find-and-replace:replace-all'
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getText().match(/\$&cats\b/g)).toHaveLength 6

  describe "history", ->
    beforeEach ->
      atom.commands.dispatch editorView, 'find-and-replace:show'

      waitsForPromise ->
        activationPromise

    describe "when there is no history", ->
      it "retains unsearched text", ->
        text = 'something I want to search for but havent yet'
        findView.findEditor.setText(text)

        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toEqual ''

        atom.commands.dispatch(findView.findEditor.element, 'core:move-down')
        expect(findView.findEditor.getText()).toEqual text

    describe "when there is history", ->
      [oneRange, twoRange, threeRange] = []

      beforeEach ->
        atom.commands.dispatch editorView, 'find-and-replace:show'
        editor.setText("zero\none\ntwo\nthree\n")
        findView.findEditor.setText('one')
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        findView.findEditor.setText('two')
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')
        findView.findEditor.setText('three')
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')

      it "can navigate the entire history stack", ->
        expect(findView.findEditor.getText()).toEqual 'three'

        atom.commands.dispatch(findView.findEditor.element, 'core:move-down')
        expect(findView.findEditor.getText()).toEqual ''

        atom.commands.dispatch(findView.findEditor.element, 'core:move-down')
        expect(findView.findEditor.getText()).toEqual ''

        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toEqual 'three'

        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toEqual 'two'

        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toEqual 'one'

        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toEqual 'one'

        atom.commands.dispatch(findView.findEditor.element, 'core:move-down')
        expect(findView.findEditor.getText()).toEqual 'two'

      it "retains the current unsearched text", ->
        text = 'something I want to search for but havent yet'
        findView.findEditor.setText(text)

        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toEqual 'three'

        atom.commands.dispatch(findView.findEditor.element, 'core:move-down')
        expect(findView.findEditor.getText()).toEqual text

        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toEqual 'three'

        atom.commands.dispatch(findView.findEditor.element, 'core:move-down')
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')

        atom.commands.dispatch(findView.findEditor.element, 'core:move-down')
        expect(findView.findEditor.getText()).toEqual ''

      it "adds confirmed patterns to the history", ->
        findView.findEditor.setText("cool stuff")
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm')

        findView.findEditor.setText("cooler stuff")
        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toEqual 'cool stuff'

        atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
        expect(findView.findEditor.getText()).toEqual 'three'

      describe "when user types in the find editor", ->
        advance = ->
          advanceClock(findView.findEditor.getModel().getBuffer().stoppedChangingDelay + 1)

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

          atom.commands.dispatch(findView.findEditor.element, 'core:move-up')
          expect(findView.findEditor.getText()).toEqual 'three'

  describe "panel focus", ->
    beforeEach ->
      atom.commands.dispatch editorView, 'find-and-replace:show'
      waitsForPromise -> activationPromise

    it "focuses the find editor when the panel gets focus", ->
      findView.replaceEditor.focus()
      expect(findView.replaceEditor).toHaveFocus()

      findView.focus()
      expect(findView.findEditor).toHaveFocus()

    it "moves focus between editors with find-and-replace:focus-next", ->
      findView.findEditor.focus()
      expect(findView.findEditor).toHaveClass('is-focused')
      expect(findView.replaceEditor).not.toHaveClass('is-focused')

      atom.commands.dispatch findView.findEditor.element, 'find-and-replace:focus-next'
      expect(findView.findEditor).not.toHaveClass('is-focused')
      expect(findView.replaceEditor).toHaveClass('is-focused')

      atom.commands.dispatch findView.replaceEditor.element, 'find-and-replace:focus-next'
      expect(findView.findEditor).toHaveClass('is-focused')
      expect(findView.replaceEditor).not.toHaveClass('is-focused')

  describe "when language-javascript is active", ->
    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage("language-javascript")

    it "uses the regexp grammar when regex-mode is loaded from configuration", ->
      atom.config.set('find-and-replace.useRegex', true)
      atom.commands.dispatch editorView, 'find-and-replace:show'
      waitsForPromise ->
        activationPromise

      runs ->
        expect(findView.model.getFindOptions().useRegex).toBe true
        expect(findView.findEditor.getModel().getGrammar().scopeName).toBe 'source.js.regexp'
        expect(findView.replaceEditor.getModel().getGrammar().scopeName).toBe 'source.js.regexp.replacement'

    describe "when panel is active", ->
      beforeEach ->
        atom.commands.dispatch editorView, 'find-and-replace:show'
        waitsForPromise -> activationPromise

      it "does not use regexp grammar when in non-regex mode", ->
        expect(findView.model.getFindOptions().useRegex).not.toBe true
        expect(findView.findEditor.getModel().getGrammar().scopeName).toBe 'text.plain.null-grammar'
        expect(findView.replaceEditor.getModel().getGrammar().scopeName).toBe 'text.plain.null-grammar'

      it "uses regexp grammar when in regex mode and clears the regexp grammar when regex is disabled", ->
        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option')

        expect(findView.model.getFindOptions().useRegex).toBe true
        expect(findView.findEditor.getModel().getGrammar().scopeName).toBe 'source.js.regexp'
        expect(findView.replaceEditor.getModel().getGrammar().scopeName).toBe 'source.js.regexp.replacement'

        atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option')

        expect(findView.model.getFindOptions().useRegex).not.toBe true
        expect(findView.findEditor.getModel().getGrammar().scopeName).toBe 'text.plain.null-grammar'
        expect(findView.replaceEditor.getModel().getGrammar().scopeName).toBe 'text.plain.null-grammar'
