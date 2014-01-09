{_} = require 'atom'

# Find and select the next occurrence of the currently selected text.
#
# The word under the cursor will be selected if the selection is empty.
module.exports =
class SelectNext
  constructor: (@editor) ->

  findAndSelectNext: ->
    selection = @editor.getSelection()
    if selection.isEmpty()
      @selectWord()
    else
      @selectNextOccurrence()

  selectWord: ->
    @editor.selectWord()

  selectNextOccurrence: ->
    selection = @editor.getSelection()
    range = [selection.getBufferRange().end, @editor.getEofBufferPosition()]
    text = _.escapeRegExp(selection.getText())
    @editor.scanInBufferRange new RegExp(text), range, ({range, stop}) =>
      @editor.addSelectionForBufferRange(range)
      stop()
