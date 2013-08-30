EventEmitter = require 'event-emitter'
_ = require 'underscore'
EditSession = require 'edit-session'
require 'underscore-extensions'

module.exports =
class FindModel
  _.extend @prototype, EventEmitter

  constructor: (@options={}) ->
    @pattern = ''

    @activePaneItemChanged()
    rootView.on 'pane-container:active-pane-item-changed', => @activePaneItemChanged()

  activePaneItemChanged: ->
    @editSession = null
    paneItem = rootView.getActivePaneItem()
    @editSession = paneItem if paneItem instanceof EditSession
    @search()

  serialize: ->
    options: @options

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

  updateMarkers: ->
    @markers = []
    return if not @editSession? or not @pattern

    buffer = @editSession.getBuffer()
    markerAttributes =
      class: 'find-result'
      invalidation: 'inside'
      replicate: false

    buffer.scanInRange @getRegex(), buffer.getRange(), ({range}) =>
      @markers.push @editSession.markBufferRange(range, markerAttributes)
