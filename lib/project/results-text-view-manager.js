const { Range, CompositeDisposable } = require('atom');

const findGrammar = atom.grammars.createGrammar('find', {
  'scopeName': 'find.results',
  'name': 'Find Results',
  'fileTypes': [
    'results'
	],
  'patterns': [
    {
      'begin': '\x1B',
      'end': '\x1B',
      'name': 'find-results-main-line-number'
    },
    {
      'begin': '\x1D',
      'end': '\x1D',
      'name': 'find-results-context-line-number'
    },
    {
      'begin': '\x1C',
      'end': '\x1C',
      'name': 'find-results-path'
    }
  ]
});

const LEFT_PAD = '     ';
const pad = (str) => {
  str = str.toString();
  return LEFT_PAD.substring(0, LEFT_PAD.length - str.length) + str;
}

module.exports =
class ResultsTextViewManager {
  constructor(model) {
    this.model = model;
    this.model.setActive(true);
    this.editor = null;
    this.cursorLine = null;
    this.lineToFilesMap = {};
    this.isLoading = false;
    // this.searchErrors = [];
    // this.searchResults = null;
    // this.searchingIsSlow = false;
    // this.numberOfPathsSearched = 0;
    // this.searchContextLineCountBefore = atom.config.get('find-and-replace.searchContextLineCountBefore') || 0;
    // this.searchContextLineCountAfter = atom.config.get('find-and-replace.searchContextLineCountAfter') || 0;

    this.subscriptions = new CompositeDisposable(
      // this.model.onDidStartSearching(this.onSearch.bind(this)),
      this.model.onDidFinishSearching(this.onFinishedSearching.bind(this))
      // this.model.onDidClear(this.onCleared.bind(this)),
      // this.model.onDidClearReplacementState(this.onReplacementStateCleared.bind(this)),
      // this.model.onDidSearchPaths(this.onPathsSearched.bind(this)),
      // this.model.onDidErrorForPath(error => this.appendError(error.message)),
      // atom.config.observe('find-and-replace.searchContextLineCountBefore', this.searchContextLineCountChanged.bind(this)),
      // atom.config.observe('find-and-replace.searchContextLineCountAfter', this.searchContextLineCountChanged.bind(this))
    );
  }

  onDoubleClick() {
    if (this.cursorLine && this.lineToFilesMap[this.cursorLine]) {
      atom.workspace
        .open(this.lineToFilesMap[this.cursorLine].filePath)
        // , {
          // pending,
          // split: reverseDirections[atom.config.get('find-and-replace.projectSearchResultsPaneSplitDirection')]
        // })
        .then(editor => {
          editor.setSelectedBufferRange(this.lineToFilesMap[this.cursorLine].range, {autoscroll: true})
        });
    }
  }

  onCursorPositionChanged(e) {
    this.cursorLine = e.newBufferPosition && e.newBufferPosition.row;
  };

  onDestroyEditor() {
    this.editorSubscriptions.dispose();
    this.editor = null;
  }

  // onPathsSearched({result}) {
  //   this.editor.insertText result.filePath
  //   this.editor.insertNewline({autoIndentNewline: false})
  //   result.matches.forEach (match) ->
  //     match.leadingContextLines.forEach (leadingContextLine) ->
  //       this.editor.insertText leadingContextLine
  //       this.editor.insertNewline({autoIndentNewline: false})
  //     this.editor.insertText match.lineText
  //     this.editor.insertNewline({autoIndentNewline: false})
  //     match.trailingContextLines.forEach (trailingContextLine) ->
  //       this.editor.insertText trailingContextLine
  //       this.editor.insertNewline({autoIndentNewline: false})
  //   this.editor.insertNewline({autoIndentNewline: false})
  // }

  onFinishedSearching(results) {
    this.editor.setGrammar(findGrammar);
    let resultsLines = [];
    this.model.getPaths().forEach((filePath) => {
      const result = this.model.results[filePath];
      resultsLines.push('\x1C' + filePath + ':\x1C');
      let lastLineNumber = null;
      result.matches.forEach((match) => {
        const mainLineNumber = Range.fromObject(match.range).start.row + 1;

        // Ignore more results on the same line
        if (mainLineNumber === lastLineNumber) {
          return;
        }

        // Remove previous trailing lines that overlap
        const linesBetween = mainLineNumber - lastLineNumber - 1;
        if (lastLineNumber) {
          if (linesBetween <= 4) {
            // Remove dots separator
            resultsLines.pop();
          }
          if (linesBetween === 3) {
            // Remove one trailing line
            resultsLines.pop();
          } else if (linesBetween < 3) {
            // Remove two trailing lines
            resultsLines.pop();
            resultsLines.pop();
          }
        }
        lastLineNumber = mainLineNumber;

        // Add new leading lines
        const twoLeadingLines = match.leadingContextLines.slice(
          Math.max(match.leadingContextLines.length - Math.min(linesBetween, 2), 0),
          match.leadingContextLines.length
        );
        for (let i = 0; i < twoLeadingLines.length; i++) {
          const lineNumber = mainLineNumber - twoLeadingLines.length + i;
          resultsLines.push('\x1D' + pad(lineNumber) + '\x1D  ' + twoLeadingLines[i]);
        };

        // Add main line
        resultsLines.push('\x1B' + pad(mainLineNumber) + ':\x1B ' + match.lineText);
        // Store the file path and range info for retrieving it on double click
        this.lineToFilesMap[resultsLines.length - 1] = {
          range: match.range,
          filePath: filePath
        }

        // Add trailing lines
        const twoTrailingLines = match.trailingContextLines.slice(
          0,
          Math.min(match.trailingContextLines.length, 2)
        );
        for (let i = 0; i < twoTrailingLines.length; i++) {
          const lineNumber = mainLineNumber + i + 1;
          resultsLines.push('\x1D' + pad(lineNumber) + '\x1D  ' + twoTrailingLines[i]);
        };

        // Separator
        resultsLines.push(pad('..'));
      });
      // Pop last separator
      resultsLines.pop();
      resultsLines.push('');
    });
    this.editor.setText(resultsLines.join('\n'));
  }

  getResultsTextEditor() {
    if (!this.editor) {
      this.cursorLine = null;
      this.lineToFilesMap = {};
      const textEditorRegistry = atom.workspace.textEditorRegistry;
      const editor = textEditorRegistry.build();
      editor.getTitle = () => 'Project Find Results';
      editor.getIconName = () => 'search';
      editor.shouldPromptToSave = () => false;
      editor.element.addEventListener('dblclick', this.onDoubleClick.bind(this));
      this.editorSubscriptions = new CompositeDisposable(
        editor.onDidChangeCursorPosition(this.onCursorPositionChanged.bind(this)),
        editor.onDidDestroy(this.onDestroyEditor.bind(this))
      );
      this.editor = editor;
    }
    // Start a search in case there are new results
    this.onFinishedSearching(this.model.getResultsSummary());
    return this.editor;
  }
}
