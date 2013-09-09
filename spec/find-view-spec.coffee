shell = require 'shell'
path = require 'path'
$ = require 'jquery'
RootView = require 'root-view'
Project = require 'project'
{View} = require 'space-pen'

describe 'FindView', ->
  [editor, findView] = []

  beforeEach ->
    window.rootView = new RootView()
    rootView.open('sample.js')
    rootView.enableKeymap()
    rootView.attachToDom()
    editor = rootView.getActiveView()
    pack = atom.activatePackage("find-and-replace")
    findView = pack.mainModule.findView

  describe "when find-and-replace:show is triggered", ->
    it "attaches FindView to the root view", ->
      editor.trigger 'find-and-replace:show'
      expect(rootView.find('.find-and-replace')).toExist()

  describe "when core:cancel is triggered", ->
    beforeEach ->
      editor.trigger 'find-and-replace:show'
      findView.findEditor.setText 'items'
      $(document.activeElement).trigger 'core:confirm'
      findView.focus()

    it "detaches from the root view", ->
      $(document.activeElement).trigger 'core:cancel'
      expect(rootView.find('.find-and-replace')).not.toExist()

    it "removes highlighted matches", ->
      findResultsView = editor.find('.search-results')

      $(document.activeElement).trigger 'core:cancel'
      expect(findResultsView.parent()).not.toExist()

  describe "serialization", ->
    it "serializes find and replace history", ->
      findView.findEditor.setText("items")
      findView.replaceEditor.setText("cat")
      findView.replaceAll()

      findView.findEditor.setText("sort")
      findView.replaceEditor.setText("dog")
      findView.replaceAll()

      atom.deactivatePackage("find-and-replace")
      pack = atom.activatePackage("find-and-replace")
      findView = pack.mainModule.findView

      findView.findEditor.trigger('core:move-up')
      expect(findView.findEditor.getText()).toBe 'sort'

      findView.replaceEditor.trigger('core:move-up')
      expect(findView.replaceEditor.getText()).toBe 'dog'

    it "serializes find options ", ->
      expect(findView.caseOptionButton).not.toHaveClass 'enabled'
      expect(findView.regexOptionButton).not.toHaveClass 'enabled'
      expect(findView.selectionOptionButton).not.toHaveClass 'enabled'

      findView.caseOptionButton.click()
      findView.regexOptionButton.click()
      findView.selectionOptionButton.click()

      expect(findView.caseOptionButton).toHaveClass 'enabled'
      expect(findView.regexOptionButton).toHaveClass 'enabled'
      expect(findView.selectionOptionButton).toHaveClass 'enabled'

      atom.deactivatePackage("find-and-replace")
      pack = atom.activatePackage("find-and-replace")
      findView = pack.mainModule.findView

      expect(findView.caseOptionButton).toHaveClass 'enabled'
      expect(findView.regexOptionButton).toHaveClass 'enabled'
      expect(findView.selectionOptionButton).toHaveClass 'enabled'

  describe "finding", ->
    beforeEach ->
      editor.setCursorBufferPosition([2,0])
      editor.trigger 'find-and-replace:show'
      findView.findEditor.setText 'items'
      $(document.activeElement).trigger 'core:confirm'

    it "doesn't change the selection, beeps if there are no matches and keeps focus on the find view", ->
      editor.setCursorBufferPosition([2,0])
      spyOn(shell, 'beep')
      findView.findEditor.setText 'notinthefilebro'
      findView.focus()
      $(document.activeElement).trigger 'core:confirm'

      expect(editor.getCursorBufferPosition()).toEqual [2,0]
      expect(shell.beep).toHaveBeenCalled()
      expect(findView.find(':focus')).toExist()

    it "selects the first match following the cursor", ->
      expect(findView.resultCounter.text()).toEqual('2 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      findView.findEditor.trigger 'core:confirm'
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]
      expect(editor.find(':focus')).toExist()

    it "selects the next match when the next match button is pressed", ->
      $('.find-and-replace .icon-next').click()
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]

    it "selects the next match when the 'find-and-replace:find-next' event is triggered", ->
      editor.trigger('find-and-replace:find-next')
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]

    it "will re-run search if 'find-and-replace:find-next' is triggered after changing the findEditor's text", ->
      findView.findEditor.setText 'sort'
      findView.findEditor.trigger 'find-and-replace:find-next'

      expect(findView.resultCounter.text()).toEqual('3 of 5')
      expect(editor.getSelectedBufferRange()).toEqual [[8, 11], [8, 15]]

    it "selects the previous match when the previous match button is pressed", ->
      $('.find-and-replace .icon-previous').click()
      expect(findView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 27], [1, 22]]

    it "selects the previous match when the 'find-and-replace:find-previous' event is triggered", ->
      editor.trigger('find-and-replace:find-previous')
      expect(findView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 27], [1, 22]]

    it "will re-run search if 'find-and-replace:find-previous' is triggered after changing the findEditor's text", ->
      findView.findEditor.setText 'sort'
      findView.findEditor.trigger 'find-and-replace:find-previous'

      expect(findView.resultCounter.text()).toEqual('2 of 5')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

    it "replaces results counter with number of results found when user moves the cursor", ->
      editor.moveCursorDown()
      expect(findView.resultCounter.text()).toBe '6 found'

    it "places the selected text into the find editor when find-and-replace:set-find-pattern is triggered", ->
      editor.setSelectedBufferRange([[1,6],[1,10]])
      rootView.trigger 'find-and-replace:use-selection-as-find-pattern'

      expect(findView.findEditor.getText()).toBe 'sort'
      expect(editor.getSelectedBufferRange()).toEqual [[1,6],[1,10]]

      rootView.trigger 'find-and-replace:find-next'
      expect(editor.getSelectedBufferRange()).toEqual [[8,11],[8,15]]

    describe "when the active pane item changes", ->
      describe "when a new edit session is activated", ->
        it "udpates the result view and selects the correct text", ->
          rootView.open('sample.coffee')
          expect(findView.resultCounter.text()).toEqual('no results')
          expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 0]]

        it "highlights the found text in the new edit session", ->
          findResultsView = editor.find('.search-results')

          rootView.open('sample.coffee')
          expect(findResultsView.children()).toHaveLength 0

      describe "when all active pane items are closed", ->
        it "updates the result count", ->
          editor.trigger 'core:close'
          expect(findView.resultCounter.text()).toEqual('no results')

        it "removes all highlights", ->
          findResultsView = editor.find('.search-results')

          editor.trigger 'core:close'
          expect(findResultsView.children()).toHaveLength 0

      describe "when the active pane item is not an edit session", ->
        [anotherOpener] = []

        beforeEach ->
          anotherOpener = (pathToOpen, options) -> $('another')
          Project.registerOpener(anotherOpener)

        afterEach ->
          Project.unregisterOpener(anotherOpener)

        it "updates the result view", ->
          rootView.open "another"
          expect(findView.resultCounter.text()).toEqual('no results')

        it "removes all highlights", ->
          findResultsView = editor.find('.search-results')

          rootView.open "another"
          expect(findResultsView.children()).toHaveLength 0

      describe "when a new edit session is activated on a different pane", ->
        it "updates the result view and selects the correct text", ->
          newEditor = editor.splitRight(project.open('sample.coffee'))
          expect(findView.resultCounter.text()).toEqual('no results')
          expect(newEditor.getSelectedBufferRange()).toEqual [[0, 0], [0, 0]]

          findView.trigger 'find-and-replace:find-next'
          expect(findView.resultCounter.text()).toEqual('1 of 7')
          expect(newEditor.getSelectedBufferRange()).toEqual [[1, 9], [1, 14]]

        it "highlights the found text in the new edit session (and removes the highlights from the other)", ->
          findResultsView = editor.find('.search-results')

          expect(findResultsView.children()).toHaveLength 6
          newEditor = editor.splitRight(project.open('sample.coffee'))
          expect(findResultsView.children()).toHaveLength 0

    describe "when the buffer contents change", ->
      it "re-runs the search", ->
        findResultsView = editor.find('.search-results')
        editor.setCursorBufferPosition([4,0])
        editor.insertText("items items")

        expect(findResultsView.children()).toHaveLength 8
        expect(findView.resultCounter.text()).toEqual('8 found')
        expect(editor.getSelectedBufferRange()).toEqual [[4, 11], [4, 11]]

    describe "when finding within a selection", ->
      beforeEach ->
        editor.setSelectedBufferRange [[2, 0], [4, 0]]
        findView.focus()

      it "toggles find within a selction via and event and only finds matches within the selection", ->
        findView.findEditor.setText 'items'
        findView.trigger 'find-and-replace:toggle-selection-option'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]
        expect(findView.resultCounter.text()).toEqual('1 of 3')

      it "toggles find within a selction via and button and only finds matches within the selection", ->
        findView.findEditor.setText 'items'
        findView.selectionOptionButton.click()
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]
        expect(findView.resultCounter.text()).toEqual('1 of 3')

    describe "when regex is toggled", ->
      beforeEach ->
        findView.focus()

      it "toggles regex via an event and finds text matching the pattern", ->
        editor.setCursorBufferPosition([2,0])
        findView.trigger 'find-and-replace:toggle-regex-option'
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
        findView.trigger 'find-and-replace:toggle-regex-option'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 10]]

    describe "when case sensitivity is toggled", ->
      beforeEach ->
        editor.setText "-----\nwords\nWORDs\n"
        editor.setCursorBufferPosition([0,0])
        findView.focus()

      it "toggles case sensitivity via an event and finds text matching the pattern", ->
        findView.findEditor.setText 'WORDs'
        $(document.activeElement).trigger 'core:confirm'
        findView.focus()
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 5]]

        editor.setCursorBufferPosition([0,0])
        findView.trigger 'find-and-replace:toggle-case-option'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 5]]

      it "toggles case sensitivity via a button and finds text matching the pattern", ->
        findView.findEditor.setText 'WORDs'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 5]]

        editor.setCursorBufferPosition([0,0])
        findView.caseOptionButton.click()
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 5]]

    describe "highlighting search results", ->
      [findResultsView] = []
      beforeEach ->
        findResultsView = editor.find('.search-results')

      it "only highlights matches", ->
        expect(findResultsView.parent()[0]).toBe editor.underlayer[0]
        expect(findResultsView.children()).toHaveLength 6

        findView.findEditor.setText 'notinthefilebro'
        findView.focus()
        $(document.activeElement).trigger 'core:confirm'

        expect(findResultsView.children()).toHaveLength 0

  describe "replacing", ->
    beforeEach ->
      editor.setCursorBufferPosition([2,0])
      editor.trigger 'find-and-replace:show-replace'
      findView.findEditor.setText('items')
      findView.replaceEditor.setText('cats')

    describe "replace next", ->
      describe "when core:confirm is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          findView.replaceEditor.trigger 'core:confirm'
          expect(findView.resultCounter.text()).toEqual('5 found')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 12], [2, 12]]

          findView.replaceEditor.trigger 'core:confirm'
          expect(findView.resultCounter.text()).toEqual('4 found')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return cats;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 37], [2, 37]]

      describe "when the replace next button is pressed", ->
        it "replaces the match after the cursor and selects the next match", ->
          $('.find-and-replace .btn-next').click()
          expect(findView.resultCounter.text()).toEqual('5 found')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 12], [2, 12]]

      describe "when the 'find-and-replace:replace-next' event is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          editor.trigger 'find-and-replace:replace-next'
          expect(findView.resultCounter.text()).toEqual('5 found')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 12], [2, 12]]

    describe "replace all", ->
      describe "when the replace all button is pressed", ->
        it "replaces all matched text", ->
          $('.find-and-replace .btn-all').click()
          expect(findView.resultCounter.text()).toEqual('no results')
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getText().match(/\bcats\b/g)).toHaveLength 6
          expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 0]]

      describe "when the 'find-and-replace:replace-all' event is triggered", ->
        it "replaces all matched text", ->
          editor.trigger 'find-and-replace:replace-all'
          expect(findView.resultCounter.text()).toEqual('no results')
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getText().match(/\bcats\b/g)).toHaveLength 6
          expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 0]]

    describe "replacement patterns", ->
      describe "when the regex option is true", ->
        it "replaces $1, $2, etc... with substring matches", ->
          findView.trigger 'find-and-replace:toggle-regex-option'
          findView.findEditor.setText('i(t)e(m)s')
          findView.replaceEditor.setText('$2i$1$1ens')
          editor.trigger 'find-and-replace:replace-all'
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getText().match(/\bmittens\b/g)).toHaveLength 6

      describe "when the regex option is false", ->
        it "replaces the matches with without any regex subsitions", ->
          findView.findEditor.setText('items')
          findView.replaceEditor.setText('$&cats')
          editor.trigger 'find-and-replace:replace-all'
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getText().match(/\$&cats\b/g)).toHaveLength 6

  describe "history", ->
    [oneRange, twoRange, threeRange] = []
    beforeEach ->
      editor.trigger 'find-and-replace:show'
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
