{_, EventEmitter} = require 'atom'

class SearchResultsModel
  _.extend @prototype, EventEmitter

  constructor: (state={}) ->
    @useRegex = state.useRegex ? false
    @inCurrentSelection = state.inCurrentSelection ? false

    @clear()
    rootView.eachEditSession(@subscribeToEditSession)

  subscribeToEditSession: (editSession) =>
    resultsModel = this
    editSession.on 'contents-modified', ->
      return unless resultsModel.regex

      matches = []
      promise = @scan resultsModel.regex, (match) ->
        matches.push(match)

      promise.done = =>
        resultsModel.setResult(@getPath(), matches)

  serialize: ->
    {@useRegex, @inCurrentSelection}

  search: (pattern, paths)->
    @regex = @getRegex(pattern)
    project.scan @regex, {paths}, (result) =>
      @setResult(result.filePath, result.matches)

  toggleUseRegex: ->
    @useRegex = not @useRegex

  toggleInSelection: ->
    @inSelection = not @inSelection

  clear: ->
    @regex = null
    @results = {}
    @trigger('cleared', filePath, matches)

  getResult: (filePath) ->
    @results[filePath]

  setResult: (filePath, matches) ->
    if matches and matches.length
      @addResult(filePath, matches)
    else
      @removeResult(filePath)

  addResult: (filePath, matches) ->
    @results[filePath] = matches
    @trigger('result-added', filePath, matches)

  removeResult: (filePath) ->
    if @results[filePath]
      delete @results[filePath]
      @trigger('result-removed', filePath)

  getRegex: (pattern) ->
    flags = 'g'
    flags += 'i' unless @caseInsensitive

    if @useRegex
      new RegExp(pattern, flags)
    else
      new RegExp(_.escapeRegExp(pattern), flags)
