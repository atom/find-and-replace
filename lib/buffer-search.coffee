_ = require 'underscore-plus'
{Point, Range, Emitter, CompositeDisposable, TextBuffer} = require 'atom'
{Patch} = TextBuffer
escapeHelper = require './escape-helper'

module.exports =
class BufferSearch
  @markerClass: 'find-result'

  constructor: (@findOptions) ->
    @emitter = new Emitter
    @patch = new Patch
    @subscriptions = null
    @markers = []
    @editor = null

    recreateMarkers = @recreateMarkers.bind(this)
    @findOptions.onDidChange (changedParams) =>
      return unless changedParams?
      return unless changedParams.findPattern? or
        changedParams.useRegex? or
        changedParams.wholeWord? or
        changedParams.caseSensitive? or
        changedParams.inCurrentSelection?
      @recreateMarkers()

  onDidUpdate: (callback) ->
    @emitter.on 'did-update', callback

  onDidError: (callback) ->
    @emitter.on 'did-error', callback

  onDidChangeCurrentResult: (callback) ->
    @emitter.on 'did-change-current-result', callback

  setEditor: (@editor) ->
    @subscriptions?.dispose()
    @resultsMarkerLayer?.destroy()
    @resultsMarkerLayerDecoration?.destroy()

    if buffer = @editor?.getBuffer()
      @subscriptions = new CompositeDisposable
      @subscriptions.add @editor.onDidAddSelection(@setCurrentResultMarkerFromSelection.bind(this))
      @subscriptions.add @editor.onDidChangeSelectionRange(@setCurrentResultMarkerFromSelection.bind(this))
      @subscriptions.add buffer.onDidChange(@bufferChanged.bind(this))
      @subscriptions.add buffer.onDidStopChanging(@bufferStoppedChanging.bind(this))
      @resultsMarkerLayer = buffer.addMarkerLayer()
      @resultsMarkerLayerDecoration = @editor.decorateMarkerLayer(@resultsMarkerLayer, {
        type: 'highlight',
        class: @constructor.markerClass
      })
    @recreateMarkers()

  getEditor: -> @editor

  setFindOptions: (newParams) -> @findOptions.set(newParams)

  getFindOptions: -> @findOptions

  search: (findPattern, otherOptions) ->
    options = {findPattern}
    if otherOptions?
      for k, v of otherOptions
        options[k] = v
    @findOptions.set(options)

  replace: (markers, replacePattern) ->
    return unless markers?.length > 0
    @findOptions.set({replacePattern})

    @editor.transact =>
      for marker in markers
        bufferRange = marker.getRange()
        replacementText = null
        if @findOptions.useRegex
          replacePattern = escapeHelper.unescapeEscapeSequence(replacePattern)
          textToReplace = @editor.getTextInBufferRange(bufferRange)
          replacementText = textToReplace.replace(@getFindPatternRegex(), replacePattern)
        @editor.setTextInBufferRange(bufferRange, replacementText ? replacePattern)

        marker.destroy()
        @markers.splice(@markers.indexOf(marker), 1)

    @emitter.emit 'did-update', @markers.slice()

  destroy: ->
    @resultsMarkerLayer?.destroy()
    @subscriptions?.dispose()

  ###
  Section: Private
  ###

  recreateMarkers: ->
    @markers.forEach (marker) -> marker.destroy()
    @markers.length = 0
    if markers = @createMarkers(Point.ZERO, Point.INFINITY)
      @markers = markers
      @emitter.emit "did-update", @markers.slice()

  createMarkers: (start, end) ->
    newMarkers = []
    if @findOptions.findPattern and @editor
      if @findOptions.inCurrentSelection and not (selectedRange = @editor.getSelectedBufferRange()).isEmpty()
        start = Point.max(start, selectedRange.start)
        end = Point.min(end, selectedRange.end)

      if regex = @getFindPatternRegex()
        @editor.scanInBufferRange regex, Range(start, end), ({range}) =>
          newMarkers.push(@createMarker(range))
      else
        return false
    newMarkers

  bufferStoppedChanging: ->
    changes = @patch.changes()
    scanEnd = Point.ZERO
    markerIndex = 0

    until (next = changes.next()).done
      change = next.value
      changeStart = change.position
      changeEnd = changeStart.traverse(change.newExtent)
      continue if changeEnd.isLessThan(scanEnd)

      precedingMarkerIndex = -1
      while marker = @markers[markerIndex]
        if marker.isValid()
          break if marker.getRange().end.isGreaterThan(changeStart)
          precedingMarkerIndex = markerIndex
        else
          @markers[markerIndex] = @recreateMarker(marker)
        markerIndex++

      followingMarkerIndex = -1
      while marker = @markers[markerIndex]
        if marker.isValid()
          followingMarkerIndex = markerIndex
          break if marker.getRange().start.isGreaterThanOrEqual(changeEnd)
        else
          @markers[markerIndex] = @recreateMarker(marker)
        markerIndex++

      if precedingMarkerIndex >= 0
        spliceStart = precedingMarkerIndex
        scanStart = @markers[precedingMarkerIndex].getRange().start
      else
        spliceStart = 0
        scanStart = Point.ZERO

      if followingMarkerIndex >= 0
        spliceEnd = followingMarkerIndex
        scanEnd = @markers[followingMarkerIndex].getRange().end
      else
        spliceEnd = Infinity
        scanEnd = Point.INFINITY

      newMarkers = @createMarkers(scanStart, scanEnd)
      oldMarkers = @markers.splice(spliceStart, spliceEnd - spliceStart + 1, newMarkers...)
      for oldMarker in oldMarkers
        oldMarker.destroy()
      markerIndex += newMarkers.length - oldMarkers.length

    while marker = @markers[++markerIndex]
      unless marker.isValid()
        @markers[markerIndex] = @recreateMarker(marker)

    @emitter.emit "did-update", @markers.slice()
    @patch.clear()
    @currentResultMarker = null
    @setCurrentResultMarkerFromSelection()

  setCurrentResultMarkerFromSelection: ->
    {start, end} = @editor.getSelectedBufferRange()
    marker = @resultsMarkerLayer.findMarkers(startPosition: start, endPosition: end)[0] if @editor?

    return if marker is @currentResultMarker

    if @currentResultMarker?
      @resultsMarkerLayerDecoration.setPropertiesForMarker(@currentResultMarker, null)
      @currentResultMarker = null

    if marker?
      @resultsMarkerLayerDecoration.setPropertiesForMarker(marker, {type: 'highlight', class: 'current-result'})
      @currentResultMarker = marker

    @emitter.emit 'did-change-current-result', @currentResultMarker

  recreateMarker: (marker) ->
    marker.destroy()
    @createMarker(marker.getRange())

  createMarker: (range) ->
    @resultsMarkerLayer.markRange(range,
      invalidate: 'inside'
      class: @constructor.markerClass
      persistent: false
      maintainHistory: false
    )

  bufferChanged: ({oldRange, newRange, newText}) ->
    @patch.splice(
      oldRange.start,
      oldRange.getExtent(),
      newRange.getExtent(),
      newText
    )

  getFindPatternRegex: ->
    try
      @findOptions.getFindPatternRegex()
    catch e
      @emitter.emit 'did-error', e
      null
