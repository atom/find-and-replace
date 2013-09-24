{_, EventEmitter} = require 'atom'

class SearchResultsModel
  _.extend @prototype, EventEmitter

  constructor: ->
    @clear()

  clear: ->
    @results = {}
    @trigger('results-cleared', filePath, matches)

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
