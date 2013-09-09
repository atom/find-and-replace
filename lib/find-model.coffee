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
    @pattern = ''
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

  setPattern: (pattern)->
    if pattern != @pattern or not @valid
      @pattern = pattern
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

    if @getOption('regex')
      new RegExp(@pattern, flags)
    else
      escapedPattern = _.escapeRegExp(@pattern)
      new RegExp(escapedPattern, flags)

  replace: (markers, replacementText) ->
    return unless markers?.length > 0

    @replacing = true
    for marker in markers
      bufferRange = marker.getBufferRange()
      if @getOption('regex')
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
