_ = require 'underscore'

HISTORY_MAX = 25

module.exports =
class History
  constructor: (@editor, @items=[]) ->
    @index = @items.length

    @editor.on 'core:confirm', => @addToHistory(@editor.getText())
    @editor.on 'core:move-up', => @previous()
    @editor.on 'core:move-down', => @next()

  serialize: ->
    @items[-HISTORY_MAX..]

  previous: ->
    if @atLastItem() and @editor.getText() != @getLast()
      @scratch = @editor.getText()
    else if @index > 0
      @index--

    @editor.setText @items[@index]

  next: ->
    if @index < @items.length - 1
      @index++
      item = @items[@index]
    else if @scratch
      item = @scratch
    else
      item = ""

    @editor.setText item

  getLast: ->
    _.last(@items)

  atLastItem: ->
    @index == @items.length - 1

  addToHistory: (pattern) ->
    @scratch = null
    @items.push(pattern)
    @index = @items.length - 1

# pattern = @unsearchedPattern if @unsearchedPattern and historyIndex == history.length and @unsearchedPattern != _.last(history)
# storeUnsearchedPattern: ->
#   if @findEditor.getText() != @searchModel.currentHistoryPattern()
#     @searchModel.moveToEndOfHistory()
#     @unsearchedPattern = @findEditor.getText()
