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

      @subview 'resultsView', new ResultsView

  initialize: ->
    super
    @loadingMessage.hide()
    @setModel(@constructor.model) if @constructor.model

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

  setModel: (@model) ->
    @resultsView.setModel(@model)
    @handleEvents()
    @onFinishedSearching()

  getResultCountText: ->
    if @resultsView.getPathCount() > 0
      "#{_.pluralize(@resultsView.getMatchCount(), 'match', 'matches')} in #{_.pluralize(@resultsView.getPathCount(), 'file')} for '#{@model.getPattern()}'"
    else
      "No matches found for '#{@model.getPattern()}'"

  handleEvents: ->
    @model.on 'search', @onSearch
    @model.on 'finished-searching', @onFinishedSearching
    @model.on 'paths-searched', @onPathsSearched

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
      @previewCount.text(@getResultCountText())

  onPathsSearched: (numberOfPathsSearched) =>
    if @showSearchedCountBlock
      @searchedCount.text(numberOfPathsSearched)

  onFinishedSearching: =>
    @previewCount.text(@getResultCountText())
