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
    it "detaches from the root view", ->
      editor.trigger 'find-and-replace:show'
      $(document.activeElement).trigger 'core:cancel'
      expect(rootView.find('.find-and-replace')).not.toExist()

  describe "finding", ->
    beforeEach ->
      editor.setCursorBufferPosition([2,0])
      editor.trigger 'find-and-replace:show'
      findView.findEditor.setText 'items'
      $(document.activeElement).trigger 'core:confirm'

    it "selects the first match following the cursor", ->
      expect(findView.resultCounter.text()).toEqual('2 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

    it "selects the next match when the next match button is pressed", ->
      $('.find-and-replace .icon-next').click()
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]

    it "selects the next match when the 'find-and-replace:focus-next' event is triggered", ->
      editor.trigger('find-and-replace:find-next')
      expect(findView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]

    it "selects the previous match when the previous match button is pressed", ->
      $('.find-and-replace .icon-previous').click()
      expect(findView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 27], [1, 22]]

    it "selects the previous match when the 'find-and-replace:focus-previous' event is triggered", ->
      editor.trigger('find-and-replace:find-previous')
      expect(findView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 27], [1, 22]]

    it "replaces results counter with number of results found when user moves the cursor", ->
      editor.moveCursorDown()
      expect(findView.resultCounter.text()).toBe '6 found'

    describe "when the active pane item changes", ->
      describe "when a new edit session is activated", ->
        it "udpates the result view and selects the correct text", ->
          rootView.open('coffee.coffee')
          expect(findView.resultCounter.text()).toEqual('1 of 6')
          expect(editor.getSelectedBufferRange()).toEqual [[1, 9], [1, 14]]

      describe "when all active pane items are closed", ->
        it "updates the result view", ->
          editor.trigger 'core:close'
          console.log "----"
          expect(findView.resultCounter.text()).toEqual('no results')

      describe "when the active pane item is not an edit session", ->
        it "updates the result view", ->
          anotherOpener = (pathToOpen, options) -> $('another')
          Project.registerOpener(anotherOpener)

          rootView.open "another"
          expect(findView.resultCounter.text()).toEqual('no results')

          Project.unregisterOpener(anotherOpener)

    describe "when regex is toggled", ->
      it "toggles regex via an event and finds text matching the pattern", ->
        editor.setCursorBufferPosition([2,0])
        findView.trigger 'find-and-replace:toggle-regex-option'
        findView.findEditor.setText 'i[t]em+s'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      it "toggles regex via a button and finds text matching the pattern", ->
        editor.setCursorBufferPosition([2,0])
        findView.regexOptionButton.click()
        findView.findEditor.setText 'i[t]em+s'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

    describe "when case sensitivity is toggled", ->
      beforeEach ->
        editor.setText "-----\nwords\nWORDs\n"
        editor.setCursorBufferPosition([0,0])

      it "toggles case sensitivity via an event and finds text matching the pattern", ->
        findView.findEditor.setText 'WORDs'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 5]]

        editor.setCursorBufferPosition([0,0])
        findView.trigger 'find-and-replace:toggle-case-sensitive-option'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 5]]

      it "toggles case sensitiviAty via a button and finds text matching the pattern", ->
        findView.findEditor.setText 'WORDs'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 5]]

        editor.setCursorBufferPosition([0,0])
        findView.caseSensitiveOptionButton.click()
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 5]]

  describe "replacing", ->
    beforeEach ->
      editor.setCursorBufferPosition([2,0])
      editor.trigger 'find-and-replace:display-replace'
      findView.findEditor.setText('items')
      findView.replaceEditor.setText('cats')

    describe "replace next", ->
      describe "when core:confirm is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          findView.replaceEditor.trigger 'core:confirm'
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

      describe "when the replace next button is pressed", ->
        it "replaces the match after the cursor and selects the next match", ->
          $('.find-and-replace .btn-next').click()
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

      describe "when the 'find-and-replace:replace-next' event is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          editor.trigger 'find-and-replace:replace-next'
          expect(findView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

    describe "replace all", ->
      describe "when the replace all button is pressed", ->
        it "replaces the match after the cursor and selects the next match", ->
          $('.find-and-replace .btn-all').click()
          expect(findView.resultCounter.text()).toEqual('0 found')
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 0]]

      describe "when the 'find-and-replace:replace-next' event is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          editor.trigger 'find-and-replace:replace-all'
          expect(findView.resultCounter.text()).toEqual('0 found')
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 0]]

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
