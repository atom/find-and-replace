SearchModel = require './search-model'
BufferFindAndReplaceView = require './buffer/buffer-find-and-replace-view'

module.exports =
  activate: (state) -> 
    options = state?.options
    options ?=
      regex: false
      caseSensitive: false
      inWord: false
      inSelection: false

    @searchModel = new SearchModel(options, state?.history ? [])
    @view = new BufferFindAndReplaceView(@searchModel)

  deactivate: ->
    @view?.remove()

  serialize: ->
    @searchModel.serialize()
