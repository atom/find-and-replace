path = require 'path'
SelectNext = require '../lib/select-next'

describe "SelectNext", ->
  [workspaceElement, editorElement, editor, promise, findOptions] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    atom.project.setPaths([path.join(__dirname, 'fixtures')])

    waitsForPromise ->
      atom.workspace.open('sample.js')

    runs ->
      jasmine.attachToDOM(workspaceElement)
      editor = atom.workspace.getActiveTextEditor()
      editorElement = atom.views.getView(editor)
      promise = atom.packages.activatePackage("find-and-replace").then ({mainModule}) ->
        findOptions = mainModule.findOptions
      atom.commands.dispatch editorElement, 'find-and-replace:show'

    waitsForPromise ->
      promise

  describe "find-and-replace:select-next", ->
    describe "when nothing is selected", ->
      it "selects the word under the cursor", ->
        editor.setCursorBufferPosition([1, 3])
        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [[[1, 2], [1, 5]]]

    describe "when a word is selected", ->
      describe "when findOptions.wholeWord is false", ->
        beforeEach ->
          findOptions.set(wholeWord: false, caseSensitive: true)

        it "selects the next occurrence of the selected word skipping any non-word matches", ->
          editor.setText """
            for
            information
            format
            another for
            fork
            a 3rd for is here
          """

          editor.setSelectedBufferRange([[0, 0], [0, 3]])

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 3]]
            [[1, 2], [1, 5]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 3]]
            [[1, 2], [1, 5]]
            [[2, 0], [2, 3]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 3]]
            [[1, 2], [1, 5]]
            [[2, 0], [2, 3]]
            [[3, 8], [3, 11]]
          ]

          editor.setText "Testing reallyTesting"
          editor.setCursorBufferPosition([0, 0])

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 7]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 7]]
            [[0, 14], [0, 21]]
          ]

      describe "when findOptions.wholeWord is true", ->
        beforeEach ->
          findOptions.set(wholeWord: true, caseSensitive: true)

        it "selects the next occurrence of the selected word skipping any non-word matches", ->
          editor.setText """
            for
            information
            format
            another for
            fork
            a 3rd for is here
          """

          editor.setSelectedBufferRange([[0, 0], [0, 3]])

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 3]]
            [[3, 8], [3, 11]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 3]]
            [[3, 8], [3, 11]]
            [[5, 6], [5, 9]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 3]]
            [[3, 8], [3, 11]]
            [[5, 6], [5, 9]]
          ]

          editor.setText "Testing reallyTesting"
          editor.setCursorBufferPosition([0, 0])

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 7]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 7]]
          ]

      describe "When buffer text is of mixed case", ->
        beforeEach ->
          editor.setText """
            FooBar
            foobar
            testFooBar
            FooBarTest
            test_foobar
            foobar_test
            FooBar
            foobar
          """

        describe "When findOptions.wholeWord is true and findOptions.caseSensitive is true", ->
          it "does not select partial words or wrong case", ->
            findOptions.set(wholeWord: true, caseSensitive: true)

            editor.setSelectedBufferRange([[0, 0], [0, 6]]) #First FooBar
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            expect(editor.getSelectedBufferRanges()).toEqual [
              [[0, 0], [0, 6]]  #First FooBar
              [[6, 0], [6, 6]]  #Second FooBar
            ]

            editor.setSelectedBufferRange([[1, 0], [1, 6]]) #First foobar
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            expect(editor.getSelectedBufferRanges()).toEqual [
              [[1, 0], [1, 6]]  #First foobar
              [[7, 0], [7, 6]]  #Second foobar
            ]

        describe "When findOptions.wholeWord is true and findOptions.caseSensitive is false", ->
          it "does not select partial words but allows case insensitive match", ->
            findOptions.set(wholeWord: true, caseSensitive: false)

            editor.setSelectedBufferRange([[0, 0], [0, 6]]) #First FooBar
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'

            expect(editor.getSelectedBufferRanges()).toEqual [
              [[0, 0], [0, 6]] #First FooBar
              [[1, 0], [1, 6]] #First foobar
              [[6, 0], [6, 6]] #Second FooBar
              [[7, 0], [7, 6]] #Second foobar
            ]

        describe "When findOptions.wholeWord is false and findOptions.caseSensitive is true", ->
          it "selects partial words but require case sensitive match", ->
            findOptions.set(wholeWord: false, caseSensitive: true)

            editor.setSelectedBufferRange([[0, 0], [0, 6]]) #First FooBar
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'

            expect(editor.getSelectedBufferRanges()).toEqual [
              [[0, 0], [0, 6]]  #First FooBar
              [[2, 4], [2, 10]] #testFooBar
              [[3, 0], [3, 6]]  #FooBarTest
              [[6, 0], [6, 6]]  #Second FooBar
            ]

        describe "When findOptions.wholeWord is false and findOptions.caseSensitive is false", ->
          it "selects case insensitive partial words", ->
            findOptions.set(wholeWord: false, caseSensitive: false)

            editor.setSelectedBufferRange([[0, 0], [0, 6]]) #First FooBar
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'
            atom.commands.dispatch editorElement, 'find-and-replace:select-next'

            expect(editor.getSelectedBufferRanges()).toEqual [
              [[0, 0], [0, 6]]  #First FooBar
              [[1, 0], [1, 6]]  #First foobar
              [[2, 4], [2, 10]] #testFooBar
              [[3, 0], [3, 6]]  #FooBarTest
              [[4, 5], [4, 11]] #test_foobar
              [[5, 0], [5, 6]]  #foobar_test
              [[6, 0], [6, 6]]  #Second FooBar
              [[7, 0], [7, 6]]  #Second foobar
            ]

    describe "when part of a word is selected", ->
      describe "when findOptions.wholeWord is false", ->
        beforeEach ->
          findOptions.set(wholeWord: false, caseSensitive: true)

        it "selects the next occurrence of the selected text", ->
          editor.setText """
            for
            information
            format
            another for
            fork
            a 3rd for is here
          """

          editor.setSelectedBufferRange([[1, 2], [1, 5]])

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[1, 2], [1, 5]]
            [[2, 0], [2, 3]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[1, 2], [1, 5]]
            [[2, 0], [2, 3]]
            [[3, 8], [3, 11]]
          ]

      describe "when findOptions.wholeWord is true", ->
        beforeEach ->
          findOptions.set(wholeWord: true, caseSensitive: true)

        it "selects the next occurrence of the selected text", ->
          editor.setText """
            for
            information
            format
            another for
            fork
            a 3rd for is here
          """

          editor.setSelectedBufferRange([[1, 2], [1, 5]])

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[1, 2], [1, 5]]
            [[2, 0], [2, 3]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[1, 2], [1, 5]]
            [[2, 0], [2, 3]]
            [[3, 8], [3, 11]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[1, 2], [1, 5]]
            [[2, 0], [2, 3]]
            [[3, 8], [3, 11]]
            [[4, 0], [4, 3]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[1, 2], [1, 5]]
            [[2, 0], [2, 3]]
            [[3, 8], [3, 11]]
            [[4, 0], [4, 3]]
            [[5, 6], [5, 9]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-next'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[1, 2], [1, 5]]
            [[2, 0], [2, 3]]
            [[3, 8], [3, 11]]
            [[4, 0], [4, 3]]
            [[5, 6], [5, 9]]
            [[0, 0], [0, 3]]
          ]

    describe "when a non-word is selected", ->
      it "selects the next occurrence of the selected text", ->
        editor.setText """
          <!
          <a
        """
        editor.setSelectedBufferRange([[0, 0], [0, 1]])
        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 1]]
          [[1, 0], [1, 1]]
        ]

    describe "when the word is at a line boundary", ->
      it "does not select the newlines", ->
        editor.setText """
          a

          a
        """

        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 1]]
        ]

        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 1]]
          [[2, 0], [2, 1]]
        ]

        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 1]]
          [[2, 0], [2, 1]]
        ]

  describe "find-and-replace:select-all", ->
    describe "when there is no selection", ->
      describe "when findOptions.wholeWord is false", ->
        beforeEach ->
          findOptions.set(wholeWord: false, caseSensitive: true)

        it "find and selects all occurrences of the word under the cursor", ->
          editor.setText """
            for
            information
            format
            another for
            fork
            a 3rd for is here
          """

          atom.commands.dispatch editorElement, 'find-and-replace:select-all'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 3]]
            [[1, 2], [1, 5]]
            [[2, 0], [2, 3]]
            [[3, 8], [3, 11]]
            [[4, 0], [4, 3]]
            [[5, 6], [5, 9]]
          ]

      describe "when findOptions.wholeWord is true", ->
        beforeEach ->
          findOptions.set(wholeWord: true, caseSensitive: true)

        it "find and selects all occurrences of the word under the cursor", ->
          editor.setText """
            for
            information
            format
            another for
            fork
            a 3rd for is here
          """

          atom.commands.dispatch editorElement, 'find-and-replace:select-all'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 3]]
            [[3, 8], [3, 11]]
            [[5, 6], [5, 9]]
          ]

          atom.commands.dispatch editorElement, 'find-and-replace:select-all'
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[0, 0], [0, 3]]
            [[3, 8], [3, 11]]
            [[5, 6], [5, 9]]
          ]

    describe "when a word is selected", ->
      it "find and selects all occurrences", ->
        findOptions.set(wholeWord: true, caseSensitive: true)

        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[3, 8], [3, 11]])

        atom.commands.dispatch editorElement, 'find-and-replace:select-all'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[3, 8], [3, 11]]
          [[0, 0], [0, 3]]
          [[5, 6], [5, 9]]
        ]

        atom.commands.dispatch editorElement, 'find-and-replace:select-all'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[3, 8], [3, 11]]
          [[0, 0], [0, 3]]
          [[5, 6], [5, 9]]
        ]

    describe "when a non-word is selected", ->
      it "selects the next occurrence of the selected text", ->
        editor.setText """
          <!
          <a
        """
        editor.setSelectedBufferRange([[0, 0], [0, 1]])
        atom.commands.dispatch editorElement, 'find-and-replace:select-all'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 1]]
          [[1, 0], [1, 1]]
        ]

  describe "find-and-replace:select-undo", ->
    describe "when there is no selection", ->
      it "does nothing", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        atom.commands.dispatch editorElement, 'find-and-replace:select-undo'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 0]]
        ]

    describe "when a word is selected", ->
      it "unselects current word", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[3, 8], [3, 11]])

        atom.commands.dispatch editorElement, 'find-and-replace:select-undo'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[3, 11], [3, 11]]
        ]

    describe "when two words are selected", ->
      it "unselects words in order", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[3, 8], [3, 11]])

        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        atom.commands.dispatch editorElement, 'find-and-replace:select-undo'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[3, 8], [3, 11]]
        ]

        atom.commands.dispatch editorElement, 'find-and-replace:select-undo'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[3, 11], [3, 11]]
        ]

    describe "when three words are selected", ->
      beforeEach ->
        findOptions.set(wholeWord: true, caseSensitive: true)

      it "unselects words in order", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[0, 0], [0, 3]])

        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        atom.commands.dispatch editorElement, 'find-and-replace:select-undo'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[3, 8], [3, 11]]
        ]

        atom.commands.dispatch editorElement, 'find-and-replace:select-undo'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
        ]

    describe "when starting at the bottom word", ->
      beforeEach ->
        findOptions.set(wholeWord: true, caseSensitive: true)

      it "unselects words in order", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[5, 6], [5, 9]])
        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[5, 6], [5, 9]]
          [[0, 0], [0, 3]]
        ]
        atom.commands.dispatch editorElement, 'find-and-replace:select-undo'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[5, 6], [5, 9]]
        ]

      it "doesn't stack previously selected", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[5, 6], [5, 9]])
        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        atom.commands.dispatch editorElement, 'find-and-replace:select-undo'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[5, 6], [5, 9]]
          [[0, 0], [0, 3]]
        ]

  describe "find-and-replace:select-skip", ->
    beforeEach ->
      findOptions.set(wholeWord: true, caseSensitive: true)

    describe "when there is no selection", ->
      it "does nothing", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        atom.commands.dispatch editorElement, 'find-and-replace:select-skip'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 0]]
        ]

    describe "when a word is selected", ->
      it "unselects current word and selects next match", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[3, 8], [3, 11]])

        atom.commands.dispatch editorElement, 'find-and-replace:select-skip'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[5, 6], [5, 9]]
        ]

    describe "when two words are selected", ->
      it "unselects second word and selects next match", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[0, 0], [0, 3]])

        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        atom.commands.dispatch editorElement, 'find-and-replace:select-skip'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
          [[5, 6], [5, 9]]
        ]

        atom.commands.dispatch editorElement, 'find-and-replace:select-skip'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 0], [0, 3]]
        ]

    describe "when starting at the bottom word", ->
      it "unselects second word and selects next match", ->
        editor.setText """
          for
          information
          format
          another for
          fork
          a 3rd for is here
        """

        editor.setSelectedBufferRange([[5, 6], [5, 9]])
        atom.commands.dispatch editorElement, 'find-and-replace:select-next'
        atom.commands.dispatch editorElement, 'find-and-replace:select-skip'
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[5, 6], [5, 9]]
          [[3, 8], [3, 11]]
        ]
