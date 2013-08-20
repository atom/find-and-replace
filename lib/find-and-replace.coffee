SearchModel = require './search-model'
BufferFindAndReplaceView = require './buffer/buffer-find-and-replace-view'

module.exports =
  activate: (state) -> 
    @activateForBuffer(state?.buffer)

  deactivate: ->
    @deactivateForBuffer()

  serialize: ->
    buffer: @bufferFindAndReplaceSearchModel.serialize()

  activateForBuffer: (bufferFindAndReplaceState={}) ->
    history = bufferFindAndReplaceState?.history ? []
    options = bufferFindAndReplaceState.options
    options ?=
      regex: false
      inWord: false
      inSelection: false
      caseSensitive: false

    @bufferFindAndReplaceSearchModel = new SearchModel(options, history)
    @bufferFindAndReplaceView = new BufferFindAndReplaceView(@bufferFindAndReplaceSearchModel)

  deactivateForBuffer: ->
    @bufferFindAndReplaceView?.remove()
