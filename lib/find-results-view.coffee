_ = require 'underscore-plus'
{EditorView, View} = require 'atom'
MarkerView = require './marker-view'

# TODO: remove this when marker views are in core. Hopefully soon.

module.exports =
class FindResultsView extends View

  @content: ->
    @div class: 'search-results'

  initialize: (@findModel) ->
    @markerViews = {}
    @subscribe @findModel, 'updated', @markersUpdated

  attach: ->
    # It must be detached from a destroyed pane before destruction otherwise
    # this view will be removed and @unsubscribe() will be called.
    pane = @getPane()
    @paneDestroySubscription = @subscribe pane, 'pane:before-item-destroyed', => @detach() if pane?

    editor = @getEditor()
    editor?.underlayer.append(this)

  detach: ->
    @paneDestroySubscription?.off()
    super

  beforeRemove: ->
    @destroyAllViews()

  getEditor: ->
    activeView = atom.workspaceView.getActiveView()
    if activeView?.hasClass('editor') and not activeView?.hasClass('react') then activeView else null

  getPane: ->
    atom.workspaceView.getActivePaneView()

  markersUpdated: =>
    editor = @getEditor()
    markers = @findModel.markers

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
