FindModel = require './find-model'
FindView = require './find-view'
ProjectFindView = require './project-find-view'
ResultsModel = require './project/results-model'
ResultsPaneView = require './project/results-pane'
{_, $$} = require 'atom'

module.exports =
  activate: ({viewState, projectViewState, resultsModelState, paneViewState}={}) ->
    @resultsModel = new ResultsModel(resultsModelState)
    @projectFindView = new ProjectFindView(@resultsModel, projectViewState)
    @findView = new FindView(viewState)

    project.registerOpener (filePath) =>
      return null unless filePath is ResultsPaneView.URI
      state = paneViewState or {}
      new ResultsPaneView(state, @resultsModel)

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
    resultsModelState: @resultsModel.serialize()
