FindModel = require './find-model'
FindView = require './find-view'
ProjectFindView = require './project-find-view'
_ = require 'underscore'

module.exports =
  activate: ({viewState, modelState}={}) ->
    @projectFindView = new ProjectFindView()
    @findModel = new FindModel(modelState)
    @findView = new FindView(@findModel, viewState)

  deactivate: ->
    @findView.remove()
    @findView = null

    @projectFindView.remove()
    @projectFindView = null

    @findModel = null

  serialize: ->
    viewState: @findView.serialize()
    modelState: @findModel.serialize()
