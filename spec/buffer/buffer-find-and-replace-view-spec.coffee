$ = require 'jquery'
RootView = require 'root-view'

fdescribe 'BufferFindAndReplaceView', ->
  [editor, bufferFindAndReplaceView] = []

  beforeEach ->
    window.rootView = new RootView()
    rootView.open('sample.js')
    rootView.enableKeymap()
    rootView.attachToDom()
    editor = rootView.getActiveView()
    pack = atom.activatePackage("find-and-replace")
    bufferFindAndReplaceView = pack.mainModule.bufferFindAndReplaceView

  describe "when find-and-replace:show is triggered", ->
    it "attaches BufferFindAndReplaceView to the root view", ->
      editor.trigger 'find-and-replace:show'
      expect(rootView.find('.find-and-replace')).toExist()

  describe "when core:cancel is triggered", ->
    it "detaches from the root view", ->
      editor.trigger 'find-and-replace:show'
      $(document.activeElement).trigger 'core:cancel'
      expect(rootView.find('.find-and-replace')).not.toExist()

  ffdescribe "finding", ->
    beforeEach ->
      editor.setCursorBufferPosition([2,0])
      editor.trigger 'find-and-replace:show'
      bufferFindAndReplaceView.findEditor.setText 'items'
      $(document.activeElement).trigger 'core:confirm'

    it "selects the first match following the cursor", ->
      expect(bufferFindAndReplaceView.resultCounter.text()).toEqual('2 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

    it "selects the next match when the next match button is pressed", ->
      $('.find-and-replace .icon-next').click()
      expect(bufferFindAndReplaceView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]

    it "selects the next match when the 'find-and-replace:focus-next' event is triggered", ->
      editor.trigger('find-and-replace:find-next')
      expect(bufferFindAndReplaceView.resultCounter.text()).toEqual('3 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[2, 34], [2, 39]]

    it "selects the previous match when the previous match button is pressed", ->
      $('.find-and-replace .icon-previous').click()
      expect(bufferFindAndReplaceView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 27], [1, 22]]

    fffit "selects the previous match when the 'find-and-replace:focus-previous' event is triggered", ->
      editor.trigger('find-and-replace:find-previous')
      expect(bufferFindAndReplaceView.resultCounter.text()).toEqual('1 of 6')
      expect(editor.getSelectedBufferRange()).toEqual [[1, 27], [1, 22]]

    it "replaces results counter with number of results found when user moves cursor outside a marker", ->
      editor.moveCursorDown()
      expect(bufferFindAndReplaceView.resultCounter.text()).toBe '6 found'
      editor.moveCursorUp()
      expect(bufferFindAndReplaceView.resultCounter.text()).toBe '2 of 6'

    describe "when the active editor changes", ->
      describe "when no more editors exist", ->
        it "detaches the view when there are no more active editors", ->
          editor.trigger 'core:close'
          expect(rootView.find('.find-and-replace')).not.toExist()

    describe "when regex is toggled", ->
      it "toggles regex via an event and finds text matching the pattern", ->
        editor.setCursorBufferPosition([2,0])
        bufferFindAndReplaceView.trigger 'find-and-replace:toggle-regex-option'
        bufferFindAndReplaceView.findEditor.setText 'i[t]em+s'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

      it "toggles regex via a button and finds text matching the pattern", ->
        editor.setCursorBufferPosition([2,0])
        bufferFindAndReplaceView.regexOptionButton.click()
        bufferFindAndReplaceView.findEditor.setText 'i[t]em+s'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 8], [2, 13]]

    describe "when case sensitivity is toggled", ->
      beforeEach ->
        editor.setText "-----\nwords\nWORDs\n"
        editor.setCursorBufferPosition([0,0])

      it "toggles case sensitivity via an event and finds text matching the pattern", ->
        bufferFindAndReplaceView.findEditor.setText 'WORDs'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 5]]

        editor.setCursorBufferPosition([0,0])
        bufferFindAndReplaceView.trigger 'find-and-replace:toggle-case-sensitive-option'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 5]]

      it "toggles case sensitiviAty via a button and finds text matching the pattern", ->
        bufferFindAndReplaceView.findEditor.setText 'WORDs'
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [1, 5]]

        editor.setCursorBufferPosition([0,0])
        bufferFindAndReplaceView.caseSensitiveOptionButton.click()
        $(document.activeElement).trigger 'core:confirm'
        expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 5]]

  describe "replacing", ->
    beforeEach ->
      editor.setCursorBufferPosition([2,0])
      editor.trigger 'find-and-replace:display-replace'
      bufferFindAndReplaceView.findEditor.setText('items')
      bufferFindAndReplaceView.replaceEditor.setText('cats')

    describe "replace next", ->
      describe "when core:confirm is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          bufferFindAndReplaceView.replaceEditor.trigger 'core:confirm'
          expect(bufferFindAndReplaceView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

      describe "when the replace next button is pressed", ->
        it "replaces the match after the cursor and selects the next match", ->
          $('.find-and-replace .btn-next').click()
          expect(bufferFindAndReplaceView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

      describe "when the 'find-and-replace:replace-next' event is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          editor.trigger 'find-and-replace:replace-next'
          expect(bufferFindAndReplaceView.resultCounter.text()).toEqual('2 of 5')
          expect(editor.lineForBufferRow(2)).toBe "    if (cats.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[2, 33], [2, 38]]

    describe "replace all", ->
      describe "when the replace all button is pressed", ->
        it "replaces the match after the cursor and selects the next match", ->
          $('.find-and-replace .btn-all').click()
          expect(bufferFindAndReplaceView.resultCounter.text()).toEqual('0 found')
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 0]]

      describe "when the 'find-and-replace:replace-next' event is triggered", ->
        it "replaces the match after the cursor and selects the next match", ->
          editor.trigger 'find-and-replace:replace-all'
          expect(bufferFindAndReplaceView.resultCounter.text()).toEqual('0 found')
          expect(editor.getText()).not.toMatch /items/
          expect(editor.getSelectedBufferRange()).toEqual [[2, 0], [2, 0]]

  describe "history", ->
    [oneRange, twoRange, threeRange] = []
    beforeEach ->
      editor.trigger 'find-and-replace:show'
      editor.setText("zero\none\ntwo\nthree\n")
      bufferFindAndReplaceView.findEditor.setText('one')
      bufferFindAndReplaceView.findEditor.trigger 'core:confirm'
      bufferFindAndReplaceView.findEditor.setText('two')
      bufferFindAndReplaceView.findEditor.trigger 'core:confirm'
      bufferFindAndReplaceView.findEditor.setText('three')
      bufferFindAndReplaceView.findEditor.trigger 'core:confirm'

    it "can navigate the entire history stack", ->
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual 'three'

      bufferFindAndReplaceView.findEditor.trigger 'core:move-down'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual ''

      bufferFindAndReplaceView.findEditor.trigger 'core:move-down'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual ''

      bufferFindAndReplaceView.findEditor.trigger 'core:move-up'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual 'three'

      bufferFindAndReplaceView.findEditor.trigger 'core:move-up'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual 'two'

      bufferFindAndReplaceView.findEditor.trigger 'core:move-up'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual 'one'

      bufferFindAndReplaceView.findEditor.trigger 'core:move-up'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual 'one'

      bufferFindAndReplaceView.findEditor.trigger 'core:move-down'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual 'two'

    it "retains the current unsearched text", ->
      text = 'something I want to search for but havent yet'
      bufferFindAndReplaceView.findEditor.setText(text)

      bufferFindAndReplaceView.findEditor.trigger 'core:move-up'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual 'three'

      bufferFindAndReplaceView.findEditor.trigger 'core:move-down'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual text

      bufferFindAndReplaceView.findEditor.trigger 'core:move-up'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual 'three'

      bufferFindAndReplaceView.findEditor.trigger 'core:move-down'
      bufferFindAndReplaceView.findEditor.trigger 'core:confirm'

      bufferFindAndReplaceView.findEditor.trigger 'core:move-down'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual ''

    it "adds confirmed patterns to the history", ->
      bufferFindAndReplaceView.findEditor.setText("cool stuff")
      bufferFindAndReplaceView.findEditor.trigger 'core:confirm'

      bufferFindAndReplaceView.findEditor.setText("cooler stuff")
      bufferFindAndReplaceView.findEditor.trigger 'core:move-up'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual 'cool stuff'

      bufferFindAndReplaceView.findEditor.trigger 'core:move-up'
      expect(bufferFindAndReplaceView.findEditor.getText()).toEqual 'three'
