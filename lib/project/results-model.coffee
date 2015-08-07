_ = require 'underscore-plus'
{Emitter} = require 'atom'
escapeHelper = require '../escape-helper'

class Result
  @create: (result) ->
    if result?.matches?.length then new Result(result) else null

  constructor: (result) ->
    _.extend(this, result)

module.exports =
class ResultsModel
  constructor: (@findOptions) ->
    @emitter = new Emitter

    atom.workspace.observeTextEditors (editor) =>
      editor.onDidStopChanging => @onContentsModified(editor)

    @clear()

  onDidClear: (callback) ->
    @emitter.on 'did-clear', callback

  onDidClearSearchState: (callback) ->
    @emitter.on 'did-clear-search-state', callback

  onDidClearReplacementState: (callback) ->
    @emitter.on 'did-clear-replacement-state', callback

  onDidSearchPaths: (callback) ->
    @emitter.on 'did-search-paths', callback

  onDidErrorForPath: (callback) ->
    @emitter.on 'did-error-for-path', callback

  onDidStartSearching: (callback) ->
    @emitter.on 'did-start-searching', callback

  onDidCancelSearching: (callback) ->
    @emitter.on 'did-cancel-searching', callback

  onDidFinishSearching: (callback) ->
    @emitter.on 'did-finish-searching', callback

  onDidStartReplacing: (callback) ->
    @emitter.on 'did-start-replacing', callback

  onDidFinishReplacing: (callback) ->
    @emitter.on 'did-finish-replacing', callback

  onDidSearchPath: (callback) ->
    @emitter.on 'did-search-path', callback

  onDidReplacePath: (callback) ->
    @emitter.on 'did-replace-path', callback

  onDidAddResult: (callback) ->
    @emitter.on 'did-add-result', callback

  onDidRemoveResult: (callback) ->
    @emitter.on 'did-remove-result', callback

  clear: ->
    @clearSearchState()
    @clearReplacementState()
    @emitter.emit 'did-clear', @getResultsSummary()

  clearSearchState: ->
    @pathCount = 0
    @matchCount = 0
    @regex = null
    @results = {}
    @paths = []
    @active = false
    @searchErrors = null

    if @inProgressSearchPromise?
      @inProgressSearchPromise.cancel()
      @inProgressSearchPromise = null

    @emitter.emit 'did-clear-search-state', @getResultsSummary()

  clearReplacementState: ->
    @replacePattern = null
    @replacedPathCount = null
    @replacementCount = null
    @replacementErrors = null
    @emitter.emit 'did-clear-replacement-state', @getResultsSummary()

  search: (findPattern, pathsPattern, replacePattern, {onlyRunIfChanged, keepReplacementState}={}) ->
    if onlyRunIfChanged and findPattern? and pathsPattern? and findPattern is @findOptions.findPattern and pathsPattern is @findOptions.pathsPattern
      return Promise.resolve()

    if keepReplacementState
      @clearSearchState()
    else
      @clear()

    @findOptions.set({findPattern, replacePattern, pathsPattern})
    @regex = @findOptions.getFindPatternRegex()

    @active = true
    searchPaths = @pathsArrayFromPathsPattern(pathsPattern)

    onPathsSearched = (numberOfPathsSearched) =>
      @emitter.emit 'did-search-paths', numberOfPathsSearched

    @inProgressSearchPromise = atom.workspace.scan @regex, {paths: searchPaths, onPathsSearched}, (result, error) =>
      if result
        @setResult(result.filePath, Result.create(result))
      else
        @searchErrors ?= []
        @searchErrors.push(error)
        @emitter.emit 'did-error-for-path', error

    @emitter.emit 'did-start-searching', @inProgressSearchPromise
    @inProgressSearchPromise.then (message) =>
      if message is 'cancelled'
        @emitter.emit 'did-cancel-searching'
      else
        @inProgressSearchPromise = null
        @emitter.emit 'did-finish-searching', @getResultsSummary()

  replace: (pathsPattern, replacePattern, replacementPaths) ->
    return unless @findOptions.findPattern and @regex?

    @findOptions.set({replacePattern, pathsPattern})

    replacePattern = escapeHelper.unescapeEscapeSequence(replacePattern) if @findOptions.useRegex

    @active = false # not active until the search is finished
    @replacedPathCount = 0
    @replacementCount = 0

    promise = atom.workspace.replace @regex, replacePattern, replacementPaths, (result, error) =>
      if result
        if result.replacements
          @replacedPathCount++
          @replacementCount += result.replacements
        @emitter.emit 'did-replace-path', result
      else
        @replacementErrors ?= []
        @replacementErrors.push(error)
        @emitter.emit 'did-error-for-path', error

    @emitter.emit 'did-start-replacing', promise
    promise.then =>
      @emitter.emit 'did-finish-replacing', @getResultsSummary()
      @search(@findOptions.findPattern, @findOptions.pathsPattern, @findOptions.replacePattern, {keepReplacementState: true})
    .catch (e) ->
      console.error e.stack

  setActive: (isActive) ->
    @active = isActive if (isActive and @findOptions.findPattern) or not isActive

  getActive: -> @active

  getFindOptions: -> @findOptions

  getResultsSummary: ->
    findPattern = @findOptions.findPattern
    replacePattern = @findOptions.replacePattern
    {
      findPattern
      replacePattern
      @pathCount
      @matchCount
      @searchErrors
      @replacedPathCount
      @replacementCount
      @replacementErrors
    }

  getPathCount: ->
    @pathCount

  getMatchCount: ->
    @matchCount

  getPaths: ->
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
      @matchCount -= @results[filePath].matches.length
    else
      @pathCount++
      @paths.push(filePath)

    @matchCount += result.matches.length

    @results[filePath] = result
    @emitter.emit 'did-add-result', {filePath, result}

  removeResult: (filePath) ->
    if @results[filePath]
      @pathCount--
      @matchCount -= @results[filePath].matches.length

      @paths = _.without(@paths, filePath)
      delete @results[filePath]
      @emitter.emit 'did-remove-result', {filePath}

  onContentsModified: (editor) =>
    return unless @active
    return unless editor.getPath()

    matches = []
    editor.scan @regex, (match) ->
      matches.push(match)

    result = Result.create({matches})
    @setResult(editor.getPath(), result)
    @emitter.emit 'did-finish-searching', @getResultsSummary()

  pathsArrayFromPathsPattern: (pathsPattern) ->
    (inputPath.trim() for inputPath in pathsPattern.trim().split(',') when inputPath)
