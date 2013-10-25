{_, $, $$$, Editor, ScrollView} = require 'atom'
ResultsView = require './results-view'

module.exports =
class ResultsPaneView extends ScrollView
  registerDeserializer(this)

  @URI: "atom://find-and-replace/project-results"

  @deserialize: (state) ->
    new ResultsPaneView(state)

  @content: ->
    @div class: 'preview-panel', =>
      @div class: 'panel-heading', =>
        @span outlet: 'previewCount', class: 'preview-count inline-block'
        @div outlet: 'loadingMessage', class: 'inline-block', =>
          @div class: 'loading loading-spinner-tiny inline-block'
          @div outlet: 'searchedCountBlock', class: 'inline-block', =>
            @span outlet: 'searchedCount', class: 'searched-count'
            @span ' paths searched'

      @subview 'resultsView', new ResultsView

  initialize: (state) ->
    super

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
