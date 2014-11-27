_ = require 'underscore-plus'
{ScrollView} = require 'atom'
{Disposable, CompositeDisposable} = require 'event-kit'
ResultsView = require './results-view'
Util = require './util'

module.exports =
class ResultsPaneView extends ScrollView
  @URI: "atom://find-and-replace/project-results"

  @content: ->
    @div class: 'preview-pane pane-item', tabindex: -1, =>
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
    @subscriptions = new CompositeDisposable
    @loadingMessage.hide()

    @model = @constructor.model
    @model.setActive(true)

    @handleEvents()
    @onFinishedSearching(@model.getResultsSummary())

    @on 'focus', @focused

  destroy: ->
    @model.setActive(false)
    @subscriptions.dispose()

  beforeRemove: -> @destroy()

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

  getUri: ->
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
