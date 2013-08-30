SearchModel = require './search-model'
FindView = require './find-view'
ProjectFindAndReplaceView = require './project/project-find-and-replace-view'

module.exports =
  activate: (state) ->
    @activateForBuffer(state?.buffer)
    # @activateForProject(state?.project)

  deactivate: ->
    @deactivateForBuffer()
    # @deactivateForProject()

  serialize: ->
    buffer: @bufferFindAndReplaceSearchModel.serialize()
    # project: @projectFindAndReplaceSearchModel.serialize()

  activateForBuffer: (bufferFindAndReplaceState={}) ->
    history = bufferFindAndReplaceState?.history ? []
    options = bufferFindAndReplaceState.options
    options ?=
      regex: false
      inWord: false
      inSelection: false
      caseSensitive: false

    @bufferFindAndReplaceSearchModel = new SearchModel(options)
    @findView = new FindView(@bufferFindAndReplaceSearchModel, history)

  deactivateForBuffer: ->
    @findView?.remove()

  activateForProject: (projectFindAndReplaceState={}) ->
    history = projectFindAndReplaceState?.history ? []
    options = projectFindAndReplaceState.options
    options ?=
      regex: false
      inWord: false
      inSelection: false
      caseSensitive: false

    @projectFindAndReplaceSearchModel = new SearchModel(options, history)
    @projectFindAndReplaceView = new ProjectFindAndReplaceView(project, @projectFindAndReplaceSearchModel)

  deactivateForProject: ->
    @projectFindAndReplaceView?.destroy()
