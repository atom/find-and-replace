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

    @activePaneItemChanged()
    rootView.on 'pane-container:active-pane-item-changed', => @activePaneItemChanged()

  activePaneItemChanged: ->
    @editSession = null
    paneItem = rootView.getActivePaneItem()
    @editSession = paneItem if paneItem instanceof EditSession
    @search()

  serialize: ->
    options: @options

  optionDefaults: ->
    regex: false
    inWord: false
    inSelection: false
    caseSensitive: false

  setOption: (key, value) ->
    return if @options[key] == value
    @options[key] = value
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

  search: ->
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

    markerAttributes =
      class: 'find-result'
      invalidation: 'inside'
      replicate: false

    bufferRange = [[0,0],[Infinity,Infinity]]
    @editSession.scanInBufferRange @getRegex(), bufferRange, ({range}) =>
      @markers.push @editSession.markBufferRange(range, markerAttributes)

    @currentMarkerIndex = @firstMarkerIndexAfterCursor()

  destroyMarkers: ->
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
