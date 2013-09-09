FindModel = require './find-model'
FindView = require './find-view'
_ = require 'underscore'

module.exports =
  activate: ({findHistory, replaceHistory, findOptions}={}) ->
    @findModel = new FindModel(findOptions)
    @findView = new FindView(@findModel, {findHistory, replaceHistory})

  deactivate: ->
    @findView?.remove()
    @findView = null
    @findModel = null

  serialize: ->
    result = @findView.serialize()
    result.findOptions = @findModel.serialize()
    result
