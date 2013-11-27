Q = require 'q'
{_, $, $$$, EditorView, View} = require 'atom'

History = require './history'
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

      @ul outlet: 'errorMessages', class: 'error-messages block'

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

  initialize: (@model, {attached, modelState, findHistory, replaceHistory, pathsHistory}={}) ->
    @handleEvents()
    @attach() if attached
    @findHistory = new History(@findEditor, findHistory)
    @replaceHistory = new History(@replaceEditor, replaceHistory)
    @pathsHistory = new History(@pathsEditor, pathsHistory)

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
    attached: @hasParent()
    findHistory: @findHistory.serialize()
    replaceHistory: @replaceHistory.serialize()
    pathsHistory: @pathsHistory.serialize()
    modelState: @model.serialize()

  handleEvents: ->
    @on 'core:confirm', => @confirm()
    @on 'find-and-replace:focus-next', => @focusNextElement(1)
    @on 'find-and-replace:focus-previous', => @focusNextElement(-1)

    @on 'project-find:toggle-regex-option', => @toggleRegexOption()
    @regexOptionButton.click => @toggleRegexOption()

    @on 'project-find:toggle-case-option', => @toggleCaseOption()
    @caseOptionButton.click => @toggleCaseOption()

    @replaceAllButton.on 'click', => @replaceAll()
    @on 'project-find:replace-all', => @replaceAll()

    @model.on 'cleared', => @clearMessages()
    @model.on 'finished-searching', => @onFinishedSearching()
    @findEditor.getBuffer().on 'changed', => @model.clear()

    atom.workspaceView.command 'find-and-replace:use-selection-as-find-pattern', @setSelectionAsFindPattern

    @handleEventsForReplace()

  handleEventsForReplace: ->
    @replacementsMade = 0
    @model.on 'replace', (promise) =>
      @replacementsMade = 0
      @replacmentInfoBlock.show()
      @replacementProgress.removeAttr('value')

    @model.on 'path-replaced', (result) =>
      @replacementsMade++
      @replacementProgress[0].value = @replacementsMade / @model.getPathCount()
      @replacmentInfo.text("Replaced #{@replacementsMade} of #{_.pluralize(@model.getPathCount(), 'file')}")

    @model.on 'finished-replacing', ({pathsReplaced, replacements}) =>
      @replacmentInfoBlock.hide()
      if pathsReplaced
        @setInfoMessage("Replaced #{_.pluralize(replacements, 'result')} in #{_.pluralize(pathsReplaced, 'file')}")
      else
        atom.beep()
        @setInfoMessage("Nothing replaced")

  attach: ->
    atom.workspaceView.vertical.append(this) unless @hasParent()
    @findEditor.focus()
    @findEditor.selectAll()

  detach: ->
    @hideAllTooltips()
    atom.workspaceView.focus()
    super()

  toggleRegexOption: ->
    @model.toggleUseRegex()
    if @model.useRegex then @regexOptionButton.addClass('selected') else @regexOptionButton.removeClass('selected')
    @updateOptionsLabel()
    @confirm()

  toggleCaseOption: ->
    @model.toggleCaseSensitive()
    if @model.caseSensitive then @caseOptionButton.addClass('selected') else @caseOptionButton.removeClass('selected')
    @updateOptionsLabel()
    @confirm()

  focusNextElement: (direction) ->
    elements = [@findEditor, @replaceEditor, @pathsEditor].filter (el) -> el.has(':visible').length > 0
    focusedElement = _.find elements, (el) -> el.has(':focus').length > 0 or el.is(':focus')
    focusedIndex = elements.indexOf focusedElement

    focusedIndex = focusedIndex + direction
    focusedIndex = 0 if focusedIndex >= elements.length
    focusedIndex = elements.length - 1 if focusedIndex < 0
    elements[focusedIndex].focus()
    elements[focusedIndex].selectAll() if elements[focusedIndex].selectAll

  confirm: ->
    return if @findEditor.getText().length == 0

    @findHistory.store()
    @replaceHistory.store()
    @pathsHistory.store()

    @search()

  search: ->
    @errorMessages.empty()
    @showResultPane()
    @model.search(@findEditor.getText(), @getPaths())

  replaceAll: ->
    deferred = Q.defer()

    promise = @model.search(@findEditor.getText(), @getPaths(), true)
    promise.done =>
      @clearMessages()
      pattern = @findEditor.getText()
      replacementText = @replaceEditor.getText()
      @model.replace(pattern, replacementText, @model.getPaths()).done ->
        deferred.resolve()

    deferred.promise

  getPaths: ->
    path.trim() for path in @pathsEditor.getText().trim().split(',') when path

  showResultPane: ->
    options = null
    options = {split: 'right'} if atom.config.get('find-and-replace.openProjectFindResultsInRightPane')
    atom.workspaceView.openSingletonSync(ResultsPaneView.URI, options)

  onFinishedSearching: ->
    resultsStr = if @model.matchCount
      "#{_.pluralize(@model.matchCount, 'result')} found in #{@model.pathCount} files"
    else
      'No results found'

    @descriptionLabel.text("#{resultsStr} for '#{@model.pattern}'")

  clearMessages: ->
    @descriptionLabel.text('Find in Project')
    @replacmentInfoBlock.hide()
    @errorMessages.hide().empty()

  addErrorMessage: (message) ->
    @errorMessages.append($$$ -> @li message)
    @errorMessages.show()

  setInfoMessage: (message) ->
    @descriptionLabel.text(message)

  updateOptionsLabel: ->
    label = []
    label.push('Regex') if @model.useRegex
    if @model.caseSensitive
      label.push('Case Sensitive')
    else
      label.push('Case Insensitive')
    @optionsLabel.text(label.join(', '))

  setSelectionAsFindPattern: =>
    editor = atom.workspaceView.getActiveView()
    if editor
      pattern = editor.editor.getSelectedText()
      @findEditor.setText(pattern)
