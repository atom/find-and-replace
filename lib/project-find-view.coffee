shell = require 'shell'

{_, $, Editor, View} = require 'atom'

History = require './history'
PreviewList = require './project/preview-list'
SearchResult = require './project/search-result'

module.exports =
class ProjectFindView extends View
  @content: ->
    @div tabIndex: -1, class: 'project-find tool-panel panel-bottom padded', =>

      @div outlet: 'loadingMessage', class: 'loading loading-spinner-small block pull-center'

      @div outlet: 'previewBlock', class: 'preview-block inset-panel block', =>
        @div class: 'panel-heading', =>
          @span outlet: 'previewCount', class: 'preview-count'
        @subview 'previewList', new PreviewList

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

  initialize: ({attached, @useRegex, @caseInsensitive, findHistory, pathsHistory}={})->
    @handleEvents()
    @attach() if attached
    @findHistory = new History(@findEditor, findHistory)
    @pathsHistory = new History(@pathsEditor, pathsHistory)

    @regexOptionButton.addClass('selected') if @useRegex
    @caseOptionButton.addClass('selected') if @caseInsensitive

  serialize: ->
    attached: @hasParent()
    useRegex: @useRegex
    caseInsensitive: @caseInsensitive

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

  attach: ->
    rootView.vertical.append(this)
    @findEditor.focus()
    @findEditor.selectAll()

  detach: ->
    rootView.focus()
    super()

  toggleRegexOption: ->
    @useRegex = not @useRegex
    if @useRegex then @regexOptionButton.addClass('selected') else @regexOptionButton.removeClass('selected')
    @confirm()

  toggleCaseOption: ->
    @caseInsensitive = not @caseInsensitive
    if @caseInsensitive then @caseOptionButton.addClass('selected') else @caseOptionButton.removeClass('selected')
    @confirm()

  focusNextElement: (direction) ->
    elements = [@previewList, @findEditor, @replaceEditor].filter (el) -> el.has(':visible').length > 0
    focusedElement = _.find elements, (el) -> el.has(':focus').length > 0 or el.is(':focus')
    focusedIndex = elements.indexOf focusedElement

    focusedIndex = focusedIndex + direction
    focusedIndex = 0 if focusedIndex >= elements.length
    focusedIndex = elements.length - 1 if focusedIndex < 0
    elements[focusedIndex].focus()
    elements[focusedIndex].selectAll() if elements[focusedIndex].selectAll

  clearResults: ->
    @results = []
    @previewBlock.hide()

  confirm: ->
    return if @findEditor.getText().length == 0

    @loadingMessage.show()
    @previewBlock.hide()
    @errorMessages.empty()
    @findHistory.store()

    deferred = @search()
    deferred.done =>
      @loadingMessage.hide()
      @previewBlock.show()
      @previewList.populate(@results)
      if @results.length > 0
        @previewCount.text("#{_.pluralize(@results.length, 'match', 'matches')} in #{_.pluralize(@previewList.getPathCount(), 'file')}").show()
        @previewList.focus()
      else
        @previewCount.text("No matches found")

    deferred

  search: ->
    regex = @getRegex()
    @results = []
    paths = (path for path in @pathsEditor.getText().trim().split(',') when path)

    deferred = $.Deferred()
    promise = project.scan regex, {paths}, ({path, matchText, lineText, range: bufferRange}) =>
      searchResult = new SearchResult({path, matchText, lineText, bufferRange})
      @results.push(searchResult)

    promise.done ->
      deferred.resolve()

    deferred.promise()

  getRegex: ->
    flags = 'g'
    flags += 'i' unless @caseInsensitive
    text = @findEditor.getText()

    if @useRegex
      new RegExp(text, flags)
    else
      new RegExp(_.escapeRegExp(text), flags)

  replaceAll: ->
    unless @results?.length
      shell.beep()
      @previewBlock.show()
      @previewCount.text("Nothing replaced").show()
    else
      regex = @getRegex()
      replacementText = @replaceEditor.getText()
      pathsReplaced = {}
      for result in @results
        buffer = result.getBuffer()
        continue if pathsReplaced[buffer.getPath()]
        pathsReplaced[buffer.getPath()] = true

        newText = buffer.getText().replace(regex, replacementText)
        buffer.setText(newText)
        buffer.save()

      @previewList.populate([])
      @previewCount.text("Replaced #{_.pluralize(@results.length, 'result')} in #{_.pluralize(Object.keys(pathsReplaced).length, 'file')}").show()
