_ = require 'underscore-plus'
{Range} = require 'atom'

# Find and select the next occurrence of the currently selected text.
#
# The word under the cursor will be selected if the selection is empty.
module.exports =
class SelectNext
  constructor: (@editor) ->

  findAndSelectNext: ->
    if @editor.getSelection().isEmpty()
      @selectWord()
    else
      @selectNextOccurrence()

  findAndSelectAll: ->
    @selectWord() if @editor.getSelection().isEmpty()
    @selectAllOccurrences()

  selectWord: ->
    @editor.selectWord()
    @wordSelected = @isWordSelected(@editor.getSelection())

  selectAllOccurrences: ->
    range = [[0, 0], @editor.getEofBufferPosition()]
    @scanForNextOccurrence range, ({range, stop}) =>
      @addSelection(range)

  selectNextOccurrence: ->
    found = false
    find = (range) =>
      @scanForNextOccurrence range, ({range, stop}) =>
        @addSelection(range)
        found = true
        stop()
    find [@editor.getSelection().getBufferRange().end, @editor.getEofBufferPosition()]
    unless found
      find [[0,0], @editor.getSelection().getBufferRange().start]

  addSelection: (range) ->
    selection = @editor.addSelectionForBufferRange(range)
    selection.once 'destroyed', => @wordSelected = null

  scanForNextOccurrence: (range, callback) ->
    selection = @editor.getSelection()
    text = _.escapeRegExp(selection.getText())

    @wordSelected ?= @isWordSelected(selection)
    if @wordSelected
      nonWordCharacters = atom.config.get('editor.nonWordCharacters')
      text = "(^|[ \t#{_.escapeRegExp(nonWordCharacters)}]+)#{text}(?=$|[\\s#{_.escapeRegExp(nonWordCharacters)}]+)"

    @editor.scanInBufferRange new RegExp(text, 'g'), range, (result) ->
      if prefix = result.match[1]
        result.range = result.range.translate([0, prefix.length], [0, 0])
      callback(result)

  isNonWordCharacter: (character) ->
    nonWordCharacters = atom.config.get('editor.nonWordCharacters')
    new RegExp("[ \t#{_.escapeRegExp(nonWordCharacters)}]").test(character)

  isNonWordCharacterToTheLeft: (selection) ->
    selectionStart = selection.getBufferRange().start
    range = Range.fromPointWithDelta(selectionStart, 0, -1)
    @isNonWordCharacter(@editor.getTextInBufferRange(range))

  isNonWordCharacterToTheRight: (selection) ->
    selectionEnd = selection.getBufferRange().end
    range = Range.fromPointWithDelta(selectionEnd, 0, 1)
    @isNonWordCharacter(@editor.getTextInBufferRange(range))

  isWordSelected: (selection) ->
    if selection.getBufferRange().isSingleLine()
      selectionRange = selection.getBufferRange()
      lineRange = @editor.bufferRangeForBufferRow(selectionRange.start.row)
      nonWordCharacterToTheLeft = _.isEqual(selectionRange.start, lineRange.start) or
        @isNonWordCharacterToTheLeft(selection)
      nonWordCharacterToTheRight = _.isEqual(selectionRange.end, lineRange.end) or
        @isNonWordCharacterToTheRight(selection)

      nonWordCharacterToTheLeft and nonWordCharacterToTheRight
    else
      false
