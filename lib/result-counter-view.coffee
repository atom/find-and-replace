{View} = require 'space-pen'

# Updates the result counter label inside the editor box.
module.exports =
class ResultCounterView extends View
  @content: ->  
    @span class: 'result-counter', ''

  initialize: ->

  setModel: (@model) ->
    @model.on 'active-editor-changed', (e, {editor}) =>
      @setResultsModel(editor?.searchResults or null)

  setResultsModel: (resultsModel) ->
    @unbindResultsModel(@resultsModel)
    @bindResultsModel(@resultsModel = resultsModel)
    @onChangeCurrentResult()

  onChangeCurrentResult: (currentResult) =>
    if @resultsModel
      currentResult = currentResult or @resultsModel.getCurrentResult()
      if currentResult.index?
        @text("#{currentResult.index+1} of #{currentResult.total}")
      else
        @text("#{currentResult.total} found") 
    else
      @text('')

  bindResultsModel: (resultsModel) ->
    return unless resultsModel
    resultsModel.on 'current-result-changed', @onChangeCurrentResult

  unbindResultsModel: (resultsModel) ->
    return unless resultsModel
    resultsModel.off 'current-result-changed', @onChangeCurrentResult
