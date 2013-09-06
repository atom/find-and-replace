FindModel = require './find-model'
FindView = require './find-view'
_ = require 'underscore'

module.exports =
  activate: ({findHistory, replaceHistory, options}={}) ->
    @findModel = new FindModel(options)
    @findView = new FindView(@findModel, {findHistory, replaceHistory})

  deactivate: ->
    @findView?.remove()
    @findView = null
    @findModel = null

  serialize: ->
    result = {}
    _.extend result, @findModel.serialize(), @findView.serialize()
    result
