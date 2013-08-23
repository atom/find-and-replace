EventEmitter = require 'event-emitter'
_ = require 'underscore'
require 'underscore-extensions'

# Holds the current search pattern and search options. Does not run the search
# on a buffer. Just holds the parameter state. See {SearchResultsModel}
module.exports =
class SearchModel
  _.extend @prototype, EventEmitter

  HISTORY_MAX = 25

  # options -
  #   regex: false
  #   caseSensitive: false
  #   inWord: false
  #   inSelection: false
  constructor: (@options={}, @history=[]) ->
    @pattern = ''
    @results = {}
    @historyIndex = @history.length
    @resultsVisible = false

  serialize: ->
    options: @options
    history: @history[-HISTORY_MAX..]

  setOption: (key, value) ->
    return if @options[key] == value
    @options[key] = value
    @update()

  getOption: (key) ->
    @options[key]

  setPattern: (pattern) ->
    return if @pattern == pattern
    @pattern = pattern
    @addToHistory(@pattern)
    @update()

  searchPreviousInHistory: ->
    return unless @historyIndex > 0
    @historyIndex--
    @pattern = @history[@historyIndex]
    @update()

  searchNextInHistory: ->
    return unless @historyIndex < @history.length
    @historyIndex++
    @pattern = @history[@historyIndex] or ''
    @update()

  currentHistoryPattern: ->
    @history[@historyIndex]

  moveToEndOfHistory: ->
    @historyIndex = @history.length

  ### Internal ###

  update: ->
    regex = @getRegex()
    @trigger 'change', { regex, @historyIndex, @history }

  getRegex: ->
    flags = 'g'
    flags += 'i' unless @options.caseSensitive
    escapedPattern = _.escapeRegExp(@pattern) unless @options.regex
    new RegExp(escapedPattern, flags)

  addToHistory: (pattern) ->
    @history.push(pattern)
    @historyIndex = @history.length - 1
