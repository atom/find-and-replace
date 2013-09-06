_ = require 'underscore'

HISTORY_MAX = 25

module.exports =
class History
  constructor: (@editor, @items=[]) ->
    @index = @items.length

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

  store: ->
    text = @editor.getText()
    @scratch = null
    @items.push(text)
    @index = @items.length - 1

  serialize: ->
    @items
