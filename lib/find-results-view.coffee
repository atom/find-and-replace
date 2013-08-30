_ = require 'underscore'
{View} = require 'space-pen'
Selection = require 'selection'
MarkerView = require './marker-view'
# SearchResultsModel = require './search-results-model'

module.exports =
class FindResultsView extends View

  @content: ->
    @div class: 'search-results'

  initialize: (@editor, @findModel) ->
    @findModel.on 'markers-updated', @markersUpdated
    @markerViews = []
    @model = new SearchResultsModel(@findModel, @editor)
    @model.on 'markers-changed', @replaceMarkerViews
    @model.on 'markers-added', @addMarkerViews
    @model.on 'destroyed', @destroy

    # The pane knows when the user changes focus to a different editor (split).
    # Ideally, the editor would have events for this, but tis not the case.
    @subscribe @editor.getPane(), 'pane:became-active pane:became-inactive', @updateInterface

    @setActive(active or false)

  markersUpdated: (@markers) =>

  setActive: (@active) ->
    @updateInterface()

  destroy: =>
    @unsubscribe()
    @removeMarkerViews()
    @trigger 'destroyed'
    @remove()

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
