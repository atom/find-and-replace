const { Range, CompositeDisposable } = require('atom');
const {sanitizePattern} = require('./util');

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
    this.searchContextLineCountBefore = atom.config.get('find-and-replace.searchContextLineCountBefore');
    this.searchContextLineCountAfter = atom.config.get('find-and-replace.searchContextLineCountAfter');
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
    this.model.setActive(false);
    this.subscriptions.dispose();
    this.editor = null;
  }

  onSearch() {
    this.editor.setText('Searching...');
  }

  onFinishedSearching(results) {
    if (this.model.getPaths().length === 0) {
      this.editor.setText(`No results found for ${sanitizePattern(results.findPattern)}.`);
      return;
    }
    this.editor.setGrammar(findGrammar);
    const searchContextLineCountTotal = this.searchContextLineCountBefore + this.searchContextLineCountAfter;
    let resultsLines = [];
    this.model.getPaths().forEach((filePath) => {
      const result = this.model.results[filePath];
      resultsLines.push('\x1C' + filePath + ':\x1C');
      let lastLineNumber = null;
      for (let i = 0; i < result.matches.length; i++) {
        const match = result.matches[i];
        const mainLineNumber = Range.fromObject(match.range).start.row + 1;

        // Add leading lines
        const linesToPrevMatch = mainLineNumber - lastLineNumber - 1;
        const leadingLines = linesToPrevMatch < match.leadingContextLines.length ?
          match.leadingContextLines.slice(
            match.leadingContextLines.length - linesToPrevMatch,
            match.leadingContextLines.length
          )
          : match.leadingContextLines;
        for (let i = 0; i < leadingLines.length; i++) {
          const lineNumber = mainLineNumber - leadingLines.length + i;
          resultsLines.push('\x1D' + pad(lineNumber) + '\x1D  ' + leadingLines[i]);
        };

        // Avoid adding the same line multiple times
        if (mainLineNumber !== lastLineNumber) {
          // Add main line
          resultsLines.push('\x1B' + pad(mainLineNumber) + ':\x1B ' + match.lineText);
        }

        // Store the file path and range info for retrieving it on double click
        this.lineToFilesMap[resultsLines.length - 1] = {
          range: match.range,
          filePath: filePath
        }

        // Check if there is overlap with the next match
        // If there is, adjust the number of trailing lines to be added
        let linesOverlap = false;
        let numberOfTrailingLines = match.trailingContextLines.length;
        if (i < result.matches.length - 1) {
          const nextMatch = result.matches[i + 1];
          const nextLineNumber = Range.fromObject(nextMatch.range).start.row + 1;
          const linesToNextMatch = nextLineNumber - mainLineNumber - 1;
          if (linesToNextMatch <= searchContextLineCountTotal) {
            linesOverlap = true;
            if (linesToNextMatch - this.searchContextLineCountBefore < this.searchContextLineCountAfter) {
              numberOfTrailingLines = Math.max(
                linesToNextMatch - this.searchContextLineCountBefore,
                0
              );
            }
          }
        }
        // Add trailing lines
        for (let j = 0; j < numberOfTrailingLines; j++) {
          const lineNumber = mainLineNumber + j + 1;
          resultsLines.push('\x1D' + pad(lineNumber) + '\x1D  ' + match.trailingContextLines[j]);
        };

        // Separator
        if (!linesOverlap) {
          resultsLines.push(pad('.'.repeat((mainLineNumber + numberOfTrailingLines).toString().length)));
        }

        lastLineNumber = mainLineNumber;
      };
      // Pop last separator
      resultsLines.pop();
      resultsLines.push('');
    });
    this.editor.setText(resultsLines.join('\n'));
    this.editor.setCursorBufferPosition([0, 0]);
  }

  onSearchContextLineCountChanged() {
    this.searchContextLineCountBefore = atom.config.get('find-and-replace.searchContextLineCountBefore');
    this.searchContextLineCountAfter = atom.config.get('find-and-replace.searchContextLineCountAfter');
  }

  getResultsTextEditor() {
    if (!this.editor) {
      this.cursorLine = null;
      this.lineToFilesMap = {};
      const textEditorRegistry = atom.workspace.textEditorRegistry;
      const editor = textEditorRegistry.build(({autoHeight: false}));
      editor.getTitle = () => 'Project Find Results';
      editor.getIconName = () => 'search';
      editor.shouldPromptToSave = () => false;
      editor.element.addEventListener('dblclick', this.onDoubleClick.bind(this));
      this.subscriptions = new CompositeDisposable(
        editor.onDidChangeCursorPosition(this.onCursorPositionChanged.bind(this)),
        editor.onDidDestroy(this.onDestroyEditor.bind(this)),
        this.model.onDidStartSearching(this.onSearch.bind(this)),
        this.model.onDidFinishSearching(this.onFinishedSearching.bind(this)),
        atom.config.observe('find-and-replace.searchContextLineCountBefore', this.onSearchContextLineCountChanged.bind(this)),
        atom.config.observe('find-and-replace.searchContextLineCountAfter', this.onSearchContextLineCountChanged.bind(this))
      );

      this.editor = editor;
    }
    // Update the editor in case there are already results available
    this.onFinishedSearching(this.model.getResultsSummary());
    return this.editor;
  }
}
