{EventEmitter} = require 'events'
_ = require 'underscore'

# Will be one of these per editor. We will swap the buffers in and out as the
# user opens/closes buffers.
module.exports =
class SearchResultsModel extends EventEmitter
  # options - 
  #   regex: false
  #   caseSensitive: false
  #   inWord: false
  #   inSelection: false
  constructor: (@searchModel, @editor) ->
    @ranges = []
    @searchModel.on 'change', @search
    @searchModel.setResultsForId(@editor.id, this)

  search: =>
    return unless @searchModel.regex
    @ranges = @findRanges(@buffer, @searchModel.regex, @searchModel.options)
    @emit 'change:ranges', ranges: @ranges

  setBuffer: (buffer) ->
    @unbindBuffer(@buffer)
    @bindBuffer(@buffer = buffer)
    @search()

  findNext: (range) ->
    return null unless @ranges and @ranges.length
    for foundRange in @ranges
      return foundRange if foundRange.compare(range) > 0
    @ranges[0]

  findPrevious: (range) ->

  ### Internal ###

  bindBuffer: (buffer) ->
    return unless buffer
    buffer.on 'contents-modified', @search
  unbindBuffer: (buffer) ->
    return unless buffer
    buffer.off 'contents-modified', @search

  findRanges: (buffer, regex, {inSelection}={}) -> 
    ranges = []
    buffer.scanInRange regex, buffer.getRange(), ({range}) ->
      ranges.push(range)
    console.log ranges
    ranges
