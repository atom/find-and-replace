{CompositeDisposable} = require 'atom'
ResultsPaneView = null

module.exports =
  config:
    focusEditorAfterSearch:
      type: 'boolean'
      default: false
    openProjectFindResultsInRightPane:
      type: 'boolean'
      default: false
    scrollToResultOnLiveSearch:
      type: 'boolean'
      default: false
      title: 'Scroll To Result On Live-Search (incremental find in buffer)'
      description: 'When you type in the buffer find box, the closest match will be selected and made visible in the editor.'
    liveSearchMinimumCharacters:
      type: 'integer'
      default: 3
      minimum: 0
      description: 'When you type in the buffer find box, you must type this many characters to automatically search'

  activate: (@state) ->
    {visiblePanel} = @state

    if visiblePanel?
      setImmediate =>
        @createViews()
        if visiblePanel is 'find'
          @findPanel.show()
        else if visiblePanel is 'project-find'
          @projectFindPanel.show()

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.workspace.observeActivePaneItem (paneItem) =>
      @createModels()
      if paneItem?.getBuffer?()
        @findModel.setEditor(paneItem)
      else
        @findModel.setEditor(null)

    @subscriptions.add atom.commands.add '.find-and-replace, .project-find', 'window:focus-next-pane', ->
      atom.views.getView(atom.workspace).focus()

    @subscriptions.add atom.commands.add 'atom-workspace', 'project-find:show', =>
      @createViews()
      @findPanel.hide()
      @projectFindPanel.show()
      @projectFindView.focusFindElement()

    @subscriptions.add atom.commands.add 'atom-workspace', 'project-find:toggle', =>
      @createViews()
      @findPanel.hide()

      if @projectFindPanel.isVisible()
        @projectFindPanel.hide()
      else
        @projectFindPanel.show()

    @subscriptions.add atom.commands.add 'atom-workspace', 'project-find:show-in-current-directory', ({target}) =>
      @createViews()
      @findPanel.hide()
      @projectFindPanel.show()
      @projectFindView.findInCurrentlySelectedDirectory(target)

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:use-selection-as-find-pattern', =>
      return if @projectFindPanel?.isVisible() or @findPanel?.isVisible()

      @createViews()
      @projectFindPanel.hide()
      @findPanel.show()
      @findView.focusFindEditor()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:toggle', =>
      @createViews()
      @projectFindPanel.hide()

      if @findPanel.isVisible()
        @findPanel.hide()
      else
        @findPanel.show()
        @findView.focusFindEditor()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:show', =>
      @createViews()
      @projectFindPanel.hide()
      @findPanel.show()
      @findView.focusFindEditor()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:show-replace', =>
      @createViews()
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
      @createModels()
      @selectNextObjects ?= new WeakMap()
      editor = editorElement.getModel()
      selectNext = @selectNextObjects.get(editor)
      unless selectNext?
        SelectNext = require './select-next'
        selectNext = new SelectNext(editor, {@findOptions})
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

  createModels: ->
    return if @findModel?

    {CompositeDisposable} = require 'atom'
    FindOptions = require './find-options'
    BufferSearch = require './buffer-search'
    ResultsModel = require './project/results-model'
    {History} = require './history'

    {findOptions, findHistory, replaceHistory, pathsHistory} = @state

    @findHistory = new History(findHistory)
    @replaceHistory = new History(replaceHistory)
    @pathsHistory = new History(pathsHistory)

    @findOptions = new FindOptions(findOptions)
    @findModel = new BufferSearch(@findOptions)
    @resultsModel = new ResultsModel(@findOptions)

  createViews: ->
    return if @findView?
    @createModels()

    atom.workspace.addOpener (filePath) ->
      ResultsPaneView ?= require './project/results-pane'
      new ResultsPaneView() if filePath is ResultsPaneView.URI

    {TextBuffer} = require 'atom'
    FindView = require './find-view'
    ProjectFindView = require './project-find-view'
    ResultsPaneView ?= require './project/results-pane'
    {HistoryCycler} = require './history'

    findBuffer = new TextBuffer(@findOptions.findPattern or '')
    replaceBuffer = new TextBuffer(@findOptions.replacePattern or '')
    pathsBuffer = new TextBuffer(@findOptions.pathsPattern or '')

    findHistoryCycler = new HistoryCycler(findBuffer, @findHistory)
    replaceHistoryCycler = new HistoryCycler(replaceBuffer, @replaceHistory)
    pathsHistoryCycler = new HistoryCycler(pathsBuffer, @pathsHistory)

    options = {findBuffer, replaceBuffer, pathsBuffer, findHistoryCycler, replaceHistoryCycler, pathsHistoryCycler}

    @findView = new FindView(@findModel, options)
    @projectFindView = new ProjectFindView(@resultsModel, options)

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
    visiblePanel = if @findPanel.isVisible()
      'find'
    else if @projectFindPanel.isVisible()
      'project-find'
    else
      null

    {
      findOptions: @findOptions.serialize()
      findHistory: @findHistory.serialize()
      replaceHistory: @replaceHistory.serialize()
      pathsHistory: @replaceHistory.serialize()
      visiblePanel: visiblePanel
    }
