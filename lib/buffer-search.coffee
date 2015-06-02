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
    change = null
    changesDone = false
    changeEnd = Point.ZERO
    scanEnd = Point.ZERO
    withinChange = false
    markerIndex = 0
    lastValidMarkerIndex = -1

    while (marker = @markers[markerIndex])? or change?
      unless change?
        until changesDone or changeEnd?.isGreaterThan(scanEnd)
          {value: change, done: changesDone} = changes.next()
          changeEnd = change.position.traverse(change.newExtent) if change?

      markerRange = marker?.getBufferRange()

      if withinChange
        if marker?
          if marker.isValid() and markerRange.start.isGreaterThan(changeEnd)
            withinChange = false
            scanEnd = markerRange.end
        else
          withinChange = false
          scanEnd = Point.INFINITY

        if not withinChange
          if lastValidMarkerIndex >= 0
            scanStart = @markers[lastValidMarkerIndex].getBufferRange().start
            spliceIndex = lastValidMarkerIndex
          else
            scanStart = Point.ZERO
            spliceIndex = 0

          newMarkers = @createMarkers(scanStart, scanEnd)
          oldMarkers = @markers.splice(spliceIndex, markerIndex - spliceIndex + 1, newMarkers...)
          oldMarker.destroy() for oldMarker in oldMarkers
          markerIndex += newMarkers.length - oldMarkers.length
          lastValidMarkerIndex = markerIndex
          change = null
      else
        if change? and markerRange.end.isGreaterThanOrEqual(change.position)
          withinChange = true
        else
          if marker.isValid()
            lastValidMarkerIndex = markerIndex
          else
            @markers[markerIndex] = @recreateMarker(marker)

      markerIndex++

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
