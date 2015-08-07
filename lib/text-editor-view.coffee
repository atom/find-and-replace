{View} = require 'atom-space-pen-views'

module.exports =
class TextEditorView extends View
  # The constructor for setting up an `TextEditorView` instance.
  constructor: (params={}) ->
    {mini, placeholderText, attributes, editor} = params
    attributes ?= {}
    attributes['mini'] = mini if mini?
    attributes['placeholder-text'] = placeholderText if placeholderText?

    if editor?
      @element = atom.views.getView(editor)
    else
      @element = document.createElement('atom-text-editor')

    @element.setAttribute(name, value) for name, value of attributes
    if @element.__spacePenView?
      @element.__spacePenView = this
      @element.__allowViewAccess = true

    super

    @setModel(@element.getModel())

  setModel: (@model) ->

  # Public: Get the underlying editor model for this view.
  #
  # Returns a `TextEditor`
  getModel: -> @model

  # Public: Get the text of the editor.
  #
  # Returns a `String`.
  getText: ->
    @model.getText()

  # Public: Set the text of the editor as a `String`.
  setText: (text) ->
    @model.setText(text)

  # Public: Determine whether the editor is or contains the active element.
  #
  # Returns a `Boolean`.
  hasFocus: ->
    @element.hasFocus()
