_ = require 'underscore-plus'
{Point, Range, Emitter, CompositeDisposable, TextBuffer} = require 'atom'
FindOptions = require './find-options'
escapeHelper = require './escape-helper'

ResultsMarkerLayersByEditor = new WeakMap

module.exports =
class BufferSearch
  constructor: (@findOptions) ->
    @emitter = new Emitter
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
    if @editor?.buffer?
      @subscriptions = new CompositeDisposable
      @subscriptions.add @editor.buffer.onDidStopChanging(@bufferStoppedChanging.bind(this))
      @subscriptions.add @editor.onDidAddSelection(@setCurrentMarkerFromSelection.bind(this))
      @subscriptions.add @editor.onDidChangeSelectionRange(@setCurrentMarkerFromSelection.bind(this))
      @resultsMarkerLayer = @resultsMarkerLayerForTextEditor(@editor)
      @resultsLayerDecoration?.destroy()
      @resultsLayerDecoration = @editor.decorateMarkerLayer(@resultsMarkerLayer, {type: 'highlight', class: 'find-result'})
    @recreateMarkers()

  getEditor: -> @editor

  setFindOptions: (newParams) -> @findOptions.set(newParams)

  getFindOptions: -> @findOptions

  resultsMarkerLayerForTextEditor: (editor) ->
    unless layer = ResultsMarkerLayersByEditor.get(editor)
      layer = editor.addMarkerLayer({maintainHistory: false})
      ResultsMarkerLayersByEditor.set(editor, layer)
    layer

  patternMatchesEmptyString: (findPattern) ->
    findOptions = new FindOptions(@findOptions.serialize())
    findOptions.set({findPattern})
    try
      findOptions.getFindPatternRegex().test('')
    catch e
      @emitter.emit 'did-error', e
      false

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
      replacePattern = escapeHelper.unescapeEscapeSequence(replacePattern) if @findOptions.useRegex
      for marker in markers
        bufferRange = marker.getBufferRange()
        replacementText = null
        if @findOptions.useRegex
          textToReplace = @editor.getTextInBufferRange(bufferRange)
          replacementText = textToReplace.replace(@getFindPatternRegex(), replacePattern)
        @editor.setTextInBufferRange(bufferRange, replacementText ? replacePattern)

        marker.destroy()
        @markers.splice(@markers.indexOf(marker), 1)

    @emitter.emit 'did-update', @markers.slice()

  destroy: ->
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
        try
          @editor.scanInBufferRange regex, Range(start, end), ({range}) =>
            newMarkers.push(@createMarker(range))
        catch error
          error.message = "Search string is too large" if /RegExp too big$/.test(error.message)
          @emitter.emit 'did-error', error
          return false
      else
        return false
    newMarkers

  bufferStoppedChanging: ({changes}) ->
    scanEnd = Point.ZERO
    markerIndex = 0

    for change in changes
      changeStart = change.start
      changeEnd = change.start.traverse(change.newExtent)
      continue if changeEnd.isLessThan(scanEnd)

      precedingMarkerIndex = -1
      while marker = @markers[markerIndex]
        if marker.isValid()
          break if marker.getBufferRange().end.isGreaterThan(changeStart)
          precedingMarkerIndex = markerIndex
        else
          @markers[markerIndex] = @recreateMarker(marker)
        markerIndex++

      followingMarkerIndex = -1
      while marker = @markers[markerIndex]
        if marker.isValid()
          followingMarkerIndex = markerIndex
          break if marker.getBufferRange().start.isGreaterThanOrEqual(changeEnd)
        else
          @markers[markerIndex] = @recreateMarker(marker)
        markerIndex++

      if precedingMarkerIndex >= 0
        spliceStart = precedingMarkerIndex
        scanStart = @markers[precedingMarkerIndex].getBufferRange().start
      else
        spliceStart = 0
        scanStart = Point.ZERO

      if followingMarkerIndex >= 0
        spliceEnd = followingMarkerIndex
        scanEnd = @markers[followingMarkerIndex].getBufferRange().end
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
    @currentResultMarker = null
    @setCurrentMarkerFromSelection()

  setCurrentMarkerFromSelection: ->
    marker = null
    marker = @findMarker(@editor.getSelectedBufferRange()) if @editor?

    return if marker is @currentResultMarker

    if @currentResultMarker?
      @resultsLayerDecoration.setPropertiesForMarker(@currentResultMarker, null)
      @currentResultMarker = null

    if marker and not marker.isDestroyed()
      @resultsLayerDecoration.setPropertiesForMarker(marker, type: 'highlight', class: 'current-result')
      @currentResultMarker = marker

    @emitter.emit 'did-change-current-result', @currentResultMarker

  findMarker: (range) ->
    if @markers?.length > 0
      @resultsMarkerLayer.findMarkers({startPosition: range.start, endPosition: range.end})[0]

  recreateMarker: (marker) ->
    marker.destroy()
    @createMarker(marker.getBufferRange())

  createMarker: (range) ->
    marker = @resultsMarkerLayer.markBufferRange(range, {invalidate: 'inside'})
    marker

  getFindPatternRegex: ->
    try
      @findOptions.getFindPatternRegex()
    catch e
      @emitter.emit 'did-error', e
      null
