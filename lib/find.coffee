FindModel = require './find-model'
FindView = require './find-view'
ProjectFindView = require './project-find-view'
{_, $$} = require 'atom'

module.exports =
  activate: ({viewState, projectViewState}={}) ->
    @projectFindView = new ProjectFindView(projectViewState)
    @findView = new FindView(viewState)
    rootView.vertical.append($$ -> @div class: 'find-and-replace-container')

  deactivate: ->
    @findView.remove()
    @findView = null

    @projectFindView.remove()
    @projectFindView = null

  serialize: ->
    viewState: @findView.serialize()
    projectViewState: @projectFindView.serialize()
