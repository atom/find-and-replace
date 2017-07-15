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
      'name': 'find-results-line-number'
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

let resultsEditor = null;

const buildResultsTextEditor = (resultsModel) => {
  const textEditorRegistry = atom.workspace.textEditorRegistry;
  if (!resultsEditor) {
    const editor = textEditorRegistry.build();
    console.log(editor);
    const subscriptions = new CompositeDisposable();
    subscriptions.add(textEditorRegistry.maintainGrammar(editor));
    subscriptions.add(textEditorRegistry.maintainConfig(editor));
    subscriptions.add(resultsModel.onDidSearchPaths((numberOfPathsSearched) => {
      console.log(numberOfPathsSearched);
      // subscriptions.add @resultsModel.onDidAddResult ({result}) =>
      //   console.log(result)
      //   editor.insertText result.filePath
      //   editor.insertNewline({autoIndentNewline: false})
      //   console.log(result.matches)
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
        console.log('s null');
        result.matches.forEach((match) => {
          const mainLineNumber = match.range[0][0] + 1;
          if (mainLineNumber === lastLineNumber) {
            return;
          }
          console.log('mainLineNumber: ' + mainLineNumber);

          // Remove previous trailing lines that overlap
          const linesBetween = mainLineNumber - lastLineNumber - 1;
          console.log(linesBetween);
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
            resultsLines.push('\x1B' + pad(lineNumber) + '\x1B  ' + twoLeadingLines[i]);
          };

          // Add main line
          resultsLines.push('\x1B' + pad(mainLineNumber) + ':\x1B ' + match.lineText);

          // Add trailing lines
          const twoTrailingLines = match.trailingContextLines.slice(
            0,
            Math.min(match.trailingContextLines.length, 2)
          );
          for (let i = 0; i < twoTrailingLines.length; i++) {
            const lineNumber = match.range[0][0] + 1 + i + 1;
            resultsLines.push('\x1B' + pad(lineNumber) + '\x1B  ' + twoTrailingLines[i]);
          };

          // Separator
          resultsLines.push(pad('..'));
        });
        resultsLines.push('');
      });
      editor.setText(resultsLines.join('\n'));
    }));
    editor.onDidDestroy(() => {
      console.log('destroy');
      subscriptions.dispose();
      resultsEditor = null;
    });
    editorView = atom.views.getView(editor);
    editorView.destroy = () => console.log('destroy');
    editor.getTitle = () => 'Project Find Results';
    editor.getIconName = () => 'search';
    resultsEditor = editor;
  }
  return resultsEditor;
}

module.exports = {
  buildResultsTextEditor
}
