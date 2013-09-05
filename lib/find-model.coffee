EventEmitter = require 'event-emitter'
_ = require 'underscore'
EditSession = require 'edit-session'
require 'underscore-extensions'

module.exports =
class FindModel
  _.extend @prototype, EventEmitter

  constructor: (options={}) ->
    @options = _.extend(@optionDefaults(), options)
    @pattern = ''
    @replacePattern = ''
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
      @editSession?.getBuffer().on "changed.find", => @findAll()

    @trigger 'markers-updated', @markers

  serialize: ->
    options: @options

  isValid: ->
    @valid

  optionDefaults: ->
    regex: false
    inWord: false
    inSelection: false
    caseSensitive: false

  toggleOption: (optionName) ->
    currentState = @getOption(optionName)
    @options[optionName] = !currentState
    @update()

  getOption: (key) ->
    @options[key]

  setPattern: (pattern='') ->
    return if @pattern == pattern
    @pattern = pattern
    @update()

  setReplacePattern: (replacePattern='') ->
    return if @replacePattern == replacePattern
    @replacePattern = replacePattern
    @update()

  getEditSession: ->
    @editSession

  getRegex: ->
    flags = 'g'
    flags += 'i' unless @options.caseSensitive

    if @options.regex
      new RegExp(@pattern, flags)
    else
      escapedPattern = _.escapeRegExp(@pattern)
      new RegExp(escapedPattern, flags)

  update: ->
    @trigger 'change'

  findAll: ->
    @updateMarkers()
    @trigger 'markers-updated', @markers

  replace: ->
    @updateMarkers()
    @replaceCurrentMarkerText()
    @trigger 'markers-updated', @markers

  replaceAll: ->
    @updateMarkers()
    loop
      break unless @replaceCurrentMarkerText()?
    @trigger 'markers-updated', @markers

  replaceCurrentMarkerText: ->
    return unless @markers.length > 0

    marker = @markers[@currentMarkerIndex]
    bufferRange = marker.getBufferRange()
    @editSession.setTextInBufferRange(bufferRange, @replacePattern)
    @markers = @markers.filter (marker) -> marker.isValid()
    @currentMarkerIndex = @firstMarkerIndexAfterCursor()

  updateMarkers: ->
    @destroyMarkers()

    return if not @editSession? or not @pattern

    @valid = true

    markerAttributes =
      class: 'find-result'
      invalidation: 'inside'
      replicate: false

    if @getOption('inSelection')
      bufferRange = @editSession.getSelectedBufferRange()
    else
      bufferRange = [[0,0],[Infinity,Infinity]]

    @editSession.scanInBufferRange @getRegex(), bufferRange, ({range}) =>
      @markers.push @editSession.markBufferRange(range, markerAttributes)

    @currentMarkerIndex = @firstMarkerIndexAfterCursor()

  destroyMarkers: ->
    @valid = false
    marker.destroy() for marker in @markers ? []
    @markers = []

  firstMarkerIndexAfterCursor: ->
    selection = @editSession.getSelection()
    {start, end} = selection.getBufferRange()
    start = end if selection.isReversed()

    for marker, index in @markers
      markerStartPosition = marker.bufferMarker.getStartPosition()
      return index if markerStartPosition.isGreaterThanOrEqual(start)
    0
