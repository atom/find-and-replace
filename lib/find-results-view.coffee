_ = require 'underscore'
{View} = require 'space-pen'
Editor = require 'editor'
Selection = require 'selection'
MarkerView = require './marker-view'

module.exports =
class FindResultsView extends View

  @content: ->
    @div class: 'search-results'

  initialize: (@findModel) ->
    @markerViews = []
    @subscribe @findModel, 'updated', (markers) => @markersUpdated(markers)

  attach: ->
    @getEditor().underlayer.append(this)

  detach: ->
    super

  getEditor: ->
    activeView = rootView.getActiveView()
    if activeView instanceof Editor then activeView else null

  markersUpdated: (@markers) ->
    @destroyMarkerViews()

    editor = @getEditor()
    return if not editor

    editor = @getEditor()
    for marker in @markers
      markerView = new MarkerView({editor, marker})
      @markerViews.push(markerView)
      @append(markerView.element)

    @getEditor().requestDisplayUpdate()

  destroyMarkerViews: ->
    @empty()
    @markerViews = []
