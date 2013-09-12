FindModel = require './find-model'
FindView = require './find-view'
_ = require 'underscore'

module.exports =
  activate: ({viewState, modelState}={}) ->
    @findModel = new FindModel(modelState)
    @findView = new FindView(@findModel, viewState)

  deactivate: ->
    @findView?.remove()
    @findView = null
    @findModel = null

  serialize: ->
    viewState: @findView.serialize()
    modelState: @findModel.serialize()
