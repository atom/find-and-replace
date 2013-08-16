_ = require 'underscore'
{View} = require 'space-pen'
Selection = require 'selection'
MarkerView = require './marker-view'
SearchResultsModel = require './search-results-model'

# Creates marker views for search results model.
# Will be one of these created per editor.
module.exports =
class SearchResultsView extends View

  @content: ->
    @div class: 'search-results'

  initialize: (@searchModel, @editor, {active}={}) ->
    @markerViews = []
    @model = new SearchResultsModel(@searchModel, @editor)
    @model.on 'markers-changed', @replaceMarkerViews
    @model.on 'markers-added', @addMarkerViews

    # The pane knows when the user changes focus to a different editor (split).
    # Ideally, the editor would have events for this, but tis not the case.
    @subscribe @editor.getPane(), 'pane:became-active pane:became-inactive', @updateInterface

    @setActive(active or false)

  setActive: (@active) ->
    @updateInterface()

  activate: -> @setActive(true)

  deactivate: -> @setActive(false)

  isEditorActive: ->
    @editor.getPane().isActive()

  hide: =>
    @removeMarkerViews()
    super()

  show: =>
    @addMarkerViews({markers: @model.markers})
    super()

  updateInterface: =>
    if @active and @isEditorActive() then @show() else @hide()

  removeMarkerViews: ->
    return unless @markerViews
    view.remove() for view in @markerViews
    @markerViews = []

  addMarkerViews: ({markers}) =>
    return unless @active
    @markerViews = (new MarkerView({@editor, marker}) for marker in markers)
    @append(view) for view in @markerViews
    @editor.requestDisplayUpdate()

  replaceMarkerViews: (options) =>
    @removeMarkerViews()
    @addMarkerViews(options)

