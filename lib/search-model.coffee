EventEmitter = require 'event-emitter'
_ = require 'underscore'

# Holds the current search pattern and search options. Does not run the search
# on a buffer. Just holds the parameter state. See SearchResultsModel
module.exports =
class SearchModel
  _.extend @prototype, EventEmitter

  # pattern - string to search for
  # options - 
  #   regex: false
  #   caseSensitive: false
  #   inWord: false
  #   inSelection: false
  constructor: (pattern, options) ->
    @results = {}
    @resultsVisible = false
    @search(pattern, options)

  search: (pattern, options={}) ->
    pattern = pattern or ''
    return if @pattern == pattern and _.isEqual(@options, options)

    [@pattern, @options] = [pattern, options]

    @regex = @buildRegex(@pattern, @options)
    @trigger 'change', this, regex: @regex

  showResults: ->
    @resultsVisible = true
    @trigger 'show:results', this
  hideResults: ->
    @resultsVisible = false
    @trigger 'hide:results', this

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

  # Use activeId to specify the active editor.
  setActiveId: (id) ->
    @activeId = id
    @trigger 'change:active-id', this, {@activeId}
  setResultsForId: (id, searchResultsModel) ->
    @results[id] = searchResultsModel
  getResultsForId: (id) ->
    @results[id]
  deleteResultsForId: (id) ->
    delete @results[id]
  getActiveResultsModel: ->
    @results[@activeId]
    
  ### Internal ###

  buildRegex: (pattern, options={}) ->
    return null unless pattern
    flags = 'g'
    flags += 'i' unless options.caseSensitive
    pattern = @escapeRegex(pattern) unless options.regex
    new RegExp(pattern, flags)

  escapeRegex: (pattern) ->
    pattern.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")
