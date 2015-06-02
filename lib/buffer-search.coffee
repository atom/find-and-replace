_ = require 'underscore-plus'
{Point, Range, Emitter, CompositeDisposable, TextBuffer} = require 'atom'
{Patch} = TextBuffer
escapeHelper = require './escape-helper'

SearchParams = [
  'useRegex',
  'pattern',
  'caseSensitive',
  'wholeWord',
  'inCurrentSelection'
]

module.exports =
class BufferSearch
  @markerClass: 'find-result'

  constructor: (searchParams={}) ->
    @emitter = new Emitter
    @patch = new Patch
    @subscriptions = null
    @markers = []
    @editor = null
    @setSearchParams(_.defaults({}, searchParams, {
      pattern: "",
      useRegex: atom.config.get('find-and-replace.useRegex') ? false
      wholeWord: atom.config.get('find-and-replace.wholeWord') ? false
      caseSensitive: atom.config.get('find-and-replace.caseSensitive') ? false
      inCurrentSelection: atom.config.get('find-and-replace.inCurrentSelection') ? false
    }))

  onDidUpdate: (callback) ->
    @emitter.on 'did-update', callback

  onDidError: (callback) ->
    @emitter.on 'did-error', callback

  onDidChangeCurrentResult: (callback) ->
    @emitter.on 'did-change-current-result', callback

  setEditor: (@editor) ->
    @subscriptions?.dispose()
    if @editor?
      @subscriptions = new CompositeDisposable
      @subscriptions.add @editor.buffer.onDidChange(@bufferChanged.bind(this))
      @subscriptions.add @editor.buffer.onDidStopChanging(@bufferStoppedChanging.bind(this))
      @subscriptions.add @editor.onDidAddSelection(@setCurrentMarkerFromSelection.bind(this))
      @subscriptions.add @editor.onDidChangeSelectionRange(@setCurrentMarkerFromSelection.bind(this))
    @recreateMarkers()

  getEditor: -> @editor

  setSearchParams: (newParams={}) ->
    changed = false
    for key in SearchParams
      if newParams[key]? and newParams[key] isnt this[key]
        this[key] = newParams[key]
        changed = true
    @recreateMarkers() if changed

  replace: (markers, replacementPattern) ->
    return unless markers?.length > 0

    @replacing = true
    @editor.transact =>
      for marker in markers
        bufferRange = marker.getBufferRange()
        replacementText = null
        if @useRegex
          replacementPattern = escapeHelper.unescapeEscapeSequence(replacementPattern)
          textToReplace = @editor.getTextInBufferRange(bufferRange)
          replacementText = textToReplace.replace(@getRegex(), replacementPattern)
        @editor.setTextInBufferRange(bufferRange, replacementText ? replacementPattern)

        marker.destroy()
        @markers.splice(@markers.indexOf(marker), 1)
    @replacing = false

    @emitter.emit 'did-update', _.clone(@markers)

  serialize: ->
    {@useRegex, @inCurrentSelection, @caseSensitive, @wholeWord}

  destroy: ->
    @subscriptions?.dispose()

  ###
  Section: Private
  ###

  recreateMarkers: ->
    @markers.forEach (marker) -> marker.destroy()
    @markers.length = 0
    @decorationsByMarkerId = {}
    if markers = @createMarkers(Point.ZERO, Point.INFINITY)
      @markers = markers
      @emitter.emit "did-update", @markers.slice()

  createMarkers: (start, end) ->
    newMarkers = []
    if @pattern and @editor
      if @inCurrentSelection
        selectedRange = @editor.getSelectedBufferRange()
        start = Point.max(start, selectedRange.start)
        end = Point.min(end, selectedRange.end)

      if regex = @getRegex()
        @editor.scanInBufferRange regex, Range(start, end), ({range}) =>
          newMarkers.push(@createMarker(range))
      else
        return false
    newMarkers

  bufferStoppedChanging: ->
    return if @replacing

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
      oldMarker.destroy() for oldMarker in oldMarkers
      markerIndex += newMarkers.length - oldMarkers.length

    while marker = @markers[++markerIndex]
      unless marker.isValid()
        @markers[markerIndex] = @recreateMarker(marker)

    @emitter.emit "did-update", @markers.slice()
    @patch.clear()

  setCurrentMarkerFromSelection: ->
    marker = null
    marker = @findMarker(@editor.getSelectedBufferRange()) if @editor?

    return if marker is @currentResultMarker

    if @currentResultMarker?
      @decorationsByMarkerId[@currentResultMarker.id]?.setProperties(type: 'highlight', class: @constructor.markerClass)
      @currentResultMarker = null

    if marker and not marker.isDestroyed()
      @decorationsByMarkerId[marker.id]?.setProperties(type: 'highlight', class: 'current-result')
      @currentResultMarker = marker

    @emitter.emit 'did-change-current-result', @currentResultMarker

  findMarker: (range) ->
    if @markers?.length > 0
      @editor.findMarkers(
        class: @constructor.markerClass,
        startPosition: range.start,
        endPosition: range.end
      )[0]

  recreateMarker: (marker) ->
    delete @decorationsByMarkerId[marker.id]
    marker.destroy()
    @createMarker(marker.getBufferRange())

  createMarker: (range) ->
    marker = @editor.markBufferRange(range,
      invalidate: 'inside'
      class: @constructor.markerClass
      persistent: false
    )
    @decorationsByMarkerId[marker.id] = @editor.decorateMarker(marker,
      type: 'highlight',
      class: @constructor.markerClass
    )
    marker

  bufferChanged: ({oldRange, newRange, newText}) ->
    @patch.splice(
      oldRange.start,
      oldRange.getExtent(),
      newRange.getExtent(),
      newText
    )

  getRegex: ->
    flags = 'g'
    flags += 'i' unless @caseSensitive

    if @useRegex
      expression = @pattern
    else
      expression = _.escapeRegExp(@pattern)

    expression = "\\b#{expression}\\b" if @wholeWord

    try
      new RegExp(expression, flags)
    catch e
      @emitter.emit 'did-error', e
      null
