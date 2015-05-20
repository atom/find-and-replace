_ = require 'underscore-plus'
{Point, Emitter, CompositeDisposable, TextBuffer} = require 'atom'
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
    @emitter.emit "did-update", []
    @createMarkers(0, Point.ZERO, Point.INFINITY)

  createMarkers: (index, start, end) ->
    if @pattern and @editor
      if @inCurrentSelection
        selectedRange = @editor.getSelectedBufferRange()
        start = Point.max(start, selectedRange.start)
        end = Point.min(end, selectedRange.end)

      if regex = @getRegex()
        @editor.scanInBufferRange regex, [start, end], ({range}) =>
          @createMarker(index, range)
          index++
        @emitter.emit "did-update", @markers.slice()

  bufferStoppedChanging: ->
    return if @replacing
    markerIndex = 0
    changes = @patch.changes()
    until (next = changes.next()).done
      changeStart = next.value.position
      changeEnd = next.value.position.traverse(next.value.newExtent)

      while @markers[markerIndex]?.getBufferRange().end.isLessThan(changeStart)
        markerIndex++

      startPosition = @markers[markerIndex - 1]?.getBufferRange().end ? Point.ZERO
      endPosition = @markers[markerIndex]?.getBufferRange().start ? Point.INFINITY
      @createMarkers(markerIndex, startPosition, endPosition)
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

  createMarker: (index, range) ->
    marker = @editor.markBufferRange(range,
      invalidate: 'inside'
      class: @constructor.markerClass
      persistent: false
    )

    marker.onDidChange ({isValid}) =>
      unless isValid
        marker.destroy()
        @markers.splice(@markers.indexOf(marker), 1)
        delete @decorationsByMarkerId[marker.id]

    @markers.splice(index, 0, marker)
    @decorationsByMarkerId[marker.id] = @editor.decorateMarker(marker,
      type: 'highlight',
      class: @constructor.markerClass
    )

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
