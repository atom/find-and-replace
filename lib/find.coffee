FindModel = require './find-model'
FindView = require './find-view'
ProjectFindView = require './project-find-view'
ResultsModel = require './project/results-model'
ResultsPaneView = require './project/results-pane'
{_, $, $$} = require 'atom'

module.exports =
  configDefaults:
    openProjectFindResultsInRightPane: false

  activate: ({viewState, projectViewState, resultsModelState, paneViewState}={}) ->
    @resultsModel = new ResultsModel(resultsModelState)
    @projectFindView = new ProjectFindView(@resultsModel, projectViewState)
    @findView = new FindView(viewState)

    # HACK: Soooo, we need to get the model to the pane view whenever it is
    # created. Creation could come from the opener below, or, more problematic,
    # from a deserialize call when splitting panes. For now, all pane views will
    # use this same model. This needs to be improved! I dont know the best way
    # to deal with this:
    # 1. How should serialization work in the case of a shared model.
    # 2. Or maybe we create the model each time a new pane is created? Then
    #    ProjectFindView needs to know about each model so it can invoke a search.
    #    And on each new model, it will run the search again.
    #
    # See https://github.com/atom/find-and-replace/issues/63
    ResultsPaneView.model = @resultsModel

    project.registerOpener (filePath) =>
      new ResultsPaneView() if filePath is ResultsPaneView.URI

    rootView.command 'project-find:show', =>
      @findView.detach()
      @projectFindView.attach()

    rootView.command 'find-and-replace:show', =>
      @projectFindView.detach()
      @findView.showFind()

    rootView.command 'find-and-replace:show-replace', =>
      @projectFindView.detach()
      @findView.showReplace()

    @findView.on 'core:cancel core:close', =>
      @findView.detach()

    @projectFindView.on 'core:cancel core:close', =>
      @projectFindView.detach()

    # in code editors
    rootView.on 'core:cancel core:close', (event) =>
      target = $(event.target)
      editor = target.parents('.editor:not(.mini)')
      return unless editor.length

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
