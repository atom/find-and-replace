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
    debouncedUpdate = _.debounce(@markersUpdated, 20)
    @subscribe @findModel, 'updated', =>
      if @getEditor()?.hasClass('react')
        # HACK: there are some issues with some of the react editor's components
        # being not available. We shouldnt be doing this rendering anyway.
        # Marker views are coming.
        debouncedUpdate()
      else
        @markersUpdated()

  attach: ->
    # It must be detached from a destroyed pane before destruction otherwise
    # this view will be removed and @unsubscribe() will be called.
    pane = @getPane()
    @paneDestroySubscription = @subscribe pane, 'pane:before-item-destroyed', => @detach() if pane?

    editor = @getEditor()
    if editor? and editor.underlayer?
      editor.underlayer.append(this)
    else if editor?
      subscription = @subscribe editor, 'editor:attached', =>
        subscription.off()
        editor.underlayer.append(this)

  detach: ->
    @paneDestroySubscription?.off()
    super

  beforeRemove: ->
    @destroyAllViews()

  getEditor: ->
    activeView = atom.workspaceView.getActiveView()
    if activeView?.hasClass('editor') then activeView else null

  getPane: ->
    atom.workspaceView.getActivePane()

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
