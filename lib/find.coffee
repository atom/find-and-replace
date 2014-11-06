{$} = require 'atom'
{Subscriber} = require 'emissary'

SelectNext = require './select-next'
{History} = require './history'
FindModel = require './find-model'
FindView = require './find-view'
ProjectFindView = require './project-find-view'
ResultsModel = require './project/results-model'
ResultsPaneView = require './project/results-pane'

module.exports =
  config:
    focusEditorAfterSearch:
      type: 'boolean'
      default: false
    openProjectFindResultsInRightPane:
      type: 'boolean'
      default: false

  activate: ({@viewState, @projectViewState, @resultsModelState, @modelState, findHistory, replaceHistory, pathsHistory}={}) ->
    atom.workspace.addOpener (filePath) =>
      new ResultsPaneView() if filePath is ResultsPaneView.URI

    @subscriber = new Subscriber()
    @findModel = new FindModel(@modelState)
    @resultsModel = new ResultsModel(@resultsModelState)
    @findHistory = new History(findHistory)
    @replaceHistory = new History(replaceHistory)
    @pathsHistory = new History(pathsHistory)

    @subscriber.subscribeToCommand atom.workspaceView, 'project-find:show', =>
      @createViews()
      @findPanel.hide()
      @projectFindPanel.show()
      @projectFindView.focusFindElement()

    @subscriber.subscribeToCommand atom.workspaceView, 'project-find:toggle', =>
      @createViews()
      @findPanel.hide()

      if @projectFindPanel.isVisible()
        @projectFindPanel.hide()
      else
        @projectFindPanel.show()

    @subscriber.subscribeToCommand atom.workspaceView, 'project-find:show-in-current-directory', ({target}) =>
      @createViews()
      @findPanel.hide()
      @projectFindPanel.show()
      @projectFindView.findInCurrentlySelectedDirectory(target)

    @subscriber.subscribeToCommand atom.workspaceView, 'find-and-replace:use-selection-as-find-pattern', =>
      return if @projectFindPanel?.isVisible() or @findPanel?.isVisible()

      @createViews()
      @projectFindPanel.hide()
      @findPanel.show()
      @findView.focusFindEditor()

    @subscriber.subscribeToCommand atom.workspaceView, 'find-and-replace:toggle', =>
      @createViews()
      @projectFindPanel.hide()

      if @findPanel.isVisible()
        @findPanel.hide()
      else
        @findPanel.show()
        @findView.focusFindEditor()

    @subscriber.subscribeToCommand atom.workspaceView, 'find-and-replace:show', =>
      @createViews()
      @projectFindPanel.hide()
      @findPanel.show()
      @findView.focusFindEditor()

    @subscriber.subscribeToCommand atom.workspaceView, 'find-and-replace:show-replace', =>
      @createViews()
      @projectFindPanel?.hide()
      @findPanel.show()
      @findView.focusReplaceEditor()

    # in code editors
    @subscriber.subscribeToCommand atom.workspaceView, 'core:cancel core:close', ({target}) =>
      if target isnt atom.workspaceView.getActivePaneView()?[0]
        $target = $(target)
        if $target.is('atom-text-editor')
          editor = $target
        else
          editor = $target.parents('.editor:not(.mini)')

        return unless editor.length

      @findPanel?.hide()
      @projectFindPanel?.hide()

    selectNextObjectForEditorElement = (editorElement) =>
      @selectNextObjects ?= new WeakMap()
      editor = $(editorElement).view().getModel()
      selectNext = @selectNextObjects.get(editor)
      unless selectNext?
        selectNext = new SelectNext(editor)
        @selectNextObjects.set(editor, selectNext)
      selectNext

    atom.commands.add '.editor:not(.mini)',
      'find-and-replace:select-next': (event) ->
        selectNextObjectForEditorElement(this).findAndSelectNext()
      'find-and-replace:select-all': (event) ->
        selectNextObjectForEditorElement(this).findAndSelectAll()
      'find-and-replace:select-undo': (event) ->
        selectNextObjectForEditorElement(this).undoLastSelection()
      'find-and-replace:select-skip': (event) ->
        selectNextObjectForEditorElement(this).skipCurrentSelection()

  createViews: ->
    return if @findView?

    history = {@findHistory, @replaceHistory, @pathsHistory}

    @findView = new FindView(@findModel, history)
    @projectFindView = new ProjectFindView(@findModel, @resultsModel, history)

    @findPanel = atom.workspace.addBottomPanel(item: @findView, visible: false, className: 'tool-panel panel-bottom')
    @projectFindPanel = atom.workspace.addBottomPanel(item: @projectFindView, visible: false, className: 'tool-panel panel-bottom')

    @findView.setPanel(@findPanel)
    @projectFindView.setPanel(@projectFindPanel)

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

  deactivate: ->
    @findPanel?.destroy()
    @findPanel = null
    @findView = null

    @findModel = null

    @projectFindPanel?.destroy()
    @projectFindPanel = null
    @projectFindView = null

    ResultsPaneView.model = null
    @resultsModel = null

    @subscriber?.unsubscribe()
    @subscriber = null

  serialize: ->
    viewState: @findView?.serialize() ? @viewState
    modelState: @findModel?.serialize() ? @modelState
    projectViewState: @projectFindView?.serialize() ? @projectViewState
    resultsModelState: @resultsModel?.serialize() ? @resultsModelState
    findHistory: @findHistory.serialize()
    replaceHistory: @replaceHistory.serialize()
    pathsHistory: @replaceHistory.serialize()
