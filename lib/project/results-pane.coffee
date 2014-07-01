_ = require 'underscore-plus'
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

      @ul outlet: 'errorList', class: 'error-list list-group padded'

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
    @subscribe @model, 'path-error', (error) => @appendError(error.message)

  setErrors: (messages) ->
    if messages? and messages.length
      @errorList.html('')
      @appendError(message) for message in messages
    else
      @clearErrors()
    return

  appendError: (message) ->
    @errorList.append("<li class=\"text-error\">#{Util.escapeHtml(message)}</li>")
    @errorList.show()

  clearErrors: ->
    @errorList.html('').hide()

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

    if results.searchErrors? or results.replacementErrors?
      errors = _.pluck(results.replacementErrors, 'message')
      errors = errors.concat _.pluck(results.searchErrors, 'message')
      @setErrors(errors)
    else
      @clearErrors()

  onReplacementStateCleared: (results) =>
    @hideOrShowNoResults(results)
    @previewCount.html(Util.getSearchResultsMessage(results))
    @clearErrors()

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
