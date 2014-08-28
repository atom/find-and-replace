_ = require 'underscore-plus'
{Emitter} = require 'emissary'

HISTORY_MAX = 25

class History
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

# Adds the ability to cycle through history
class HistoryCycler

  # * `miniEditor` an {Editor} instance to attach the cycler to
  # * `history` a {History} object
  constructor: (@miniEditor, @history) ->
    @index = @history.length
    @miniEditor.on 'core:move-up', => @previous()
    @miniEditor.on 'core:move-down', => @next()

    @history.on 'added', (text) =>
      @miniEditor.setText(text) if text isnt @miniEditor.getText()

  previous: ->
    if @history.length == 0 or (@atLastItem() and @miniEditor.getText() != @history.getLast())
      @scratch = @miniEditor.getText()
    else if @index > 0
      @index--

    @miniEditor.setText @history.getAtIndex(@index) ? ''

  next: ->
    if @index < @history.length - 1
      @index++
      item = @history.getAtIndex(@index)
    else if @scratch
      item = @scratch
    else
      item = ''

    @miniEditor.setText item

  atLastItem: ->
    @index == @history.length - 1

  store: ->
    text = @miniEditor.getText()
    return if not text or text is @history.getLast()
    @scratch = null
    @history.add(text)
    @index = @history.length - 1

module.exports = {History, HistoryCycler}
