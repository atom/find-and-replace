shell = require 'shell'

{_, $, Editor, View} = require 'atom'

History = require './history'
ResultsView = require './project/results-view'
ResultsModel = require './project/results-model'

module.exports =
class ProjectFindView extends View
  @content: ->
    @div tabIndex: -1, class: 'project-find tool-panel panel-bottom padded', =>

      @div outlet: 'previewBlock', class: 'preview-block inset-panel block', =>
        @div class: 'panel-heading', =>
          @span outlet: 'previewCount', class: 'preview-count inline-block'
          @div outlet: 'loadingMessage', class: 'loading loading-spinner-tiny inline-block'
        @subview 'resultsView', new ResultsView

      @ul outlet: 'errorMessages', class: 'error-messages block'

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

  initialize: ({attached, modelState, findHistory, pathsHistory}={})->
    @model = new ResultsModel(modelState)

    @handleEvents()
    @attach() if attached
    @findHistory = new History(@findEditor, findHistory)
    @pathsHistory = new History(@pathsEditor, pathsHistory)

    @resultsView.setModel(@model)

    @regexOptionButton.addClass('selected') if @model.useRegex
    @caseOptionButton.addClass('selected') if @model.caseSensitive

  serialize: ->
    attached: @hasParent()
    findHistory: @findHistory.serialize()
    pathsHistory: @pathsHistory.serialize()
    modelState: @model.serialize()

  handleEvents: ->
    rootView.command 'project-find:show', => @attach()
    @on 'core:cancel', => @detach()
    @on 'core:confirm', => @confirm()
    @on 'find-and-replace:focus-next', => @focusNextElement(1)
    @on 'find-and-replace:focus-previous', => @focusNextElement(-1)

    @on 'project-find:toggle-regex-option', => @toggleRegexOption()
    @regexOptionButton.click => @toggleRegexOption()

    @on 'project-find:toggle-case-option', => @toggleCaseOption()
    @caseOptionButton.click => @toggleCaseOption()

    @replaceAllButton.on 'click', => @replaceAll()
    @on 'project-find:replace-all', => @replaceAll()

    @findEditor.getBuffer().on 'changed', => @clearResults()

    @model.on 'result-added result-removed', =>
      @previewCount.text(@getResultCountText()) if @model.getPathCount() % 250 == 0

    @model.on 'finished-searching', =>
      @previewCount.text(@getResultCountText())

  attach: ->
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

  focusNextElement: (direction) ->
    elements = [@resultsView, @findEditor, @replaceEditor].filter (el) -> el.has(':visible').length > 0
    focusedElement = _.find elements, (el) -> el.has(':focus').length > 0 or el.is(':focus')
    focusedIndex = elements.indexOf focusedElement

    focusedIndex = focusedIndex + direction
    focusedIndex = 0 if focusedIndex >= elements.length
    focusedIndex = elements.length - 1 if focusedIndex < 0
    elements[focusedIndex].focus()
    elements[focusedIndex].selectAll() if elements[focusedIndex].selectAll

  clearResults: ->
    @resultsView.clear()
    @previewBlock.hide()

  confirm: ->
    return if @findEditor.getText().length == 0

    @clearResults()
    @loadingMessage.show()
    @previewBlock.hide()
    @errorMessages.empty()
    @findHistory.store()

    deferred = @search()
    console.time("search")
    deferred.done =>
      console.timeEnd("search")
      @loadingMessage.hide()
      @previewCount.text(@getResultCountText())

    deferred

  search: ->
    paths = (path.trim() for path in @pathsEditor.getText().trim().split(',') when path)

    @previewCount.text('Searching...')
    @previewBlock.show()
    @previewCount.show()
    @resultsView.focus()

    @model.search(@findEditor.getText(), paths)

  getResultCountText: ->
    if @resultsView.getPathCount() > 0
      "#{_.pluralize(@resultsView.getMatchCount(), 'match', 'matches')} in #{_.pluralize(@resultsView.getPathCount(), 'file')}"
    else
      "No matches found"

  replaceAll: ->
    unless @model.getPathCount()
      shell.beep()
      @previewBlock.show()
      @previewCount.text("Nothing replaced").show()
    else
      regex = @model.getRegex(@findEditor.getText())
      replacementText = @replaceEditor.getText()
      pathsReplaced = {}
      replacementsCount = 0
      for filePath in @model.getPaths()
        continue if pathsReplaced[filePath]

        result = @model.getResult(filePath)

        replacementsCount += result.length
        buffer = project.bufferForPath(filePath)
        pathsReplaced[buffer.getPath()] = true

        newText = buffer.getText().replace(regex, replacementText)
        buffer.setText(newText)
        buffer.save()

      @resultsView.clear()

      @previewCount.text("Replaced #{_.pluralize(replacementsCount, 'result')} in #{_.pluralize(Object.keys(pathsReplaced).length, 'file')}").show()
