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

const buildResultsTextEditor = (resultsModel) => {
  const textEditorRegistry = atom.workspace.textEditorRegistry;
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
    console.log(resultsModel.results);
    editor.setGrammar(findGrammar);
    let newText = '';
    resultsModel.getPaths().forEach((filePath) => {
      console.log(filePath);
      console.log(resultsModel.results[filePath]);
      const result = resultsModel.results[filePath];
      newText += '\x1C' + filePath + ':\x1C\n';
      result.matches.forEach((match) => {
        const twoLeadingLines = match.leadingContextLines.slice(
          Math.max(match.leadingContextLines.length - 2, 0),
          match.leadingContextLines.length
        );
        for (let i = 0; i < twoLeadingLines.length; i++) {
          newText += '\x1B' + (match.range[0][0] - twoLeadingLines.length + i) + '\x1B  ' + twoLeadingLines[i] + '\n';
        };
        newText += '\x1B' + match.range[0][0] + ':\x1B ' + match.lineText + '\n';
        const twoTrailingLines = match.trailingContextLines.slice(
          0,
          Math.min(match.trailingContextLines.length, 2)
        );
        for (let i = 0; i < twoTrailingLines.length; i++) {
          newText += '\x1B' + (match.range[0][0] - twoTrailingLines.length + i) + '\x1B  ' + twoTrailingLines[i] + '\n';
        };
      });
      newText += '\n'
    });
    editor.setText(newText);
  }));
  editor.onDidDestroy(() => subscriptions.dispose());
  editorView = atom.views.getView(editor);
  editorView.destroy = () => console.log('destroy');
  editor.getTitle = () => 'Project Find Results';
  editor.getIconName = () => 'search';
  return editor;
}

module.exports = {
  buildResultsTextEditor
}
