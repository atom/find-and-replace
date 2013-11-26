{_} = require 'atom'
{Emitter} = require 'emissary'

module.exports =
class ResultsModel
  Emitter.includeInto(this)

  constructor: (state={}) ->
    @useRegex = state.useRegex ? false
    @caseSensitive = state.caseSensitive ? false

    atom.rootView.eachEditSession (editSession) =>
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
    @emit('cleared')

  search: (pattern, paths)->
    @clear()
    @active = true
    @regex = @getRegex(pattern)
    @pattern = pattern

    onPathsSearched = (numberOfPathsSearched) =>
      @emit('paths-searched', numberOfPathsSearched)

    promise = atom.project.scan @regex, {paths, onPathsSearched}, (result) =>
      @setResult(result.filePath, result.matches)

    promise.done => @emit('finished-searching')

    @emit('search', promise)

    promise

  replace: (pattern, replacementText, paths) ->
    regex = @getRegex(pattern)

    pathsReplaced = 0
    replacements = 0

    promise = atom.project.replace regex, replacementText, paths, (result) =>
      if result and result.replacements
        pathsReplaced++
        replacements += result.replacements
      @emit('path-replaced', result)

    promise.done =>
      @clear()
      @emit('finished-replacing', {pathsReplaced, replacements})

    @emit('replace', promise)

    promise

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
    @emit('result-added', filePath, matches)

  removeResult: (filePath) ->
    if @results[filePath]
      @pathCount--
      @matchCount -= @results[filePath].length

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

    @setResult(editSession.getPath(), matches)
    @emit('finished-searching')
