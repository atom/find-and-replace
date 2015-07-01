{$} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'

SelectNext = require './select-next'
{History} = require './history'
BufferSearch = require './buffer-search'
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
    atom.workspace.addOpener (filePath) ->
      new ResultsPaneView() if filePath is ResultsPaneView.URI

    @subscriptions = new CompositeDisposable

    @findModel = new BufferSearch(@modelState)
    @subscriptions.add atom.workspace.observeActivePaneItem (paneItem) =>
      if paneItem?.getBuffer?()
        @findModel.setEditor(paneItem)
      else
        @findModel.setEditor(null)

    @resultsModel = new ResultsModel(@resultsModelState)
    @findHistory = new History(findHistory)
    @replaceHistory = new History(replaceHistory)
    @pathsHistory = new History(pathsHistory)

    @subscriptions.add atom.commands.add 'atom-workspace', 'project-find:show', =>
      @findPanel.hide()
      @projectFindPanel.show()
      @projectFindView.focusFindElement()

    @subscriptions.add atom.commands.add 'atom-workspace', 'project-find:toggle', =>
      @findPanel.hide()

      if @projectFindPanel.isVisible()
        @projectFindPanel.hide()
      else
        @projectFindPanel.show()

    @subscriptions.add atom.commands.add 'atom-workspace', 'project-find:show-in-current-directory', ({target}) =>
      @findPanel.hide()
      @projectFindPanel.show()
      @projectFindView.findInCurrentlySelectedDirectory(target)

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:use-selection-as-find-pattern', =>
      return if @projectFindPanel?.isVisible() or @findPanel?.isVisible()

      @projectFindPanel.hide()
      @findPanel.show()
      @findView.focusFindEditor()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:toggle', =>
      @projectFindPanel.hide()

      if @findPanel.isVisible()
        @findPanel.hide()
      else
        @findPanel.show()
        @findView.focusFindEditor()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:show', =>
      @projectFindPanel.hide()
      @findPanel.show()
      @findView.focusFindEditor()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:show-replace', =>
      @projectFindPanel?.hide()
      @findPanel.show()
      @findView.focusReplaceEditor()

    # Handling cancel in the workspace + code editors
    handleEditorCancel = ({target}) =>
      isMiniEditor = target.tagName is 'ATOM-TEXT-EDITOR' and target.hasAttribute('mini')
      unless isMiniEditor
        @findPanel?.hide()
        @projectFindPanel?.hide()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'core:cancel': handleEditorCancel
      'core:close': handleEditorCancel

    selectNextObjectForEditorElement = (editorElement) =>
      @selectNextObjects ?= new WeakMap()
      editor = editorElement.getModel()
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
    @createViews()

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
    @findView?.destroy()
    @findView = null
    @findModel?.destroy()
    @findModel = null

    @projectFindPanel?.destroy()
    @projectFindPanel = null
    @projectFindView?.destroy()
    @projectFindView = null

    ResultsPaneView.model = null
    @resultsModel = null

    @subscriptions?.dispose()
    @subscriptions = null

  serialize: ->
    viewState: @findView?.serialize() ? @viewState
    modelState: @findModel?.serialize() ? @modelState
    projectViewState: @projectFindView?.serialize() ? @projectViewState
    resultsModelState: @resultsModel?.serialize() ? @resultsModelState
    findHistory: @findHistory.serialize()
    replaceHistory: @replaceHistory.serialize()
    pathsHistory: @replaceHistory.serialize()
