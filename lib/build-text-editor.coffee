TextEditor = null
module.exports = ->
  if atom.workspace.buildTextEditor?
    atom.workspace.buildTextEditor(params)
  else
    TextEditor ?= require("atom").TextEditor
    new TextEditor(params)
