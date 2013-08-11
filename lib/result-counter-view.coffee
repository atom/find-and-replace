{View} = require 'space-pen'

module.exports =
class ResultCounterView extends View
  @content: ->  
    @span class: 'result-counter', ''

  initialize: ->

  setModel: (@searchModel) ->
    @setResultsModel(@searchModel.getActiveResultsModel())
    @searchModel.on 'change:active-id', (model, {activeId}) =>
      @setResultsModel(@searchModel.getActiveResultsModel())

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
    resultsModel.on 'change:current-result', @onChangeCurrentResult

  unbindResultsModel: (resultsModel) ->
    return unless resultsModel
    resultsModel.off 'change:current-result', @onChangeCurrentResult
