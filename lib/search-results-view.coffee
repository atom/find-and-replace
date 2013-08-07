_ = require 'underscore'
{View} = require 'space-pen'
Selection = require 'selection'
SelectionView = require 'selection-view'
SearchResultsModel = require './search-results-model'

# Will be one of these created per editor.
module.exports =
class SearchResultsView extends View

  @content: ->
    @div class: 'search-results'

  # options - 
  #   editor: an Atom Editor!
  initialize: (@searchModel, @editor) ->
    @searchResults = []

    @model = new SearchResultsModel(@searchModel, @editor)
    @model.on 'change:markers', @onChangeMarkers

    @searchModel.on 'activate', => @show()
    @searchModel.on 'deactivate', => @hide()

    @editor.on 'editor:path-changed', @onPathChanged
    @onPathChanged()

    @hide()

  onChangeMarkers: ({markers}) =>
    @createMarkerViews(markers)

  onPathChanged: =>
    # will search and emit the change:markers event -> update the interface
    @model.setBuffer(@editor.activeEditSession.buffer)

  createMarkerViews: (markers) ->
    @deleteMarkerViews()
    @searchResults = (new SearchResultView(@editor, marker) for marker in markers)
    @append(result.selectionView) for result in @searchResults
    @searchResults

  deleteMarkerViews: ->
    result.destroy() for result in @searchResults
    @searchResults = []


class SearchResultView
  constructor: (@editor, @marker) ->
    @selection = new Selection(_.extend({editSession: @editor.activeEditSession, @marker}, @getMarkerAttributes()))
    @selectionView = new SelectionView({editor: @editor, @selection})

    @editor.on 'editor:display-updated', @onDisplayUpdated 

  destroy: ->
    @editor.off 'editor:display-updated', @onDisplayUpdated
    @selection.destroy()
    @selectionView.remove()

  onDisplayUpdated: =>
    _.nextTick =>
      @selectionView.updateDisplay()

  getMarkerAttributes: (attributes={}) ->
    _.extend attributes, 
      class: 'search-result'
      displayBufferId: @editor.activeEditSession.displayBuffer.id
      invalidationStratrgy: 'between'