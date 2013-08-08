_ = require 'underscore'
{View} = require 'space-pen'
Selection = require 'selection'
MarkerView = require './marker-view'
SearchResultsModel = require './search-results-model'

# Will be one of these created per editor.
module.exports =
class SearchResultsView extends View

  @content: ->
    @div class: 'search-results'

  # options - 
  #   editor: an Atom Editor!
  initialize: (@searchModel, @editor) ->
    @model = new SearchResultsModel(@searchModel, @editor)
    @model.on 'change:markers', @addMarkerViews
    @model.on 'add:markers', @addMarkerViews

    @searchModel.on 'show:results', @onShowResults
    @searchModel.on 'hide:results', @onHideResults

    if @searchModel.resultsVisible
      @onShowResults()
    else
      @onHideResults()

  onHideResults: =>
    view.remove() for view in @markerViews if @markerViews
    @markerViews = []
    @hide()

  onShowResults: =>
    @addMarkerViews({markers: @model.markers})
    @show()

  addMarkerViews: ({markers}) =>
    return unless @searchModel.resultsVisible
    @markerViews = (new MarkerView({@editor, marker}) for marker in markers)
    @append(view) for view in @markerViews
    @editor.requestDisplayUpdate()
