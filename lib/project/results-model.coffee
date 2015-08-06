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

  onDidChangeReplacementPattern: (callback) ->
    @emitter.on 'did-change-replacement-pattern', callback

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
    @replacementPattern = null
    @replacedPathCount = null
    @replacementCount = null
    @replacementErrors = null
    @emitter.emit 'did-clear-replacement-state', @getResultsSummary()

  search: (findPattern, searchPaths, replacementPattern, {onlyRunIfChanged, keepReplacementState}={}) ->
    if onlyRunIfChanged and findPattern? and searchPaths? and findPattern is @findOptions.findPattern and _.isEqual(searchPaths, @searchedPaths)
      return Promise.resolve()

    if keepReplacementState
      @clearSearchState()
    else
      @clear()

    @active = true
    @regex = @getRegex(findPattern)
    @searchedPaths = searchPaths
    @findOptions.set({findPattern})

    @updateReplacementPattern(replacementPattern)

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

  replace: (searchPaths, replacementPattern, replacementPaths) ->
    return unless @findOptions.findPattern and @regex?

    @updateReplacementPattern(replacementPattern)
    replacementPattern = escapeHelper.unescapeEscapeSequence(replacementPattern) if @findOptions.useRegex

    @active = false # not active until the search after finish
    @replacedPathCount = 0
    @replacementCount = 0

    promise = atom.workspace.replace @regex, replacementPattern, replacementPaths, (result, error) =>
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
      @search(@findOptions.findPattern, searchPaths, replacementPattern, {keepReplacementState: true})

  updateReplacementPattern: (replacementPattern) ->
    @replacementPattern = replacementPattern or null
    @emitter.emit 'did-change-replacement-pattern', @regex, replacementPattern

  setActive: (isActive) ->
    @active = isActive if (isActive and @findOptions.pattern) or not isActive

  getActive: -> @active

  getFindOptions: -> @findOptions

  getResultsSummary: ->
    pattern = @findOptions.findPattern
    {
      pattern
      @pathCount
      @matchCount
      @searchErrors
      @replacementPattern
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

  getRegex: (pattern) ->
    flags = 'g'
    flags += 'i' unless @findOptions.caseSensitive

    if @findOptions.useRegex
      expression = pattern
    else
      expression = _.escapeRegExp(pattern)

    expression = "\\b#{expression}\\b" if @findOptions.wholeWord

    new RegExp(expression, flags)

  onContentsModified: (editor) =>
    return unless @active
    return unless editor.getPath()

    matches = []
    editor.scan @regex, (match) ->
      matches.push(match)

    result = Result.create({matches})
    @setResult(editor.getPath(), result)
    @emitter.emit 'did-finish-searching', @getResultsSummary()
