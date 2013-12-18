{_, $, $$$, EditorView, ScrollView} = require 'atom'
ResultsView = require './results-view'

module.exports =
class ResultsPaneView extends ScrollView
  atom.deserializers.add(this)

  @URI: "atom://find-and-replace/project-results"

  @deserialize: (state) ->
    new ResultsPaneView()

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

  initialize: ->
    super
    @loadingMessage.hide()

    @model = @constructor.model
    @handleEvents()
    @onFinishedSearching(@model.getResultsSummary())

  getPane: ->
    @parent('.item-views').parent('.pane').view()

  serialize: ->
    deserializer: 'ResultsPaneView'

  getTitle: ->
    "Project Find Results"

  getUri: ->
    @constructor.URI

  focus: ->
    @resultsView.focus()

  handleEvents: ->
    @subscribe @model, 'search', @onSearch
    @subscribe @model, 'finished-searching', @onFinishedSearching
    @subscribe @model, 'paths-searched', @onPathsSearched

  onSearch: (deferred) =>
    @loadingMessage.show()

    @previewCount.text('Searching...')
    @searchedCount.text('0')
    @searchedCountBlock.hide()

    @previewCount.show()
    @resultsView.focus()

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

  onFinishedSearching: ({pattern, matchCount, pathCount, replacementPattern, pathsReplaced, replacements}) =>
    message = @getSearchResultsMessage(pattern, matchCount, pathCount)

    if pathsReplaced?
      replace = @getReplacementResultsMessage(pattern, replacementPattern, pathsReplaced, replacements)
      message = "<span class=\"text-highlight\">#{replace}.</span> #{message}"

    @previewCount.html(message)

  getReplacementResultsMessage: (pattern, replacementPattern, pathsReplaced, replacements) ->
    if pathsReplaced
      "Replaced <span class=\"highlight-error\">#{pattern}</span> with <span class=\"highlight-success\">#{replacementPattern}</span> #{_.pluralize(replacements, 'time')} in #{_.pluralize(pathsReplaced, 'file')}"
    else
      "Nothing replaced"

  getSearchResultsMessage: (pattern, matchCount, pathCount) ->
    if matchCount
      "#{_.pluralize(matchCount, 'result')} found in #{_.pluralize(pathCount, 'file')} for '#{pattern}'"
    else
      "No results found for '#{pattern}'"
