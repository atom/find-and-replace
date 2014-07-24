_ = require 'underscore-plus'
{Emitter} = require 'emissary'
escapeHelper = require './escape-helper'

module.exports =
class FindModel
  Emitter.includeInto(this)
  @markerClass: 'find-result'

  constructor: (state={}) ->
    @pattern = ''
    @useRegex = state.useRegex ? false
    @inCurrentSelection = state.inCurrentSelection ? false
    @caseSensitive = state.caseSensitive ? false
    @valid = false

    @activePaneItemChanged()
    atom.workspaceView.on 'pane-container:active-pane-item-changed', => @activePaneItemChanged()

  activePaneItemChanged: ->
    @editor?.getBuffer().off(".find")
    @editor = null
    paneItem = atom.workspace.getActivePaneItem()
    @destroyAllMarkers()

    if paneItem?.getBuffer?()?
      @editor = paneItem
      @editor.getBuffer().on "contents-modified.find", (args) =>
        @updateMarkers() unless @replacing
      @updateMarkers()

  serialize: ->
    {@useRegex, @inCurrentSelection, @caseSensitive}

  update: (newParams={}) ->
    currentParams = {@pattern, @useRegex, @inCurrentSelection, @caseSensitive}
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

    @emit 'updated', _.clone(@markers)

  updateMarkers: ->
    if not @editor? or not @pattern
      @destroyAllMarkers()
      return

    @valid = true
    if @inCurrentSelection
      bufferRange = @editor.getSelectedBufferRange()
    else
      bufferRange = [[0,0],[Infinity,Infinity]]

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
      @emit 'updated', _.clone(@markers)
    catch e
      @destroyAllMarkers()
      @emit 'find-error', e

  setCurrentResultMarker: (marker) ->
    if @currentResultMarker?
      @decorationsByMarkerId[@currentResultMarker.id]?.update(type: 'highlight', class: @constructor.markerClass)

    @currentResultMarker = null
    if marker and not marker.isDestroyed()
      @decorationsByMarkerId[marker.id]?.update(type: 'highlight', class: 'current-result')
      @currentResultMarker = marker

  findMarker: (range) ->
    attributes = { class: @constructor.markerClass, startPosition: range.start, endPosition: range.end }
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
    @emit 'updated', _.clone(@markers)

  getEditor: ->
    @editor

  getRegex: ->
    flags = 'g'
    flags += 'i' unless @caseSensitive

    if @useRegex
      new RegExp(@pattern, flags)
    else
      new RegExp(_.escapeRegExp(@pattern), flags)
