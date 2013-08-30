FindModel = require './find-model'
FindView = require './find-view'
# ProjectFindAndReplaceView = require './project/project-find-and-replace-view'

module.exports =
  activate: (state) ->
    @activateForBuffer(state?.buffer)
    # @activateForProject(state?.project)

  deactivate: ->
    @deactivateForBuffer()
    # @deactivateForProject()

  serialize: ->
    buffer: @findModel.serialize()
    # project: @projectFindAndReplaceSearchModel.serialize()

  activateForBuffer: (findState={}) ->
    history = findState?.history ? []
    options = findState.options
    options ?=
      regex: false
      inWord: false
      inSelection: false
      caseSensitive: false

    @findModel = new FindModel(options)
    @findView = new FindView(@findModel, history)

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

    @projectFindAndReplaceSearchModel = new FindModel(options, history)
    @projectFindAndReplaceView = new ProjectFindAndReplaceView(project, @projectFindAndReplaceSearchModel)

  deactivateForProject: ->
    @projectFindAndReplaceView?.destroy()
