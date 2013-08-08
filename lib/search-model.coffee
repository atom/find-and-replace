{EventEmitter} = require 'events'
_ = require 'underscore'

module.exports =
class SearchModel extends EventEmitter
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
    return unless pattern
    return if @pattern == pattern and _.isEqual(@options, options)

    [@pattern, @options] = [pattern, options]

    @regex = @buildRegex(@pattern, @options)
    @emit 'change', this, regex: @regex

  showResults: ->
    @resultsVisible = true
    @emit 'show:results', this
  hideResults: ->
    @resultsVisible = false
    @emit 'hide:results', this

  setOptions: (options) ->
    @search(@pattern, options)

  setPattern: (pattern) ->
    @search(pattern, @options)

  setResultsForId: (id, searchResultsModel) ->
    @results[id] = searchResultsModel

  getResultsForId: (id) ->
    @results[id]
    
  ### Internal ###

  buildRegex: (pattern, options={}) ->
    flags = 'g'
    flags += 'i' unless options.caseSensitive
    new RegExp(pattern, flags)
