const {CompositeDisposable} = require('atom');

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

let line = null;
let lineFilesMap = {};

const onDoubleClick = (e) => {
  if (lineFilesMap[line]) {
    atom.workspace
      .open(lineFilesMap[line].filePath)
      // , {
        // pending,
        // split: reverseDirections[atom.config.get('find-and-replace.projectSearchResultsPaneSplitDirection')]
      // })
      .then(editor => {
        editor.setSelectedBufferRange(lineFilesMap[line].range, {autoscroll: true})
      });
  }
};

const onCursorPositionChanged = (e) => {
  line = e.newBufferPosition && e.newBufferPosition.row;
};

const LEFT_PAD = '     ';
const pad = (str) => {
  str = str.toString();
  return LEFT_PAD.substring(0, LEFT_PAD.length - str.length) + str;
}

let resultsEditor = null;

const buildResultsTextEditor = (resultsModel) => {
  const textEditorRegistry = atom.workspace.textEditorRegistry;
  if (!resultsEditor) {
    const editor = textEditorRegistry.build();
    editor.getTitle = () => 'Project Find Results';
    editor.getIconName = () => 'search';
    editor.shouldPromptToSave = () => false;
    editor.element.addEventListener('dblclick', onDoubleClick);
    const subscriptions = new CompositeDisposable();
    subscriptions.add(atom.textEditors.add(editor));
    subscriptions.add(editor.onDidChangeCursorPosition(onCursorPositionChanged));
    subscriptions.add(editor.onDidDestroy(() => {
      editor.element.removeEventListener('dblclick', onDoubleClick);
      subscriptions.dispose();
      resultsEditor = null;
    }));
    subscriptions.add(resultsModel.onDidSearchPaths((numberOfPathsSearched) => {
      // subscriptions.add @resultsModel.onDidAddResult ({result}) =>
      //   editor.insertText result.filePath
      //   editor.insertNewline({autoIndentNewline: false})
      //   result.matches.forEach (match) ->
      //     match.leadingContextLines.forEach (leadingContextLine) ->
      //       editor.insertText leadingContextLine
      //       editor.insertNewline({autoIndentNewline: false})
      //     editor.insertText match.lineText
      //     editor.insertNewline({autoIndentNewline: false})
      //     match.trailingContextLines.forEach (trailingContextLine) ->
      //       editor.insertText trailingContextLine
      //       editor.insertNewline({autoIndentNewline: false})
      //   editor.insertNewline({autoIndentNewline: false})
    }));

    subscriptions.add(resultsModel.onDidFinishSearching((results) => {
      editor.setGrammar(findGrammar);
      let resultsLines = [];
      resultsModel.getPaths().forEach((filePath) => {
        const result = resultsModel.results[filePath];
        resultsLines.push('\x1C' + filePath + ':\x1C');
        let lastLineNumber = null;
        result.matches.forEach((match) => {
          const mainLineNumber = match.range[0][0] + 1;
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
            const lineNumber = match.range[0][0] + 1 - twoLeadingLines.length + i;
            resultsLines.push('\x1D' + pad(lineNumber) + '\x1D  ' + twoLeadingLines[i]);
          };

          // Add main line
          resultsLines.push('\x1B' + pad(mainLineNumber) + ':\x1B ' + match.lineText);
          // Store the file path and range info for retrieving it on double click
          lineFilesMap[resultsLines.length - 1] = {
            range: match.range,
            filePath: filePath
          }

          // Add trailing lines
          const twoTrailingLines = match.trailingContextLines.slice(
            0,
            Math.min(match.trailingContextLines.length, 2)
          );
          for (let i = 0; i < twoTrailingLines.length; i++) {
            const lineNumber = match.range[0][0] + 1 + i + 1;
            resultsLines.push('\x1D' + pad(lineNumber) + '\x1D  ' + twoTrailingLines[i]);
          };

          // Separator
          resultsLines.push(pad('..'));
        });
        // Pop last separator
        resultsLines.pop();
        resultsLines.push('');
      });
      editor.setText(resultsLines.join('\n'));
    }));
    resultsEditor = editor;
  }
  return resultsEditor;
}

module.exports = {
  buildResultsTextEditor
}
