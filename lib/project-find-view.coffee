Q = require 'q'
_ = require 'underscore-plus'
{$, $$$, EditorView, View} = require 'atom'

History = require './history'
Util = require './project/util'
ResultsModel = require './project/results-model'
ResultsPaneView = require './project/results-pane'

module.exports =
class ProjectFindView extends View
  @content: ->
    @div tabIndex: -1, class: 'project-find tool-panel panel-bottom padded', =>
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
          @subview 'findEditor', new EditorView(mini: true, placeholderText: 'Find in project')

        @div class: 'btn-group btn-toggle btn-group-options', =>
          @button outlet: 'regexOptionButton', class: 'btn option-regex', '.*'
          @button outlet: 'caseOptionButton', class: 'btn option-case-sensitive', 'Aa'

      @div class: 'replace-container block', =>
        @div class: 'editor-container', =>
          @subview 'replaceEditor', new EditorView(mini: true, placeholderText: 'Replace in project')

        @div class: 'btn-group btn-group-replace-all', =>
          @button outlet: 'replaceAllButton', class: 'btn', 'Replace All'

      @div class: 'paths-container block', =>
        @div class: 'editor-container', =>
          @subview 'pathsEditor', new EditorView(mini: true, placeholderText: 'File/directory pattern. eg. `src` to search in the "src" directory or `*.js` to search all javascript files.')

  initialize: (@model, {modelState, findHistory, replaceHistory, pathsHistory}={}) ->
    @handleEvents()
    @findHistory = new History(@findEditor, findHistory)
    @replaceHistory = new History(@replaceEditor, replaceHistory)
    @pathsHistory = new History(@pathsEditor, pathsHistory)
    @onlyRunIfChanged = true

    @regexOptionButton.addClass('selected') if @model.useRegex
    @caseOptionButton.addClass('selected') if @model.caseSensitive

    @clearMessages()
    @updateOptionsLabel()

  afterAttach: ->
    unless @tooltipsInitialized
      @regexOptionButton.setTooltip("Use Regex", command: 'project-find:toggle-regex-option', commandElement: @findEditor)
      @caseOptionButton.setTooltip("Match Case", command: 'project-find:toggle-case-option', commandElement: @findEditor)
      @replaceAllButton.setTooltip("Replace All", command: 'project-find:replace-all', commandElement: @replaceEditor)
      @tooltipsInitialized = true

  hideAllTooltips: ->
    @regexOptionButton.hideTooltip()
    @caseOptionButton.hideTooltip()
    @replaceAllButton.hideTooltip()

  serialize: ->
    findHistory: @findHistory.serialize()
    replaceHistory: @replaceHistory.serialize()
    pathsHistory: @pathsHistory.serialize()
    modelState: @model.serialize()

  handleEvents: ->
    @on 'core:confirm', => @confirm()
    @on 'find-and-replace:focus-next', => @focusNextElement(1)
    @on 'find-and-replace:focus-previous', => @focusNextElement(-1)
    @on 'core:cancel core:close', => @detach()

    @on 'project-find:toggle-regex-option', => @toggleRegexOption()
    @regexOptionButton.click => @toggleRegexOption()

    @on 'project-find:toggle-case-option', => @toggleCaseOption()
    @caseOptionButton.click => @toggleCaseOption()

    @replaceAllButton.on 'click', => @replaceAll()
    @on 'project-find:replace-all', => @replaceAll()

    @subscribe @model, 'cleared', => @clearMessages()
    @subscribe @model, 'replacement-state-cleared', (results) => @generateResultsMessage(results)
    @subscribe @model, 'finished-searching', (results) => @generateResultsMessage(results)

    @subscribe $(window), 'focus', => @onlyRunIfChanged = false

    atom.workspaceView.command 'find-and-replace:use-selection-as-find-pattern', @setSelectionAsFindPattern

    @handleEventsForReplace()

  handleEventsForReplace: ->
    @replaceEditor.getEditor().getBuffer().on 'changed', => @model.clearReplacementState()
    @replaceEditor.getEditor().on 'contents-modified', => @model.updateReplacementPattern(@replaceEditor.getText())
    @replacementsMade = 0
    @subscribe @model, 'replace', (promise) =>
      @replacementsMade = 0
      @replacmentInfoBlock.show()
      @replacementProgress.removeAttr('value')

    @subscribe @model, 'path-replaced', (result) =>
      @replacementsMade++
      @replacementProgress[0].value = @replacementsMade / @model.getPathCount()
      @replacmentInfo.text("Replaced #{@replacementsMade} of #{_.pluralize(@model.getPathCount(), 'file')}")

    @subscribe @model, 'finished-replacing', (result) => @onFinishedReplacing(result)

  attach: ->
    atom.workspaceView.prependToBottom(this) unless @hasParent()

    @setSelectionAsFindPattern() unless @findEditor.getText()

    @findEditor.focus()
    @findEditor.getEditor().selectAll()

  detach: ->
    return unless @hasParent()

    @hideAllTooltips()
    atom.workspaceView.focus()
    super()

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
    elements[focusedIndex].getEditor?().selectAll()

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

    @clearMessages()
    @showResultPane().then =>
      try
        @model.search(@findEditor.getText(), @getPaths(), @replaceEditor.getText(), {onlyRunIfChanged})
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

  findFileParent: (node) ->
    parent = node.parent()
    return parent if parent.is('.file') or parent.is('.directory')
    @findFileParent(parent)

  findInCurrentlySelectedDirectory: (selectedNode) ->
    selected = @findFileParent(selectedNode)
    selected = selected.parents('.directory:eq(0)') if selected.is('.file')
    absPath = selected.view().getPath()
    relPath = atom.project.relativize(absPath)
    @pathsEditor.setText(relPath)

  showResultPane: ->
    options = null
    options = {split: 'right'} if atom.config.get('find-and-replace.openProjectFindResultsInRightPane')
    atom.workspaceView.open(ResultsPaneView.URI, options)

  onFinishedReplacing: (results) ->
    atom.beep() unless results.replacedPathCount
    @replacmentInfoBlock.hide()

  generateResultsMessage: (results) =>
    message = Util.getSearchResultsMessage(results)
    message = Util.getReplacementResultsMessage(results) if results.replacedPathCount?
    @setInfoMessage(message)

  clearMessages: ->
    @setInfoMessage('Find in Project')
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
