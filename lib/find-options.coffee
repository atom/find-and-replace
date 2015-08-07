_ = require 'underscore-plus'
{Emitter} = require 'atom'

Params = [
  'findPattern'
  'replacePattern'
  'pathsPattern'
  'useRegex'
  'wholeWord'
  'caseSensitive'
  'inCurrentSelection'
]

module.exports =
class FindOptions
  constructor: (state={}) ->
    @emitter = new Emitter

    @findPattern = state.findPattern ? ''
    @replacePattern = state.replacePattern ? ''
    @pathsPattern = state.pathsPattern ? ''
    @useRegex = state.useRegex ? atom.config.get('find-and-replace.useRegex') ? false
    @caseSensitive = state.caseSensitive ? atom.config.get('find-and-replace.caseSensitive') ? false
    @wholeWord = state.wholeWord ? atom.config.get('find-and-replace.wholeWord') ? false
    @inCurrentSelection = state.inCurrentSelection ? atom.config.get('find-and-replace.inCurrentSelection') ? false

  onDidChange: (callback) ->
    @emitter.on('did-change', callback)

  onDidChangeReplacePattern: (callback) ->
    @emitter.on('did-change-replacePattern', callback)

  serialize: ->
    result = {}
    for param in Params
      result[param] = this[param]
    result

  set: (newParams={}) ->
    changedParams = null
    for key in Params
      if newParams[key]? and newParams[key] isnt this[key]
        changedParams ?= []
        changedParams.push(key)
        this[key] = newParams[key]

    if changedParams?
      for param in changedParams
        @emitter.emit("did-change-#{param}")
      @emitter.emit('did-change')

  toggleUseRegex: ->
    @useRegex = not @useRegex
    @emitter.emit('did-change')

  toggleCaseSensitive: ->
    @caseSensitive = not @caseSensitive
    @emitter.emit('did-change')

  toggleWholeWord: ->
    @wholeWord = not @wholeWord
    @emitter.emit('did-change')

  toggleInCurrentSelection: ->
    @inCurrentSelection = not @inCurrentSelection
    @emitter.emit('did-change')

  getFindPatternRegex: ->
    flags = 'g'
    flags += 'i' unless @caseSensitive

    if @useRegex
      expression = @findPattern
    else
      expression = _.escapeRegExp(@findPattern)

    expression = "\\b#{expression}\\b" if @wholeWord

    new RegExp(expression, flags)