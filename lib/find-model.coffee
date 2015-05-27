_ = require 'underscore-plus'
{Emitter, CompositeDisposable} = require 'atom'
escapeHelper = require './escape-helper'

module.exports =
class FindModel
  @markerClass: 'find-result'

  constructor: (state={}) ->
    @emitter = new Emitter()
    @pattern = ''
    @useRegex = state.useRegex ? atom.config.get('find-and-replace.useRegex') ? false
    @inCurrentSelection = state.inCurrentSelection ? atom.config.get('find-and-replace.inCurrentSelection') ? false
    @caseSensitive = state.caseSensitive ? atom.config.get('find-and-replace.caseSensitive') ? false
    @wholeWord = state.wholeWord ? atom.config.get('find-and-replace.wholeWord') ? false
    @valid = false

    atom.workspace.observeActivePaneItem @activePaneItemChanged

  onDidUpdate: (callback) ->
    @emitter.on 'did-update', callback

  onDidError: (callback) ->
    @emitter.on 'did-error', callback

  onDidChangeCurrentResult: (callback) ->
    @emitter.on 'did-change-current-result', callback

  activePaneItemChanged: (paneItem) =>
    @editor = null
    @subscriptions?.dispose()
    @subscriptions = new CompositeDisposable
    @destroyAllMarkers()

    if paneItem?.getBuffer?()?
      @editor = paneItem
      @subscriptions.add @editor.getBuffer().onDidStopChanging =>
        @updateMarkers() unless @replacing
      @subscriptions.add @editor.onDidAddSelection @setCurrentMarkerFromSelection
      @subscriptions.add @editor.onDidChangeSelectionRange @setCurrentMarkerFromSelection

      @updateMarkers()

  serialize: ->
    {@useRegex, @inCurrentSelection, @caseSensitive, @wholeWord}

  update: (newParams={}) ->
    currentParams = {@pattern, @useRegex, @inCurrentSelection, @caseSensitive, @wholeWord}
    _.defaults(newParams, currentParams)

    unless @valid and _.isEqual(newParams, currentParams)
      _.extend(this, newParams)
      @updateMarkers()

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

  updateMarkers: ->
    if not @editor? or not @pattern
      @destroyAllMarkers()
      return

    @valid = true
    if @inCurrentSelection
      bufferRange = @editor.getSelectedBufferRange()
    else
      bufferRange = [[0, 0], [Infinity, Infinity]]

    updatedMarkers = []
    markersToRemoveById = {}

    markersToRemoveById[marker.id] = marker for marker in @markers

    try
      @editor.scanInBufferRange @getRegex(), bufferRange, ({range}) =>
        if marker = @findMarker(range)
          delete markersToRemoveById[marker.id]
        else
          marker = @createMarker(range)

        updatedMarkers.push marker

      marker.destroy() for id, marker of markersToRemoveById

      @markers = updatedMarkers
      @emitter.emit 'did-update', _.clone(@markers)
      @setCurrentMarkerFromSelection()
    catch e
      @destroyAllMarkers()
      @emitter.emit 'did-error', e

  setCurrentMarkerFromSelection: =>
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
    if @markers? and @markers.length
      attributes = {class: @constructor.markerClass, startPosition: range.start, endPosition: range.end}
      _.find @editor.findMarkers(attributes), (marker) -> marker.isValid()

  createMarker: (range) ->
    markerAttributes =
      class: @constructor.markerClass
      invalidate: 'inside'
      replicate: false
      persistent: false
      isCurrent: false
    marker = @editor.markBufferRange(range, markerAttributes)
    if @editor.decorateMarker?
      decoration = @editor.decorateMarker(marker, type: 'highlight', class: @constructor.markerClass)
      @decorationsByMarkerId[marker.id] = decoration
    marker

  destroyAllMarkers: ->
    @valid = false
    marker.destroy() for marker in @markers ? []
    @markers = []
    @decorationsByMarkerId = {}
    @currentResultMarker = null
    @emitter.emit 'did-update', _.clone(@markers)
    @setCurrentMarkerFromSelection()

  getEditor: ->
    @editor

  getRegex: ->
    flags = 'g'
    flags += 'i' unless @caseSensitive

    if @useRegex
      expression = @pattern
    else
      expression = _.escapeRegExp(@pattern)

    expression = "\\b#{expression}\\b" if @wholeWord

    new RegExp(expression, flags)
