fs = require 'fs-plus'
Q = require 'q'
_ = require 'underscore-plus'
{Disposable, CompositeDisposable} = require 'atom'
{$, $$$, View, TextEditorView} = require 'atom-space-pen-views'

{HistoryCycler} = require './history'
Util = require './project/util'
ResultsModel = require './project/results-model'
ResultsPaneView = require './project/results-pane'

module.exports =
class ProjectFindView extends View
  @content: ->
    @div tabIndex: -1, class: 'project-find padded', =>
      @div class: 'block', =>
        @span outlet: 'descriptionLabel', class: 'description'
        @span class: 'options-label pull-right', =>
          @span 'Finding with Options: '
          @span outlet: 'optionsLabel', class: 'options'

      @div outlet: 'replacmentInfoBlock', class: 'block', =>
        @progress outlet: 'replacementProgress', class: 'inline-block'
        @span outlet: 'replacmentInfo', class: 'inline-block', 'Replaced 2 files of 10 files'

      @div class: 'find-container block', =>
        @div class: 'editor-container', =>
          @subview 'findEditor', new TextEditorView(mini: true, placeholderText: 'Find in project')

        @div class: 'btn-group btn-toggle btn-group-options', =>
          @button outlet: 'regexOptionButton', class: 'btn option-regex', '.*'
          @button outlet: 'caseOptionButton', class: 'btn option-case-sensitive', 'Aa'

      @div class: 'replace-container block', =>
        @div class: 'editor-container', =>
          @subview 'replaceEditor', new TextEditorView(mini: true, placeholderText: 'Replace in project')

        @div class: 'btn-group btn-group-replace-all', =>
          @button outlet: 'replaceAllButton', class: 'btn', 'Replace All'

      @div class: 'paths-container block', =>
        @div class: 'editor-container', =>
          @subview 'pathsEditor', new TextEditorView(mini: true, placeholderText: 'File/directory pattern. eg. `src` to search in the "src" directory or `*.js` to search all javascript files.')

  initialize: (@findInBufferModel, @model, {findHistory, replaceHistory, pathsHistory}) ->
    @subscriptions = new CompositeDisposable
    @handleEvents()
    @findHistory = new HistoryCycler(@findEditor, findHistory)
    @replaceHistory = new HistoryCycler(@replaceEditor, replaceHistory)
    @pathsHistory = new HistoryCycler(@pathsEditor, pathsHistory)
    @onlyRunIfChanged = true

    @regexOptionButton.addClass('selected') if @model.useRegex
    @caseOptionButton.addClass('selected') if @model.caseSensitive

    @clearMessages()
    @updateOptionsLabel()

  destroy: ->
    @subscriptions?.dispose()
    @tooltipSubscriptions?.dispose()

  setPanel: (@panel) ->
    @subscriptions.add @panel.onDidChangeVisible (visible) =>
      if visible then @didShow() else @didHide()

  didShow: ->
    atom.views.getView(atom.workspace).classList.add('find-visible')
    return if @tooltipSubscriptions?

    @tooltipSubscriptions = subs = new CompositeDisposable
    subs.add atom.tooltips.add @regexOptionButton,
      title: "Use Regex"
      keyBindingCommand: 'project-find:toggle-regex-option',
      keyBindingTarget: @findEditor[0]

    subs.add atom.tooltips.add @caseOptionButton,
      title: "Match Case",
      keyBindingCommand: 'project-find:toggle-case-option',
      keyBindingTarget: @findEditor[0]

    subs.add atom.tooltips.add @replaceAllButton,
      title: "Replace All",
      keyBindingCommand: 'project-find:replace-all',
      keyBindingTarget: @replaceEditor[0]

  didHide: ->
    @hideAllTooltips()
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.focus()
    workspaceElement.classList.remove('find-visible')

  hideAllTooltips: ->
    @tooltipSubscriptions.dispose()
    @tooltipSubscriptions = null

  handleEvents: ->
    @subscriptions.add atom.commands.add 'atom-workspace',
      'find-and-replace:use-selection-as-find-pattern': @setSelectionAsFindPattern

    @subscriptions.add atom.commands.add this[0],
      'find-and-replace:focus-next': => @focusNextElement(1)
      'find-and-replace:focus-previous': => @focusNextElement(-1)
      'core:confirm': => @confirm()
      'core:close': => @panel?.hide()
      'core:cancel': => @panel?.hide()
      'project-find:confirm': => @confirm()
      'project-find:toggle-regex-option': => @toggleRegexOption()
      'project-find:toggle-case-option': => @toggleCaseOption()
      'project-find:replace-all': => @replaceAll()

    @subscriptions.add @model.onDidClear => @clearMessages()
    @subscriptions.add @model.onDidClearReplacementState (results) => @generateResultsMessage(results)
    @subscriptions.add @model.onDidFinishSearching (results) => @generateResultsMessage(results)

    @on 'focus', (e) => @findEditor.focus()
    @regexOptionButton.click => @toggleRegexOption()
    @caseOptionButton.click => @toggleCaseOption()
    @replaceAllButton.on 'click', => @replaceAll()

    focusCallback = => @onlyRunIfChanged = false
    $(window).on 'focus', focusCallback
    @subscriptions.add new Disposable ->
      $(window).off 'focus', focusCallback

    @handleEventsForReplace()

  handleEventsForReplace: ->
    @replaceEditor.getModel().getBuffer().onDidChange => @model.clearReplacementState()
    @replaceEditor.getModel().onDidStopChanging => @model.updateReplacementPattern(@replaceEditor.getText())
    @replacementsMade = 0
    @subscriptions.add @model.onDidStartReplacing (promise) =>
      @replacementsMade = 0
      @replacmentInfoBlock.show()
      @replacementProgress.removeAttr('value')

    @subscriptions.add @model.onDidReplacePath (result) =>
      @replacementsMade++
      @replacementProgress[0].value = @replacementsMade / @model.getPathCount()
      @replacmentInfo.text("Replaced #{@replacementsMade} of #{_.pluralize(@model.getPathCount(), 'file')}")

    @subscriptions.add @model.onDidFinishReplacing (result) => @onFinishedReplacing(result)

  toggleRegexOption: ->
    @model.toggleUseRegex()
    if @model.useRegex then @regexOptionButton.addClass('selected') else @regexOptionButton.removeClass('selected')
    @updateOptionsLabel()
    @search(onlyRunIfActive: true)

  toggleCaseOption: ->
    @model.toggleCaseSensitive()
    if @model.caseSensitive then @caseOptionButton.addClass('selected') else @caseOptionButton.removeClass('selected')
    @updateOptionsLabel()
    @search(onlyRunIfActive: true)

  focusNextElement: (direction) ->
    elements = [@findEditor, @replaceEditor, @pathsEditor].filter (el) -> el.has(':visible').length > 0
    focusedElement = _.find elements, (el) -> el.has(':focus').length > 0 or el.is(':focus')
    focusedIndex = elements.indexOf focusedElement

    focusedIndex = focusedIndex + direction
    focusedIndex = 0 if focusedIndex >= elements.length
    focusedIndex = elements.length - 1 if focusedIndex < 0
    elements[focusedIndex].focus()
    elements[focusedIndex].getModel?().selectAll()

  focusFindElement: ->
    selectedText = atom.workspace.getActiveEditor()?.getSelectedText?()
    @findEditor.setText(selectedText) if selectedText and selectedText.indexOf('\n') < 0
    @findEditor.focus()
    @findEditor.getModel().selectAll()

  confirm: ->
    if @findEditor.getText().length == 0
      @model.clear()
      return

    @findHistory.store()
    @replaceHistory.store()
    @pathsHistory.store()

    searchPromise = @search({@onlyRunIfChanged})
    @onlyRunIfChanged = true
    searchPromise

  search: ({onlyRunIfActive, onlyRunIfChanged}={}) ->
    return Q() if onlyRunIfActive and not @model.active

    pattern = @findEditor.getText()
    @findInBufferModel.update {pattern}

    @clearMessages()
    @showResultPane().then =>
      try
        @model.search(pattern, @getPaths(), @replaceEditor.getText(), {onlyRunIfChanged})
      catch e
        @setErrorMessage(e.message)

  replaceAll: ->
    @clearMessages()
    @showResultPane().then =>
      pattern = @findEditor.getText()
      replacementPattern = @replaceEditor.getText()

      @model.search(pattern, @getPaths(), replacementPattern, onlyRunIfChanged: true).then =>
        @clearMessages()
        @model.replace(pattern, @getPaths(), replacementPattern, @model.getPaths())

  getPaths: ->
    path.trim() for path in @pathsEditor.getText().trim().split(',') when path

  directoryPathForElement: (element) ->
    elementPath = element?.dataset.path ? element?.querySelector('[data-path]')?.dataset.path

    # Traverse up the DOM if the element and its children don't have a path
    unless elementPath
      while element?
        elementPath = element.dataset.path
        break if elementPath
        element = element.parentElement

    if fs.isFileSync(elementPath)
      require('path').dirname(elementPath)
    else
      elementPath

  findInCurrentlySelectedDirectory: (selectedElement) ->
    if absPath = @directoryPathForElement(selectedElement)
      relPath = atom.project.relativize(absPath)
      @pathsEditor.setText(relPath)

  showResultPane: ->
    options = null
    options = {split: 'right'} if atom.config.get('find-and-replace.openProjectFindResultsInRightPane')
    atom.workspace.open(ResultsPaneView.URI, options)

  onFinishedReplacing: (results) ->
    atom.beep() unless results.replacedPathCount
    @replacmentInfoBlock.hide()

  generateResultsMessage: (results) =>
    message = Util.getSearchResultsMessage(results)
    message = Util.getReplacementResultsMessage(results) if results.replacedPathCount?
    @setInfoMessage(message)

  clearMessages: ->
    @setInfoMessage('Find in Project <span class="subtle-info-message">Close this panel with the <span class="highlight">esc</span> key</span>').removeClass('text-error')
    @replacmentInfoBlock.hide()

  setInfoMessage: (infoMessage) ->
    @descriptionLabel.html(infoMessage).removeClass('text-error')

  setErrorMessage: (errorMessage) ->
    @descriptionLabel.html(errorMessage).addClass('text-error')

  updateOptionsLabel: ->
    label = []
    label.push('Regex') if @model.useRegex
    if @model.caseSensitive
      label.push('Case Sensitive')
    else
      label.push('Case Insensitive')
    @optionsLabel.text(label.join(', '))

  setSelectionAsFindPattern: =>
    editor = atom.workspace.getActivePaneItem()
    if editor?.getSelectedText?
      pattern = editor.getSelectedText()
      @findEditor.setText(pattern)
