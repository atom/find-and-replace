_ = require 'underscore-plus'
{ScrollView} = require 'atom-space-pen-views'
{Disposable, CompositeDisposable} = require 'atom'
ResultsView = require './results-view'
Util = require './util'

module.exports =
class ResultsPaneView extends ScrollView
  @URI: "atom://find-and-replace/project-results"

  @content: ->
    @div class: 'preview-pane pane-item', tabindex: -1, =>
      @div class: 'preview-header', =>
        @span outlet: 'previewCount', class: 'preview-count inline-block'
        @div outlet: 'previewControls', class: 'preview-controls', =>
          @div class: 'btn-group', =>
            @button outlet: 'collapseAll', class: 'btn'
            @button outlet: 'expandAll', class: 'btn'
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
    @onFinishedSearching(@model.getResultsSummary())
    @on 'focus', @focused

    @previewControls.hide()
    @collapseAll
      .text('Collapse All')
      .click(@collapseAllResults)
    @expandAll
      .text('Expand All')
      .click(@expandAllResults)

  attached: ->
    @model.setActive(true)
    @subscriptions = new CompositeDisposable
    @handleEvents()

  detached: ->
    @model.setActive(false)
    @subscriptions.dispose()

  copy: ->
    new ResultsPaneView()

  getPaneView: ->
    @parents('.pane').view()

  getTitle: ->
    "Project Find Results"

  # NOP to remove deprecation. This kind of sucks
  onDidChangeTitle: ->
    new Disposable()
  onDidChangeModified: ->
    new Disposable()

  getIconName: ->
    "search"

  getURI: ->
    @constructor.URI

  focused: =>
    @resultsView.focus()

  handleEvents: ->
    @subscriptions.add @model.onDidStartSearching @onSearch
    @subscriptions.add @model.onDidFinishSearching @onFinishedSearching
    @subscriptions.add @model.onDidClear @onCleared
    @subscriptions.add @model.onDidClearReplacementState @onReplacementStateCleared
    @subscriptions.add @model.onDidSearchPaths @onPathsSearched
    @subscriptions.add @model.onDidErrorForPath (error) => @appendError(error.message)

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

    hideLoadingMessage = => @loadingMessage.hide()

    deferred.then(hideLoadingMessage).catch(hideLoadingMessage)

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
      @previewControls.show()
      @removeClass('no-results')
    else
      @previewControls.hide()
      @addClass('no-results')

  collapseAllResults: =>
    @resultsView.collapseAllResults()
    @resultsView.focus()

  expandAllResults: =>
    @resultsView.expandAllResults()
    @resultsView.focus()
