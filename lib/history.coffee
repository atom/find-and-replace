_ = require 'underscore'

HISTORY_MAX = 25

module.exports =
class History
  constructor: (@miniEditor, @items=[]) ->
    @index = @items.length

    @miniEditor.on 'core:move-up', => @previous()
    @miniEditor.on 'core:move-down', => @next()

  serialize: ->
    @items[-HISTORY_MAX..]

  previous: ->
    if @items.length == 0 or (@atLastItem() and @miniEditor.getText() != @getLast())
      @scratch = @miniEditor.getText()
    else if @index > 0
      @index--

    @miniEditor.setText @items[@index] ? ''

  next: ->
    if @index < @items.length - 1
      @index++
      item = @items[@index]
    else if @scratch
      item = @scratch
    else
      item = ''

    @miniEditor.setText item

  getLast: ->
    _.last(@items)

  atLastItem: ->
    @index == @items.length - 1

  store: ->
    text = @miniEditor.getText()
    return if not text
    @scratch = null
    @items.push(text)
    @index = @items.length - 1

  serialize: ->
    @items
