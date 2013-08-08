{EventEmitter} = require 'events'
_ = require 'underscore'

# Will be one of these per editor. We will swap the buffers in and out as the
# user opens/closes buffers.
#
# TODO/FIXME - This thing hooks the current buffer's contents-modified event.
# It will run the search and keep the markers in memory even when the find box
# is not open. This can be fixed by hooking the searchModel's 'show:results'
# and 'hide:results' events and unbinding from the buffer. But then the find-
# next (cmd+g) behavior becomes a different code path. To keep things simple
# for now, I'm going to leave it this way. If it's slow, we can implement the
# optimization.
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
    @destroyMarkers()
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

    isEqualToRange = (marker, range) ->
      # Using marker.getBufferRange().compare() was slow on large sets. This is faster.
      first = marker.bufferMarker.tailPosition or marker.bufferMarker.headPosition
      last = marker.bufferMarker.headPosition
      return false unless range.start.column == first.column and range.start.row == first.row
      return false unless range.end.column == last.column and range.end.row == last.row
      true

    rangesToAdd = []

    ranges = @findRanges()
    for range in ranges
      matchingMarker = null
      for marker in @markers
        matchingMarker = marker if isEqualToRange(marker, range)

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
    markerAttributes = @getMarkerAttributes()
    editSession = @editor.activeEditSession
    (editSession.markBufferRange(range, markerAttributes) for range in @findRanges())

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
