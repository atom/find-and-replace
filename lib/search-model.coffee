EventEmitter = require 'event-emitter'
_ = require 'underscore'

# Holds the current search pattern and search options. Does not run the search
# on a buffer. Just holds the parameter state. See SearchResultsModel
module.exports =
class SearchModel
  _.extend @prototype, EventEmitter

  HISTORY_MAX = 25

  # pattern - string to search for
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

  setOptions: (options) ->
    @search(@pattern, options)

  setOption: (key, value) ->
    opts = {}
    opts[key] = value
    @search(@pattern, _.extend({}, @options, opts))

  getOption: (key) ->
    @options[key]

  setPattern: (pattern) ->
    @search(pattern, @options)

  searchPreviousInHistory: ->
    if @historyIndex > 0
      @historyIndex--
      pattern = @history[@historyIndex]
      @trigger('history-index-changed', this, { pattern, @historyIndex })
      @search(pattern, @options, addToHistory: false)

  searchNextInHistory: ->
    if @historyIndex < @history.length
      @historyIndex++
      pattern = @history[@historyIndex] or ''
      @trigger('history-index-changed', this, { pattern, @historyIndex })
      @search(pattern, @options, addToHistory: false)
    
  ### Internal ###

  search: (pattern, options={}, {addToHistory}={}) ->
    addToHistory ?= true

    pattern = pattern or ''
    return if @pattern == pattern and _.isEqual(@options, options)

    [@pattern, @options] = [pattern, options]

    @addToHistory(pattern) if addToHistory

    @regex = @buildRegex(@pattern, @options)

    @trigger 'change', this, { @regex, @historyIndex, @history }

  buildRegex: (pattern, options={}) ->
    return null unless pattern
    flags = 'g'
    flags += 'i' unless options.caseSensitive
    pattern = @escapeRegex(pattern) unless options.regex
    new RegExp(pattern, flags)

  escapeRegex: (pattern) ->
    pattern.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")

  addToHistory: (pattern) ->
    @history.push(pattern) if _.last(@history) != pattern
    @historyIndex = @history.length-1

    @trigger 'history-added', this, { @history, index: @historyIndex }
