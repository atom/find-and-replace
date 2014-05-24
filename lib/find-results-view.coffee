_ = require 'underscore-plus'
{EditorView, View} = require 'atom'
MarkerView = require './marker-view'

module.exports =
class FindResultsView extends View

  @content: ->
    @div class: 'search-results'

  initialize: (@findModel) ->
    @markerViews = {}
    @subscribe @findModel, 'updated', (args...) => @markersUpdated(args...)

  attach: ->
    @getEditor()?.underlayer.append(this)

  detach: ->
    super

  beforeRemove: ->
    @destroyAllViews()

  getEditor: ->
    activeView = atom.workspaceView.getActiveView()
    if activeView?.hasClass('editor') then activeView else null

  markersUpdated: (markers) ->
    editor = @getEditor()

    if not editor?
      @destroyAllViews()
    else
      markerViewsToRemoveById = _.clone(@markerViews)
      for marker in markers
        if @markerViews[marker.id]
          delete markerViewsToRemoveById[marker.id]
        else
          markerView = new MarkerView({editor, marker})
          @append(markerView.element)
          @markerViews[marker.id] = markerView

      for id, markerView of markerViewsToRemoveById
        delete @markerViews[id]
        markerView.remove()

      editor.requestDisplayUpdate()

  destroyAllViews: ->
    @empty()
    @markerViews = {}
