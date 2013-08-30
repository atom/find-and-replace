FindModel = require './find-model'
FindView = require './find-view'

module.exports =
  activate: (state) ->
    history = findState?.history
    options = findState?.options

    @findModel = new FindModel(options)
    @findView = new FindView(@findModel, history)

  deactivate: ->
    @findView?.remove()

  serialize: ->
    @findModel.serialize()
