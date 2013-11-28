Q = require 'q'
{_} = require 'atom'
{Emitter} = require 'emissary'

class Result
  constructor: (@data) ->

module.exports =
class ResultsModel
  Emitter.includeInto(this)

  constructor: (state={}) ->
    @useRegex = state.useRegex ? false
    @caseSensitive = state.caseSensitive ? false

    atom.project.eachEditor (editSession) =>
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
    @active = false
    @pattern = ''
    @replacementPattern = null
    @emit('cleared')

  search: (pattern, paths, onlyRunIfChanged = false) ->
    return Q() if onlyRunIfChanged and pattern? and paths? and pattern == @pattern and _.isEqual(paths, @searchedPaths)

    @clear()
    @active = true
    @regex = @getRegex(pattern)
    @pattern = pattern
    @searchedPaths = paths

    onPathsSearched = (numberOfPathsSearched) =>
      @emit('paths-searched', numberOfPathsSearched)

    promise = atom.project.scan @regex, {paths, onPathsSearched}, (result) =>
      @setResult(result.filePath, if result.matches?.length then new Result(result.matches) else null)

    @emit('search', promise)
    promise.then => @emit('finished-searching')

  replace: (pattern, replacementText, paths) ->
    regex = @getRegex(pattern)

    pathsReplaced = 0
    replacements = 0

    promise = atom.project.replace regex, replacementText, paths, (result) =>
      if result and result.replacements
        pathsReplaced++
        replacements += result.replacements
      @emit('path-replaced', result)

    @emit('replace', promise)
    promise.then =>
      @clear()
      @emit('finished-replacing', {pathsReplaced, replacements})

  updateReplacementPattern: (replacementPattern) ->
    @replacementPattern = replacementPattern or 'null'
    @emit('replacement-pattern-changed', @regex, replacementPattern)

  toggleUseRegex: ->
    @useRegex = not @useRegex

  toggleCaseSensitive: ->
    @caseSensitive = not @caseSensitive

  getPathCount: ->
    @pathCount

  getMatchCount: ->
    @matchCount

  getPattern: ->
    @pattern or ''

  getPaths: (filePath) ->
    @paths

  getResult: (filePath) ->
    @results[filePath]

  setResult: (filePath, result) ->
    if result
      @addResult(filePath, result)
    else
      @removeResult(filePath)

  addResult: (filePath, result) ->
    if @results[filePath]
      @matchCount -= @results[filePath].data.length
    else
      @pathCount++
      @paths.push(filePath)

    @matchCount += result.data.length

    @results[filePath] = result
    @emit('result-added', filePath, result)

  removeResult: (filePath) ->
    if @results[filePath]
      @pathCount--
      @matchCount -= @results[filePath].data.length

      @paths = _.without(@paths, filePath)
      delete @results[filePath]
      @emit('result-removed', filePath)

  getRegex: (pattern) ->
    flags = 'g'
    flags += 'i' unless @caseSensitive

    if @useRegex
      new RegExp(pattern, flags)
    else
      new RegExp(_.escapeRegExp(pattern), flags)

  onContentsModified: (editSession) =>
    return unless @active

    matches = []
    editSession.scan @regex, (match) ->
      matches.push(match)

    result = if matches?.length then new Result(matches) else null
    @setResult(editSession.getPath(), result)
    @emit('finished-searching')
