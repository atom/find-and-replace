shell = require 'shell'

{_, $, $$$, Editor, View} = require 'atom'

History = require './history'
ResultsModel = require './project/results-model'
ResultsPaneView = require './project/results-pane'

module.exports =
class ProjectFindView extends View
  @content: ->
    @div tabIndex: -1, class: 'project-find tool-panel panel-bottom padded', =>

      @ul outlet: 'errorMessages', class: 'error-messages block'
      @ul outlet: 'infoMessages', class: 'info-messages block'

      @div class: 'find-container block', =>
        @label class: 'text-subtle', 'Find'

        @subview 'findEditor', new Editor(mini: true)

        @div class: 'btn-group btn-toggle', =>
          @button outlet: 'regexOptionButton', class: 'btn btn-mini option-regex', '.*'
          @button outlet: 'caseOptionButton', class: 'btn btn-mini option-case-sensitive', 'Aa'

      @div class: 'replace-container block', =>
        @label outlet: 'replaceLabel', class: 'text-subtle', 'Replace'

        @subview 'replaceEditor', new Editor(mini: true)

        @div class: 'btn-group btn-toggle', =>
          @button outlet: 'replaceAllButton', class: 'btn btn-mini', 'Replace'

      @div class: 'paths-container block', =>
        @label class: 'text-subtle', 'In'
        @subview 'pathsEditor', new Editor(mini: true)

  initialize: (@model, {attached, modelState, findHistory, replaceHistory, pathsHistory}={}) ->
    @lastFocusedElement = null

    @handleEvents()
    @attach() if attached
    @findHistory = new History(@findEditor, findHistory)
    @replaceHistory = new History(@replaceEditor, replaceHistory)
    @pathsHistory = new History(@pathsEditor, pathsHistory)

    @regexOptionButton.addClass('selected') if @model.useRegex
    @caseOptionButton.addClass('selected') if @model.caseSensitive

    @clearMessages()

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
    @findEditor.getBuffer().on 'changed', => @model.clear()

    self = this
    @findEditor.on 'focus', -> self.setLastFocusedElement(this)
    @findEditor.on 'blur', -> self.setLastFocusedElement(this)
    @replaceEditor.on 'focus', -> self.setLastFocusedElement(this)
    @replaceEditor.on 'blur', -> self.setLastFocusedElement(this)
    @pathsEditor.on 'focus', -> self.setLastFocusedElement(this)
    @pathsEditor.on 'blur', -> self.setLastFocusedElement(this)

  attach: ->
    if @hasParent()
      el = @lastFocusedElement or @findEditor
      el.focus()
      el.selectAll?()
    else
      rootView.vertical.append(this)
      @findEditor.focus()
      @findEditor.selectAll()

  detach: ->
    rootView.focus()
    super()

  toggleRegexOption: ->
    @model.toggleUseRegex()
    if @model.useRegex then @regexOptionButton.addClass('selected') else @regexOptionButton.removeClass('selected')
    @confirm()

  toggleCaseOption: ->
    @model.toggleCaseSensitive()
    if @model.caseSensitive then @caseOptionButton.addClass('selected') else @caseOptionButton.removeClass('selected')
    @confirm()

  setLastFocusedElement: (element) ->
    @lastFocusedElement = $(element)

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
    paths = (path.trim() for path in @pathsEditor.getText().trim().split(',') when path)
    @errorMessages.empty()
    @showResultPane()
    @model.search(@findEditor.getText(), paths)

  showResultPane: ->
    rootView.openSingletonSync(ResultsPaneView.URI, split: 'right')

  clearMessages: ->
    @errorMessages.hide().empty()
    @infoMessages.hide().empty()

  addInfoMessage: (message) ->
    @infoMessages.append($$$ -> @li message)
    @infoMessages.show()

  addErrorMessage: (message) ->
    @errorMessages.append($$$ -> @li message)
    @errorMessages.show()

  replaceAll: ->
    @clearMessages()

    unless @model.getPathCount()
      shell.beep()

      @addInfoMessage("Nothing replaced")
    else
      regex = @model.getRegex(@findEditor.getText())
      replacementText = @replaceEditor.getText()
      pathsReplaced = {}
      replacementsCount = 0
      for filePath in @model.getPaths()
        continue if pathsReplaced[filePath]

        result = @model.getResult(filePath)

        replacementsCount += result.length
        buffer = project.bufferForPathSync(filePath)
        pathsReplaced[buffer.getPath()] = true

        newText = buffer.getText().replace(regex, replacementText)
        buffer.setText(newText)
        buffer.save()

      @model.clear()
      @addInfoMessage("Replaced #{_.pluralize(replacementsCount, 'result')} in #{_.pluralize(Object.keys(pathsReplaced).length, 'file')}")
