const {CompositeDisposable} = require('atom');

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
    let newText = '';
    resultsModel.getPaths().forEach((filePath) => {
      console.log(filePath);
      console.log(resultsModel.results[filePath]);
      const result = resultsModel.results[filePath];
      newText += filePath + '\n';
      result.matches.forEach((match) => {
        match.leadingContextLines.forEach((leadingContextLine) => {
          newText += leadingContextLine + '\n';
        });
        newText += match.lineText + '\n';
        match.trailingContextLines.forEach((trailingContextLine) => {
          newText += match.lineText + '\n';
        });
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
