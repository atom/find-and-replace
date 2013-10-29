FindModel = require './find-model'
FindView = require './find-view'
ProjectFindView = require './project-find-view'
ResultsPaneView = require './project/results-pane'
{_, $$} = require 'atom'

module.exports =
  activate: ({viewState, projectViewState}={}) ->
    @projectFindView = new ProjectFindView(projectViewState)
    @findView = new FindView(viewState)

    project.registerOpener (filePath) ->
      if filePath is ResultsPaneView.URI
        new ResultsPaneView({})
      else
        null

    rootView.command 'project-find:show', =>
      @findView.detach()
      @projectFindView.attach()

    rootView.command 'find-and-replace:show', =>
      @projectFindView.detach()
      @findView.showFind()

    rootView.command 'find-and-replace:show-replace', =>
      @projectFindView.detach()
      @findView.showReplace()

    rootView.on 'core:cancel core:close', =>
      @findView.detach()
      @projectFindView.detach()

  deactivate: ->
    @findView.remove()
    @findView = null

    @projectFindView.remove()
    @projectFindView = null

  serialize: ->
    viewState: @findView.serialize()
    projectViewState: @projectFindView.serialize()
