_ = require 'underscore'
EventEmitter = require 'event-emitter'
shell = require 'shell'
EditSession = require 'edit-session'
require 'underscore-extensions'

module.exports =
class FindModel
  _.extend @prototype, EventEmitter

  constructor: (options={}) ->
    @options = _.extend({}, @optionDefaults(), options)
    @findPattern = ''
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
      @editSession?.getBuffer().on "changed.find", =>
        @updateMarkers() unless @replacing

    @trigger 'updated', @markers

  serialize: ->
    options: @options

  update: (findPattern=@findPattern, replacePattern=@replacePattern)->
    @replacePattern = replacePattern

    if findPattern != @findPattern or not @valid
      @findPattern = findPattern
      @updateMarkers()

  toggleOption: (optionName) ->
    currentState = @getOption(optionName)
    @options[optionName] = !currentState
    @updateMarkers()

  getOption: (key) ->
    @options[key]

  getEditSession: ->
    @editSession

  getRegex: ->
    flags = 'g'
    flags += 'i' unless @options.caseSensitive

    if @options.regex
      new RegExp(@findPattern, flags)
    else
      escapedPattern = _.escapeRegExp(@findPattern)
      new RegExp(escapedPattern, flags)

  replace: (markers) ->
    return unless markers?.length > 0

    @replacing = true
    for marker in markers
      bufferRange = marker.getBufferRange()
      @editSession.setTextInBufferRange(bufferRange, @replacePattern)
    @replacing = false

    @markers = @markers.filter (marker) -> marker.isValid()
    @trigger 'updated', @markers

  updateMarkers: ->
    @destroyMarkers()
    @valid = true

    if not @editSession? or not @findPattern
      @trigger 'updated', @markers
      return

    markerAttributes =
      class: 'find-result'
      invalidation: 'inside'
      replicate: false
      # originSiteId: Infinity # HACK: Don't serialize this marker

    if @getOption('inSelection')
      bufferRange = @editSession.getSelectedBufferRange()
    else
      bufferRange = [[0,0],[Infinity,Infinity]]

    @editSession.scanInBufferRange @getRegex(), bufferRange, ({range}) =>
      @markers.push @editSession.markBufferRange(range, markerAttributes)

    shell.beep() if @markers.length == 0
    @trigger 'updated', @markers

  destroyMarkers: ->
    @valid = false
    marker.destroy() for marker in @markers ? []
    @markers = []

  optionDefaults: ->
    regex: false
    inSelection: false
    caseSensitive: false
