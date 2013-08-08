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

    @editor.on 'editor:path-changed', @onPathChanged
    @onPathChanged()

  search: =>
    return unless @searchModel.regex
    @markers = @findAndMarkRanges()
    @emit 'change:markers', markers: @markers

  setBuffer: (buffer) ->
    @unbindBuffer(buffer)
    @bindBuffer(@buffer = buffer)
    @search()

  findNext: (range) ->
    return null unless @markers and @markers.length
    for marker in @markers
      return marker.getBufferRange() if marker.isValid() and marker.getBufferRange().compare(range) > 0
    @markers[0].getBufferRange()

  findPrevious: (range) ->

  ### Event Handlers ###

  onPathChanged: =>
    @setBuffer(@editor.activeEditSession.buffer)

  onContentsModified: =>
    return unless @searchModel.regex

    rangesToAdd = []

    ranges = @findRanges()
    for range in ranges
      matchingMarker = null
      for marker in @markers
        matchingMarker = marker if marker.getBufferRange().compare(range) == 0

      if matchingMarker and not matchingMarker.isValid()
        matchingMarker.bufferMarker.revalidate()
      else if not matchingMarker
        rangesToAdd.push(range)

    @addMarkers(rangesToAdd) 

  ### Internal ###

  bindBuffer: (buffer) ->
    return unless buffer
    buffer.on 'contents-modified', @onContentsModified
  unbindBuffer: (buffer) ->
    return unless buffer
    buffer.off 'contents-modified', @onContentsModified

  addMarkers: (rangesToAdd) ->
    markerAttributes = @getMarkerAttributes()
    editSession = @editor.activeEditSession

    markers = (editSession.markBufferRange(range, markerAttributes) for range in rangesToAdd)

    @markers = @markers.concat(markers)
    @markers.sort (left, right) -> left.getBufferRange().compare(right.getBufferRange())

    @emit('add:markers', markers: markers)

  findAndMarkRanges: ->
    @destroyMarkers()

    markerAttributes = @getMarkerAttributes()
    editSession = @editor.activeEditSession

    markers = (editSession.markBufferRange(range, markerAttributes) for range in @findRanges())

    console.log 'searched; found', markers
    markers

  findRanges: ->
    return [] unless @searchModel.regex

    options = @searchModel.options #TODO: handle inSelection option

    ranges = []
    @buffer.scanInRange @searchModel.regex, @buffer.getRange(), ({range}) ->
      ranges.push(range)
    ranges

  destroyMarkers: ->
    marker.destroy() for marker in @markers

  getMarkerAttributes: (attributes={}) ->
    _.extend attributes, 
      class: 'search-result'
      displayBufferId: @editor.activeEditSession.displayBuffer.id
      invalidationStrategy: 'between'
