_ = require 'underscore-plus'
{Range} = require 'atom'

# Find and select the next occurrence of the currently selected text.
#
# The word under the cursor will be selected if the selection is empty.
module.exports =
class SelectNext
  selectionRanges: null

  constructor: (@editor) ->
    @selectionRanges = []
    @noofSelections = 0

  findAndSelectNext: ->
    if @editor.getLastSelection().isEmpty()
      @selectWord()
    else
      if(@editor.getSelectedBufferRanges().length isnt @noofSelections)
        @noofSelections = 1
        @resetSelectedWord()
      @selectNextOccurrence()

  findAndSelectAll: ->
    if @editor.getLastSelection().isEmpty()
      @selectWord()
    if(@editor.getSelectedBufferRanges().length < @noofSelections)
      @resetSelectedWord()
    @noofSelections = 0
    @selectAllOccurrences()

  undoLastSelection: ->
    @updateSavedSelections()

    return if @selectionRanges.length < 1

    if @selectionRanges.length > 1
      @selectionRanges.pop()
      @editor.setSelectedBufferRanges @selectionRanges
    else
      @editor.clearSelections()

    @editor.scrollToCursorPosition()

  skipCurrentSelection: ->
    @updateSavedSelections()

    return if @selectionRanges.length < 1

    if @selectionRanges.length > 1
      lastSelection = @selectionRanges.pop()
      @editor.setSelectedBufferRanges @selectionRanges
      @selectNextOccurrence(start: lastSelection.end)
    else
      @selectNextOccurrence()
      @selectionRanges.shift()
      return if @selectionRanges.length < 1
      @editor.setSelectedBufferRanges @selectionRanges

  selectWord: ->
    @editor.selectWordsContainingCursors()
    @noofSelections = 1
    @wordUnderCursorIsSelected = true
    @wordSelected = @isWordSelected(@editor.getLastSelection())

  selectAllOccurrences: ->
    range = [[0, 0], @editor.getEofBufferPosition()]
    @scanForNextOccurrence range, ({range, stop}) =>
      @addSelection(range)
      @noofSelections++

  selectNextOccurrence: (options={}) ->
    startingRange = options.start ? @editor.getSelectedBufferRange().end
    range = @findNextOccurrence([startingRange, @editor.getEofBufferPosition()])
    range ?= @findNextOccurrence([[0, 0], @editor.getSelections()[0].getBufferRange().start])
    if range?
      @addSelection(range)
      @noofSelections++
    else
      @resetSelectedWord()

  resetSelectedWord: ->
    @wordSelected = null
    @wordUnderCursorIsSelected = false

  findNextOccurrence: (scanRange) ->
    foundRange = null
    @scanForNextOccurrence scanRange, ({range, stop}) ->
      foundRange = range
      stop()
    foundRange

  addSelection: (range) ->
    selection = @editor.addSelectionForBufferRange(range)
    @updateSavedSelections selection
    disposable = selection.onDidDestroy =>
      @wordSelected = null
      disposable.dispose()

  scanForNextOccurrence: (range, callback) ->
    selection = @editor.getLastSelection()
    text = _.escapeRegExp(selection.getText())

    @wordSelected ?= @isWordSelected(selection)
    if @wordSelected
      nonWordCharacters = atom.config.get('editor.nonWordCharacters')
      text = "(^|[ \t#{_.escapeRegExp(nonWordCharacters)}]+)#{text}(?=$|[\\s#{_.escapeRegExp(nonWordCharacters)}]+)"

    @editor.scanInBufferRange new RegExp(text, 'g'), range, (result) ->
      if prefix = result.match[1]
        result.range = result.range.translate([0, prefix.length], [0, 0])
      callback(result)

  updateSavedSelections: (selection=null) ->
    selections = @editor.getSelections()
    @selectionRanges = [] if selections.length < 3
    if @selectionRanges.length is 0
      @selectionRanges.push s.getBufferRange() for s in selections
    else if selection
      selectionRange = selection.getBufferRange()
      return if @selectionRanges.some (existingRange) -> existingRange.isEqual(selectionRange)
      @selectionRanges.push selectionRange

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
      containsOnlyWordCharacters = not @isNonWordCharacter(selection.getText())

      nonWordCharacterToTheLeft and nonWordCharacterToTheRight and containsOnlyWordCharacters and @wordUnderCursorIsSelected
    else
      false
