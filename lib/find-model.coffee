_ = require 'underscore'
EventEmitter = require 'event-emitter'
EditSession = require 'edit-session'
require 'underscore-extensions'

module.exports =
class FindModel
  _.extend @prototype, EventEmitter

  constructor: (findOptions={}) ->
    @pattern = findOptions.pattern ? ''
    @useRegex = findOptions.useRegex ? false
    @inCurrentSelection = findOptions.inCurrentSelection ? false
    @caseInsensitive = findOptions.caseInsensitive ? false
    @valid = false

    @activePaneItemChanged()
    rootView.on 'pane-container:active-pane-item-changed', => @activePaneItemChanged()

  activePaneItemChanged: ->
    @editSession?.getBuffer().off(".find")
    @editSession = null
    paneItem = rootView.getActivePaneItem()
    @destroyAllMarkers()

    if paneItem instanceof EditSession
      @editSession = paneItem
      @editSession?.getBuffer().on "contents-modified.find", (args) =>
        @updateMarkers() unless @replacing

  serialize: ->
    {@pattern, @useRegex, @inCurrentSelection, @caseInsensitive}

  update: (newFindOptions={}) ->
    currentFindOptions = {@pattern, @useRegex, @inCurrentSelection, @caseInsensitive}
    _.defaults(newFindOptions, currentFindOptions)

    unless @valid and _.isEqual(newFindOptions, currentFindOptions)
      _.extend(this, newFindOptions)
      @updateMarkers()

  replace: (markers, replacementText) ->
    return unless markers?.length > 0

    @replacing = true
    for marker in markers
      bufferRange = marker.getBufferRange()
      if @useRegex
        textToReplace = @editSession.getTextInBufferRange(bufferRange)
        replacementText = textToReplace.replace(@getRegex(), replacementText)
      @editSession.setTextInBufferRange(bufferRange, replacementText)

      marker.destroy()
      @markers.splice(@markers.indexOf(marker), 1)
    @replacing = false

    @trigger 'updated', _.clone(@markers)

  updateMarkers: ->
    if not @editSession? or not @pattern
      @destroyAllMarkers()
      return

    @valid = true
    if @inCurrentSelection
      bufferRange = @editSession.getSelectedBufferRange()
    else
      bufferRange = [[0,0],[Infinity,Infinity]]

    updatedMarkers = []
    markersToRemoveById = {}
    markerClass = 'find-result'

    markersToRemoveById[marker.id] = marker for marker in @markers

    @editSession.scanInBufferRange @getRegex(), bufferRange, ({range}) =>
      if marker = @findMarker(range, markerClass)
        delete markersToRemoveById[marker.id]
      else
        marker = @createMarker(range, markerClass)

      updatedMarkers.push marker

    marker.destroy() for id, marker of markersToRemoveById

    @markers = updatedMarkers
    @trigger 'updated', _.clone(@markers)

  findMarker: (range, markerClass) ->
    attributes = { class: markerClass, startPosition: range.start, endPosition: range.end }
    _.find @editSession.findMarkers(attributes), (marker) -> marker.isValid()

  createMarker: (range, markerClass) ->
    markerAttributes = { class: markerClass, invalidation: 'inside', replicate: false }
    @editSession.markBufferRange(range, markerAttributes)

  destroyAllMarkers: ->
    @valid = false
    @markers = []
    @trigger 'updated', _.clone(@markers)

  getEditSession: ->
    @editSession

  getRegex: ->
    flags = 'g'
    flags += 'i' unless @caseInsensitive

    if @useRegex
      new RegExp(@pattern, flags)
    else
      escapedPattern = _.escapeRegExp(@pattern)
      new RegExp(escapedPattern, flags)
