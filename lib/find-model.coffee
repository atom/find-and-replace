_ = require 'underscore'
EventEmitter = require 'event-emitter'
shell = require 'shell'
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
    @destroyMarkers()

    if paneItem instanceof EditSession
      @editSession = paneItem
      @editSession?.getBuffer().on "changed.find", =>
        @updateMarkers() unless @replacing

    @trigger 'updated', @markers

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
    @replacing = false

    @markers = @markers.filter (marker) -> marker.isValid()
    @trigger 'updated', @markers

  updateMarkers: ->
    @destroyMarkers()
    @valid = true
    if not @editSession? or not @pattern
      @trigger 'updated', @markers
      return

    markerAttributes =
      class: 'find-result'
      invalidation: 'inside'
      replicate: false
      # originSiteId: Infinity # HACK: Don't serialize this marker

    if @inCurrentSelection
      bufferRange = @editSession.getSelectedBufferRange()
    else
      bufferRange = [[0,0],[Infinity,Infinity]]

    @editSession.scanInBufferRange @getRegex(), bufferRange, ({range}) =>
      @markers.push @editSession.markBufferRange(range, markerAttributes)

    shell.beep() if @markers.length == 0
    @trigger 'updated', @markers

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

  destroyMarkers: ->
    @valid = false
    marker.destroy() for marker in @markers ? []
    @markers = []
