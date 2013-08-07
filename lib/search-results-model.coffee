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
    @markers = []
    @searchModel.on 'change', @search
    @searchModel.setResultsForId(@editor.id, this)

  search: =>
    return unless @searchModel.regex
    @markers = @findAndMarkRanges(@buffer, @searchModel.regex, @searchModel.options)
    @emit 'change:markers', markers: @markers

  setBuffer: (@buffer) ->
    @search()

  findNext: (range) ->
    return null unless @markers and @markers.length
    for marker in @markers
      return marker.getBufferRange() if marker.getBufferRange().compare(range) > 0
    @markers[0].getBufferRange()

  findPrevious: (range) ->

  ### Internal ###

  findAndMarkRanges: (buffer, regex, {inSelection}={}) -> 
    markerAttributes = @getMarkerAttributes()
    editSession = @editor.activeEditSession
    markers = []
    buffer.scanInRange regex, buffer.getRange(), ({range}) ->
      marker = editSession.markBufferRange(range, markerAttributes)
      markers.push(marker)
    console.log 'searched; found', markers
    markers

  getMarkerAttributes: (attributes={}) ->
    _.extend attributes, 
      class: 'search-result'
      displayBufferId: @editor.activeEditSession.displayBuffer.id
      invalidationStrategy: 'between'
