EventEmitter = require 'event-emitter'
{Range} = require 'telepath'
_ = require 'underscore'
shell = require 'shell'

# Runs the search on a buffer. Holds the markers for search results for a
# given buffer. Continually updates search results as the user types and
# markers are invalidated.
#
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
class SearchResultsModel
  _.extend @prototype, EventEmitter

  constructor: (@searchModel, @editor) ->
    @markers = []
    @currentResultIndex = null
    @searchModel.on 'change', @search

    # FIXME: I feel a little dirty
    @editor.searchResults = this

    @editor.on 'cursor:moved', @onCursorMoved
    @editor.on 'editor:path-changed', @onPathChanged
    @editor.on 'editor:will-be-removed', @destroy

    @editor.command 'find-and-replace:find-next', @selectNextResult
    @editor.command 'find-and-replace:find-previous', @selectPreviousResult
    @editor.command 'find-and-replace:replace-next', (e, {replacement}) => @replaceCurrentResultAndSelectNextResult(replacement)
    @editor.command 'find-and-replace:replace-all', (e, {replacement}) => @replaceAllResults(replacement)

    @onPathChanged()

  search: =>
    @destroyMarkers()
    @markers = @findAndMarkRanges()
    @emitCurrentResult()
    @trigger 'markers-changed', markers: @markers

  clearCurrentResult: =>
    @setCurrentResultIndex(null)

  getCurrentResult: ->
    @generateCurrentResult()

  selectNextResult: =>
    @selectResult('findNext')

  selectPreviousResult: =>
    @selectResult('findPrevious')

  replaceAllResults: (replacement) =>
    shell.beep() unless @replaceAll(replacement)

  replaceCurrentResultAndSelectNextResult: (replacement) =>
    currentResult = @replaceCurrentResultAndFindNext(replacement)
    if currentResult.range
      @selectBufferRange(currentResult.range)
    else
      shell.beep()

  findNext: (initialBufferRange) ->
    initialBufferRange = @currentBufferRange(initialBufferRange, 'first')
    if @markers and @markers.length
      for i in [0...@markers.length]
        marker = @markers[i]
        return @setCurrentResultIndex(i) if marker.getBufferRange().compare(initialBufferRange) > 0

    @findFirst()

  findPrevious: (initialBufferRange) ->
    initialBufferRange = @currentBufferRange(initialBufferRange, 'last')
    if @markers and @markers.length
      for i in [@markers.length-1..0]
        marker = @markers[i]
        range = marker.getBufferRange()
        return @setCurrentResultIndex(i) if range.compare(initialBufferRange) < 0 and not range.intersectsWith(initialBufferRange)

    @findLast()

  findFirst: ->
    @setCurrentResultIndex(if @markers.length then 0 else null)

  findLast: ->
    @setCurrentResultIndex(if @markers.length then @markers.length-1 else null)

  replaceCurrentResultAndFindNext: (replacement='', currentBufferRange) ->
    currentBufferRange = @currentBufferRange(currentBufferRange)
    return {total: 0} unless @markers.length

    if @currentResultIndex?
      bufferRange = @markers[@currentResultIndex].getBufferRange()
    else
      bufferRange = @findNext(currentBufferRange).range

    @buffer.change(bufferRange, replacement)
    @findNext(bufferRange)

  replaceAll: (replacement='') ->
    return false unless @markers.length
    @setCurrentResultIndex(null)
    @buffer.transact =>
      for marker in _.clone(@markers)
        # FIXME? It might be more efficient to delete all the markers then use the
        # replace() fn in buffer.scanRange()? Or just a regex replacement?
        @buffer.change(marker.getBufferRange(), replacement)
      @search()
    true

  destroy: =>
    @searchModel.off 'change', @search
    @editor = null
    @searchModel = null

  ### Event Handlers ###

  onPathChanged: =>
    @setBuffer(@editor.activeEditSession.buffer)

  onCursorMoved: =>
    isWithinMarker = (bufferPosition, marker) ->
      # Using marker.getBufferRange() was slow on large sets. This is faster -- no object creation.
      start = marker.bufferMarker.getTailPosition()
      end = marker.bufferMarker.getHeadPosition()
      return false unless bufferPosition.column >= start.column and bufferPosition.column <= end.column
      return false unless bufferPosition.row >= start.row and bufferPosition.row <= end.row
      true

    bufferPosition = @editor.getCursorBufferPosition()
    for i in [0...@markers.length]
      marker = @markers[i]
      return @setCurrentResultIndex(i) if isWithinMarker(bufferPosition, marker)

    @clearCurrentResult()

  onBufferContentsModified: =>
    return unless @searchModel.regex

    isEqualToRange = (marker, range) ->
      # Using marker.getBufferRange().compare() was slow on large sets. This is faster.
      start = marker.bufferMarker.getTailPosition()
      end = marker.bufferMarker.getHeadPosition()
      return false unless range.start.column == start.column and range.start.row == start.row
      return false unless range.end.column == end.column and range.end.row == end.row
      true

    rangesToAdd = []

    ranges = @findRanges()
    for range in ranges
      matchingMarker = null
      for marker in @markers
        matchingMarker = marker if isEqualToRange(marker, range)

      rangesToAdd.push(range) unless matchingMarker

    @addMarkers(rangesToAdd) if rangesToAdd.length

  onMarkerDestroyed: (marker) ->
    index = _.indexOf(@markers, marker)
    @markers = _.without(@markers, marker)
    @clearCurrentResult() if index == @currentResultIndex

  onMarkerChanged: (marker, options={}) ->
    @destroyMarker(marker) unless options.isValid
    @emitCurrentResult()

  ### Internal ###

  setBuffer: (buffer) ->
    @unbindBuffer(buffer)
    @bindBuffer(@buffer = buffer)
    @search()

  selectResult: (functionName) ->
    currentResult = @[functionName]()
    if currentResult.range
      @selectBufferRange(currentResult.range)
    else
      shell.beep() # FIXME: this is more of a view thing, but it's in here...

  selectBufferRange: (bufferRange) ->
    editSession = @editor.activeEditSession
    editSession.setSelectedBufferRange(bufferRange, autoscroll: true) if bufferRange

  setCurrentResultIndex: (index) ->
    return @generateCurrentResult() if @currentResultIndex == index
    @currentResultIndex = index
    @emitCurrentResult()

  emitCurrentResult: ->
    result = @generateCurrentResult()
    @trigger 'current-result-changed', result
    result

  generateCurrentResult: ->
    if @currentResultIndex?
      marker = @markers[@currentResultIndex]
      {
        index: @currentResultIndex
        range: marker.getBufferRange()
        marker: marker
        total: @markers.length
      }
    else 
      { total: @markers.length }

  bindBuffer: (buffer) ->
    return unless buffer
    buffer.on 'contents-modified', @onBufferContentsModified
  unbindBuffer: (buffer) ->
    return unless buffer
    buffer.off 'contents-modified', @onBufferContentsModified

  addMarkers: (rangesToAdd) ->
    markerAttributes = @getMarkerAttributes()

    markers = (@createMarker(range, markerAttributes) for range in rangesToAdd)

    @markers = @markers.concat(markers)
    @markers.sort (left, right) -> left.getBufferRange().compare(right.getBufferRange())

    @trigger 'markers-added', markers: markers
    @emitCurrentResult()

  currentBufferRange: (bufferRange, firstOrLast='first') ->
    bufferRange = _[firstOrLast](@editor.getSelectedBufferRanges()) unless bufferRange?
    Range.fromObject(bufferRange)

  findAndMarkRanges: ->
    markerAttributes = @getMarkerAttributes()
    (@createMarker(range, markerAttributes) for range in @findRanges())

  findRanges: ->
    return [] unless @searchModel.regex
    ranges = []
    for rangeToSearch in @getRangesToSearch()
      @buffer.scanInRange @searchModel.regex, rangeToSearch, ({range}) ->
        ranges.push(range)
    ranges

  getRangesToSearch: ->
    if @searchModel.options.inSelection
      selectedBufferRanges = @editor.getSelectedBufferRanges()
      # only search in selection if there is a selection somewhere.
      for range in selectedBufferRanges
        rangesToSearch = selectedBufferRanges unless range.isEmpty()
    rangesToSearch or [@buffer.getRange()]

  destroyMarkers: ->
    @destroyMarker(marker) for marker in @markers
    @setCurrentResultIndex(null)

  destroyMarker: (marker) ->
    marker.destroy()

  createMarker: (range, markerAttributes) ->
    marker = @editor.activeEditSession.markBufferRange(range, markerAttributes)
    marker.on 'changed', _.bind(@onMarkerChanged, this, marker)
    marker.on 'destroyed', _.bind(@onMarkerDestroyed, this, marker)
    marker

  getMarkerAttributes: (attributes={}) ->
    _.extend attributes, 
      class: 'search-result'
      invalidation: 'inside'
      replicate: false
