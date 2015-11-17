fs = require 'fs-plus'
path = require 'path'
_ = require 'underscore-plus'
{Disposable, CompositeDisposable} = require 'atom'
{$, $$$, View, TextEditorView} = require 'atom-space-pen-views'

Util = require './project/util'
ResultsModel = require './project/results-model'
ResultsPaneView = require './project/results-pane'

buildTextEditor = require './build-text-editor'

module.exports =
class ProjectFindView extends View
  @content: (model, {findBuffer, replaceBuffer, pathsBuffer}) ->
    findEditor = buildTextEditor
      mini: true
      tabLength: 2
      softTabs: true
      softWrapped: false
      buffer: findBuffer
      placeholderText: 'Find in project'

    replaceEditor = buildTextEditor
      mini: true
      tabLength: 2
      softTabs: true
      softWrapped: false
      buffer: replaceBuffer
      placeholderText: 'Replace in project'

    pathsEditor = buildTextEditor
      mini: true
      tabLength: 2
      softTabs: true
      softWrapped: false
      buffer: pathsBuffer
      placeholderText: 'File/directory pattern. eg. `src` to search in the "src" directory or `*.js` to search all javascript files.'

    @div tabIndex: -1, class: 'project-find padded', =>
      @header class: 'header', =>
        @span outlet: 'descriptionLabel', class: 'header-item description'
        @span class: 'header-item options-label pull-right', =>
          @span 'Finding with Options: '
          @span outlet: 'optionsLabel', class: 'options'

      @section outlet: 'replacmentInfoBlock', class: 'input-block', =>
        @progress outlet: 'replacementProgress', class: 'inline-block'
        @span outlet: 'replacmentInfo', class: 'inline-block', 'Replaced 2 files of 10 files'

      @section class: 'input-block find-container', =>
        @div class: 'input-block-item input-block-item--flex editor-container', =>
          @subview 'findEditor', new TextEditorView(editor: findEditor)
        @div class: 'input-block-item', =>
          @div class: 'btn-group btn-group-find', =>
            @button outlet: 'findAllButton', class: 'btn', 'Find'
          @div class: 'btn-group btn-toggle btn-group-options', =>
            @button outlet: 'regexOptionButton', class: 'btn option-regex', =>
              @raw '<svg class="icon"><use xlink:href="#find-and-replace-icon-regex" /></svg>'
            @button outlet: 'caseOptionButton', class: 'btn option-case-sensitive', =>
              @raw '<svg class="icon"><use xlink:href="#find-and-replace-icon-case" /></svg>'
            @button outlet: 'wholeWordOptionButton', class: 'btn option-whole-word', =>
              @raw '<svg class="icon"><use xlink:href="#find-and-replace-icon-word" /></svg>'

      @section class: 'input-block replace-container', =>
        @div class: 'input-block-item input-block-item--flex editor-container', =>
          @subview 'replaceEditor', new TextEditorView(editor: replaceEditor)
        @div class: 'input-block-item', =>
          @div class: 'btn-group btn-group-replace-all', =>
            @button outlet: 'replaceAllButton', class: 'btn disabled', 'Replace All'

      @section class: 'input-block paths-container', =>
        @div class: 'input-block-item editor-container', =>
          @subview 'pathsEditor', new TextEditorView(editor: pathsEditor)

  initialize: (@model, {@findHistoryCycler, @replaceHistoryCycler, @pathsHistoryCycler}) ->
    @subscriptions = new CompositeDisposable
    @handleEvents()

    @findHistoryCycler.addEditorElement(@findEditor.element)
    @replaceHistoryCycler.addEditorElement(@replaceEditor.element)
    @pathsHistoryCycler.addEditorElement(@pathsEditor.element)

    @onlyRunIfChanged = true

    @clearMessages()
    @updateOptionViews()

  destroy: ->
    @subscriptions?.dispose()
    @tooltipSubscriptions?.dispose()

  setPanel: (@panel) ->
    @subscriptions.add @panel.onDidChangeVisible (visible) =>
      if visible then @didShow() else @didHide()

  didShow: ->
    atom.views.getView(atom.workspace).classList.add('find-visible')
    return if @tooltipSubscriptions?

    @updateReplaceAllButtonEnablement()
    @tooltipSubscriptions = subs = new CompositeDisposable
    subs.add atom.tooltips.add @regexOptionButton,
      title: "Use Regex"
      keyBindingCommand: 'project-find:toggle-regex-option',
      keyBindingTarget: @findEditor.element

    subs.add atom.tooltips.add @caseOptionButton,
      title: "Match Case",
      keyBindingCommand: 'project-find:toggle-case-option',
      keyBindingTarget: @findEditor.element

    subs.add atom.tooltips.add @wholeWordOptionButton,
      title: "Whole Word",
      keyBindingCommand: 'project-find:toggle-whole-word-option',
      keyBindingTarget: @findEditor.element

    subs.add atom.tooltips.add @findAllButton,
      title: "Find All",
      keyBindingCommand: 'find-and-replace:search',
      keyBindingTarget: @findEditor.element

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

    @subscriptions.add atom.commands.add @element,
      'find-and-replace:focus-next': => @focusNextElement(1)
      'find-and-replace:focus-previous': => @focusNextElement(-1)
      'core:confirm': => @confirm()
      'core:close': => @panel?.hide()
      'core:cancel': => @panel?.hide()
      'project-find:confirm': => @confirm()
      'project-find:toggle-regex-option': => @toggleRegexOption()
      'project-find:toggle-case-option': => @toggleCaseOption()
      'project-find:toggle-whole-word-option': => @toggleWholeWordOption()
      'project-find:replace-all': => @replaceAll()

    updateInterfaceForSearching = =>
      @setInfoMessage('Searching...')

    updateInterfaceForResults = (results) =>
      return @panel?.hide() if atom.config.get('find-and-replace.closeFindPanelAfterSearch')
      if results.matchCount is 0 and results.findPattern is ''
        @clearMessages()
      else
        @generateResultsMessage(results)
      @updateReplaceAllButtonEnablement(results)

    resetInterface = =>
      @clearMessages()
      @updateReplaceAllButtonEnablement(null)

    @subscriptions.add @model.onDidClear(resetInterface)
    @subscriptions.add @model.onDidClearReplacementState(updateInterfaceForResults)
    @subscriptions.add @model.onDidStartSearching(updateInterfaceForSearching)
    @subscriptions.add @model.onDidFinishSearching(updateInterfaceForResults)
    @subscriptions.add @model.getFindOptions().onDidChange @updateOptionViews

    @on 'focus', (e) => @findEditor.focus()
    @regexOptionButton.click => @toggleRegexOption()
    @caseOptionButton.click => @toggleCaseOption()
    @wholeWordOptionButton.click => @toggleWholeWordOption()
    @replaceAllButton.on 'click', => @replaceAll()
    @findAllButton.on 'click', => @search()

    focusCallback = => @onlyRunIfChanged = false
    $(window).on 'focus', focusCallback
    @subscriptions.add new Disposable ->
      $(window).off 'focus', focusCallback

    @findEditor.getModel().getBuffer().onDidChange =>
      @updateReplaceAllButtonEnablement(@model.getResultsSummary())
    @handleEventsForReplace()

  handleEventsForReplace: ->
    @replaceEditor.getModel().getBuffer().onDidChange => @model.clearReplacementState()
    @replaceEditor.getModel().onDidStopChanging => @model.getFindOptions().set(replacePattern: @replaceEditor.getText())
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

  focusNextElement: (direction) ->
    elements = [@findEditor, @replaceEditor, @pathsEditor]
    focusedElement = _.find elements, (el) -> el.hasClass('is-focused')
    focusedIndex = elements.indexOf focusedElement

    focusedIndex = focusedIndex + direction
    focusedIndex = 0 if focusedIndex >= elements.length
    focusedIndex = elements.length - 1 if focusedIndex < 0
    elements[focusedIndex].focus()
    elements[focusedIndex].getModel?().selectAll()

  focusFindElement: ->
    selectedText = atom.workspace.getActiveTextEditor()?.getSelectedText?()
    if selectedText and selectedText.indexOf('\n') < 0
      selectedText = Util.escapeRegex(selectedText) if @model.getFindOptions().useRegex
      @findEditor.setText(selectedText)
    @findEditor.focus()
    @findEditor.getModel().selectAll()

  confirm: ->
    if @findEditor.getText().length is 0
      @model.clear()
      return

    @findHistoryCycler.store()
    @replaceHistoryCycler.store()
    @pathsHistoryCycler.store()

    searchPromise = @search({@onlyRunIfChanged})
    @onlyRunIfChanged = true
    searchPromise

  search: (options={}) ->
    # We always want to set the options passed in, even if we dont end up doing the search
    @model.getFindOptions().set(options)

    findPattern = @findEditor.getText()
    pathsPattern = @pathsEditor.getText()
    replacePattern = @replaceEditor.getText()

    {onlyRunIfActive, onlyRunIfChanged} = options
    return Promise.resolve() if (onlyRunIfActive and not @model.active) or not findPattern

    @showResultPane().then =>
      try
        @model.search(findPattern, pathsPattern, replacePattern, options)
      catch e
        @setErrorMessage(e.message)

  replaceAll: ->
    return atom.beep() unless @model.matchCount
    findPattern = @model.getLastFindPattern()
    currentPattern = @findEditor.getText()
    if findPattern and findPattern isnt currentPattern
      atom.confirm
        message: "The searched pattern '#{findPattern}' was changed to '#{currentPattern}'"
        detailedMessage: "Please run the search with the new pattern '#{currentPattern}' before running a replace-all"
        buttons: ['OK']
      return

    @showResultPane().then =>
      pathsPattern = @pathsEditor.getText()
      replacePattern = @replaceEditor.getText()

      message = "This will replace '#{findPattern}' with '#{replacePattern}' #{_.pluralize(@model.matchCount, 'time')} in #{_.pluralize(@model.pathCount, 'file')}"
      buttonChosen = atom.confirm
        message: 'Are you sure you want to replace all?'
        detailedMessage: message
        buttons: ['OK', 'Cancel']

      if buttonChosen is 0
        @clearMessages()
        @model.replace(pathsPattern, replacePattern, @model.getPaths())

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
      [rootPath, relPath] = atom.project.relativizePath(absPath)
      if rootPath? and atom.project.getDirectories().length > 1
        relPath = path.join(path.basename(rootPath), relPath)
      @pathsEditor.setText(relPath)
      @findEditor.focus()
      @findEditor.getModel().selectAll()

  showResultPane: ->
    options = {searchAllPanes: true}
    switch atom.config.get('find-and-replace.openProjectFindResultsInANewPane')
      when 'right pane' then options.split = 'right'
      when 'bottom pane' then options.split = 'down'
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

  updateReplaceAllButtonEnablement: (results) ->
    canReplace = results?.matchCount and results?.findPattern is @findEditor.getText()
    return if canReplace and not @replaceAllButton[0].classList.contains('disabled')

    @replaceTooltipSubscriptions?.dispose()
    @replaceTooltipSubscriptions = new CompositeDisposable

    if canReplace
      @replaceAllButton[0].classList.remove('disabled')
      @replaceTooltipSubscriptions.add atom.tooltips.add @replaceAllButton,
        title: "Replace All",
        keyBindingCommand: 'project-find:replace-all',
        keyBindingTarget: @replaceEditor.element
    else
      @replaceAllButton[0].classList.add('disabled')
      @replaceTooltipSubscriptions.add atom.tooltips.add @replaceAllButton,
        title: "Replace All [run a search to enable]"

  setSelectionAsFindPattern: =>
    editor = atom.workspace.getActivePaneItem()
    if editor?.getSelectedText?
      pattern = editor.getSelectedText() or editor.getWordUnderCursor()
      pattern = Util.escapeRegex(pattern) if @model.getFindOptions().useRegex
      @findEditor.setText(pattern) if pattern

  updateOptionViews: =>
    @updateOptionButtons()
    @updateOptionsLabel()
    @updateSyntaxHighlighting()

  updateSyntaxHighlighting: ->
    if @model.getFindOptions().useRegex
      @findEditor.getModel().setGrammar(atom.grammars.grammarForScopeName('source.js.regexp'))
      @replaceEditor.getModel().setGrammar(atom.grammars.grammarForScopeName('source.js.regexp.replacement'))
    else
      @findEditor.getModel().setGrammar(atom.grammars.nullGrammar)
      @replaceEditor.getModel().setGrammar(atom.grammars.nullGrammar)

  updateOptionsLabel: ->
    label = []
    label.push('Regex') if @model.getFindOptions().useRegex
    if @model.getFindOptions().caseSensitive
      label.push('Case Sensitive')
    else
      label.push('Case Insensitive')
    label.push('Whole Word') if @model.getFindOptions().wholeWord
    @optionsLabel.text(label.join(', '))

  updateOptionButtons: ->
    @setOptionButtonState(@regexOptionButton, @model.getFindOptions().useRegex)
    @setOptionButtonState(@caseOptionButton, @model.getFindOptions().caseSensitive)
    @setOptionButtonState(@wholeWordOptionButton, @model.getFindOptions().wholeWord)

  setOptionButtonState: (optionButton, selected) ->
    if selected
      optionButton.addClass 'selected'
    else
      optionButton.removeClass 'selected'

  toggleRegexOption: ->
    @search(onlyRunIfActive: true, useRegex: not @model.getFindOptions().useRegex)

  toggleCaseOption: ->
    @search(onlyRunIfActive: true, caseSensitive: not @model.getFindOptions().caseSensitive)

  toggleWholeWordOption: ->
    @search(onlyRunIfActive: true, wholeWord: not @model.getFindOptions().wholeWord)
