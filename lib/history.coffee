_ = require 'underscore-plus'
{Emitter} = require 'atom'

HISTORY_MAX = 25

class History
  constructor: (@items=[]) ->
    @emitter = new Emitter
    @length = @items.length

  onDidAddItem: (callback) ->
    @emitter.on 'did-add-item', callback

  serialize: ->
    @items[-HISTORY_MAX..]

  getLast: ->
    _.last(@items)

  getAtIndex: (index) ->
    @items[index]

  add: (text) ->
    @items.push(text)
    @length = @items.length
    @emitter.emit 'did-add-item', text

# Adds the ability to cycle through history
class HistoryCycler

  # * `miniEditor` an {Editor} instance to attach the cycler to
  # * `history` a {History} object
  constructor: (@miniEditor, @history) ->
    @index = @history.length
    atom.commands.add @miniEditor.element,
      'core:move-up': => @previous()
      'core:move-down': => @next()

    @history.onDidAddItem (text) =>
      @miniEditor.setText(text) if text isnt @miniEditor.getText()

  previous: ->
    if @history.length is 0 or (@atLastItem() and @miniEditor.getText() isnt @history.getLast())
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
    @index is @history.length - 1

  store: ->
    text = @miniEditor.getText()
    return if not text or text is @history.getLast()
    @scratch = null
    @history.add(text)
    @index = @history.length - 1

module.exports = {History, HistoryCycler}
