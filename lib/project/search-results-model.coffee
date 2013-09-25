{_, EventEmitter} = require 'atom'

module.exports =
class SearchResultsModel
  _.extend @prototype, EventEmitter

  constructor: (state={}) ->
    @useRegex = state.useRegex ? false
    @inCurrentSelection = state.inCurrentSelection ? false

    rootView.eachEditSession (editSession) =>
      editSession.on 'contents-modified', => @onContentsModified(editSession)

    @clear()

  serialize: ->
    {@useRegex, @inCurrentSelection}

  clear: ->
    @regex = null
    @results = {}
    @trigger('cleared')

  search: (pattern, paths)->
    @regex = @getRegex(pattern)
    project.scan @regex, {paths}, (result) =>
      @setResult(result.filePath, result.matches)

  toggleUseRegex: ->
    @useRegex = not @useRegex

  toggleInSelection: ->
    @inSelection = not @inSelection

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

  onContentsModified: (editSession) =>
    return unless @regex

    matches = []
    editSession.scan @regex, (match) ->
      matches.push(match)

    @setResult(editSession.getPath(), matches)
