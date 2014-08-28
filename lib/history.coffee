_ = require 'underscore-plus'
{Emitter} = require 'emissary'

HISTORY_MAX = 25

class HistoryData
  Emitter.includeInto(this)

  constructor: (@items=[]) ->
    @length = @items.length

  serialize: ->
    @items[-HISTORY_MAX..]

  getLast: ->
    _.last(@items)

  getAtIndex: (index) ->
    @items[index]

  add: (text) ->
    @items.push(text)
    @length = @items.length
    @emit 'added', text

class History
  constructor: (@miniEditor, @items) ->
    @index = @items.length
    @miniEditor.on 'core:move-up', => @previous()
    @miniEditor.on 'core:move-down', => @next()

    @items.on 'added', (text) =>
      @miniEditor.setText(text) if text isnt @miniEditor.getText()

  previous: ->
    if @items.length == 0 or (@atLastItem() and @miniEditor.getText() != @items.getLast())
      @scratch = @miniEditor.getText()
    else if @index > 0
      @index--

    @miniEditor.setText @items.getAtIndex(@index) ? ''

  next: ->
    if @index < @items.length - 1
      @index++
      item = @items.getAtIndex(@index)
    else if @scratch
      item = @scratch
    else
      item = ''

    @miniEditor.setText item

  atLastItem: ->
    @index == @items.length - 1

  store: ->
    text = @miniEditor.getText()
    return if not text or text is @items.getLast()
    @scratch = null
    @items.add(text)
    @index = @items.length - 1

module.exports = {History, HistoryData}
