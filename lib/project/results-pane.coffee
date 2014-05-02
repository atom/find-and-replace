{ScrollView} = require 'atom'
ResultsView = require './results-view'
Util = require './util'

module.exports =
class ResultsPaneView extends ScrollView
  @URI: "atom://find-and-replace/project-results"

  @content: ->
    @div class: 'preview-pane pane-item', =>
      @div class: 'panel-heading', =>
        @span outlet: 'previewCount', class: 'preview-count inline-block'
        @div outlet: 'loadingMessage', class: 'inline-block', =>
          @div class: 'loading loading-spinner-tiny inline-block'
          @div outlet: 'searchedCountBlock', class: 'inline-block', =>
            @span outlet: 'searchedCount', class: 'searched-count'
            @span ' paths searched'

      @subview 'resultsView', new ResultsView(@model)
      @ul class: 'centered background-message no-results-overlay', =>
        @li 'No Results'

  initialize: ->
    super
    @loadingMessage.hide()

    @model = @constructor.model
    @model.setActive(true)

    @handleEvents()
    @onFinishedSearching(@model.getResultsSummary())

  beforeRemove: ->
    @model.setActive(false)

  copy: ->
    new ResultsPaneView()

  getPane: ->
    @parents('.pane').view()

  getTitle: ->
    "Project Find Results"

  getIconName: ->
    "search"

  getUri: ->
    @constructor.URI

  focus: ->
    @resultsView.focus()

  handleEvents: ->
    @subscribe @model, 'search', @onSearch
    @subscribe @model, 'cleared', @onCleared
    @subscribe @model, 'replacement-state-cleared', @onReplacementStateCleared
    @subscribe @model, 'finished-searching', @onFinishedSearching
    @subscribe @model, 'paths-searched', @onPathsSearched

  onSearch: (deferred) =>
    @loadingMessage.show()

    @previewCount.text('Searching...')
    @searchedCount.text('0')
    @searchedCountBlock.hide()
    @removeClass('no-results')

    @previewCount.show()

    # We'll only show the paths searched message after 500ms. It's too fast to
    # see on short searches, and slows them down.
    @showSearchedCountBlock = false
    timeout = setTimeout =>
      @searchedCountBlock.show()
      @showSearchedCountBlock = true
    , 500

    deferred.done =>
      @loadingMessage.hide()

  onPathsSearched: (numberOfPathsSearched) =>
    if @showSearchedCountBlock
      @searchedCount.text(numberOfPathsSearched)

  onFinishedSearching: (results) =>
    @hideOrShowNoResults(results)
    @previewCount.html(Util.getSearchResultsMessage(results))

  onReplacementStateCleared: (results) =>
    @hideOrShowNoResults(results)
    @previewCount.html(Util.getSearchResultsMessage(results))

  onCleared: =>
    @addClass('no-results')
    @previewCount.text('Find in project results')
    @loadingMessage.hide()
    @searchedCountBlock.hide()

  hideOrShowNoResults: (results) ->
    if results.pathCount
      @removeClass('no-results')
    else
      @addClass('no-results')
