{_, EventEmitter} = require 'atom'

module.exports =
class ResultsModel
  _.extend @prototype, EventEmitter

  constructor: (state={}) ->
    @useRegex = state.useRegex ? false
    @caseSensitive = state.caseSensitive ? false

    rootView.eachEditSession (editSession) =>
      editSession.on 'contents-modified', => @onContentsModified(editSession)

    @clear()

  serialize: ->
    {@useRegex, @caseSensitive}

  clear: ->
    @pathCount = 0
    @matchCount = 0
    @regex = null
    @results = {}
    @paths = []
    @trigger('cleared')

  search: (pattern, paths)->
    @regex = @getRegex(pattern)
    project.scan @regex, {paths}, (result) =>
      @setResult(result.filePath, result.matches)

  toggleUseRegex: ->
    @useRegex = not @useRegex

  toggleCaseSensitive: ->
    @caseSensitive = not @caseSensitive

  getPathCount: ->
    @pathCount

  getMatchCount: ->
    @matchCount

  getPaths: (filePath) ->
    @paths

  getResult: (filePath) ->
    @results[filePath]

  setResult: (filePath, matches) ->
    if matches and matches.length
      @addResult(filePath, matches)
    else
      @removeResult(filePath)

  addResult: (filePath, matches) ->
    if @results[filePath]
      @matchCount -= @results[filePath].length
    else
      @pathCount++
      @paths.push(filePath)

    @matchCount += matches.length

    @results[filePath] = matches
    @trigger('result-added', filePath, matches)

  removeResult: (filePath) ->
    if @results[filePath]
      @pathCount--
      @matchCount -= @results[filePath].length

      @paths = _.without(@paths, filePath)
      delete @results[filePath]
      @trigger('result-removed', filePath)

  getRegex: (pattern) ->
    flags = 'g'
    flags += 'i' unless @caseSensitive

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
