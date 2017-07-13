_ = require 'underscore-plus'
{Emitter, TextEditor} = require 'atom'
escapeHelper = require '../escape-helper'

class Result
  @create: (result) ->
    if result?.matches?.length
      matches = result.matches.map((m) ->
        return {
          matchText: m.matchText,
          lineText: m.lineText,
          lineTextOffset: m.lineTextOffset,
          range: m.range,
          leadingContextLines: m.leadingContextLines,
          trailingContextLines: m.trailingContextLines
        }
      )
      new Result({filePath: result.filePath, matches})
    else
      null

  constructor: (result) ->
    _.extend(this, result)

module.exports =
class ResultsModel
  constructor: (@findOptions) ->
    @emitter = new Emitter

    atom.workspace.getCenter().observeActivePaneItem (item) =>
      if item instanceof TextEditor
        item.onDidStopChanging => @onContentsModified(item)

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

  shoudldRerunSearch: (findPattern, pathsPattern, replacePattern, options={}) ->
    {onlyRunIfChanged} = options
    if onlyRunIfChanged and findPattern? and pathsPattern? and findPattern is @lastFindPattern and pathsPattern is @lastPathsPattern
      false
    else
      true

  search: (findPattern, pathsPattern, replacePattern, options={}) ->
    return Promise.resolve() unless @shoudldRerunSearch(findPattern, pathsPattern, replacePattern, options)

    {keepReplacementState} = options
    if keepReplacementState
      @clearSearchState()
    else
      @clear()

    @lastFindPattern = findPattern
    @lastPathsPattern = pathsPattern
    @findOptions.set(_.extend({findPattern, replacePattern, pathsPattern}, options))
    @regex = @findOptions.getFindPatternRegex()

    @active = true
    searchPaths = @pathsArrayFromPathsPattern(pathsPattern)

    onPathsSearched = (numberOfPathsSearched) =>
      @emitter.emit 'did-search-paths', numberOfPathsSearched

    leadingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountBefore')
    trailingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountAfter')
    @inProgressSearchPromise = atom.workspace.scan @regex, {paths: searchPaths, onPathsSearched, leadingContextLineCount, trailingContextLineCount}, (result, error) =>
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

  getLastFindPattern: -> @lastFindPattern

  getResultsSummary: ->
    findPattern = @lastFindPattern ? @findOptions.findPattern
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

  getResultAt: (index) ->
    @results[@paths[index]]

  setResult: (filePath, result) ->
    if result
      @addResult(filePath, result)
    else
      @removeResult(filePath)

  addResult: (filePath, result) ->
    filePathInsertedIndex = null
    filePathUpdatedIndex = null
    if @results[filePath]
      @matchCount -= @results[filePath].matches.length
      filePathUpdatedIndex = @paths.indexOf(filePath)
    else
      @pathCount++
      filePathInsertedIndex = binaryIndex(@paths, filePath, stringCompare)
      @paths.splice(filePathInsertedIndex, 0, filePath)

    @matchCount += result.matches.length

    @results[filePath] = result
    @emitter.emit 'did-add-result', {filePath, result, filePathInsertedIndex, filePathUpdatedIndex}

  removeResult: (filePath) ->
    if @results[filePath]
      @pathCount--
      @matchCount -= @results[filePath].matches.length

      filePathRemovedIndex = @paths.indexOf(filePath)
      @paths = _.without(@paths, filePath)
      delete @results[filePath]
      @emitter.emit 'did-remove-result', {filePath, filePathRemovedIndex}

  onContentsModified: (editor) =>
    return unless @active and @regex
    return unless editor.getPath()

    matches = []
    # the following condition is pretty hacky
    # it doesn't work correctly for e.g. version 1.2
    if parseFloat(atom.getVersion()) >= 1.17
      leadingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountBefore')
      trailingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountAfter')
      editor.scan @regex, {leadingContextLineCount, trailingContextLineCount}, (match) ->
        matches.push(match)
    else
      editor.scan @regex, (match) ->
        matches.push(match)

    result = Result.create({filePath: editor.getPath(), matches})
    @setResult(editor.getPath(), result)
    @emitter.emit 'did-finish-searching', @getResultsSummary()

  pathsArrayFromPathsPattern: (pathsPattern) ->
    (inputPath.trim() for inputPath in pathsPattern.trim().split(',') when inputPath)

stringCompare = (a, b) -> a.localeCompare(b)

binaryIndex = (array, value, comparator) ->
  # Lifted from underscore's _.sortedIndex ; adds a flexible comparator
  low = 0
  high = array.length
  while low < high
    mid = Math.floor((low + high) / 2)
    if comparator(array[mid], value) < 0
      low = mid + 1
    else
      high = mid
  low
