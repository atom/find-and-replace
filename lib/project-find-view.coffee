_ = require 'underscore'
$ = require 'jquery'
{View} = require 'space-pen'
Editor = require 'editor'
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
        @label outlet: 'findLabel', class: 'text-subtle', 'Find'

        @subview 'findEditor', new Editor(mini: true)

        @div class: 'btn-group btn-toggle', =>
          @button outlet: 'regexOptionButton', class: 'btn btn-mini option-regex', '.*'
          @button outlet: 'caseOptionButton', class: 'btn btn-mini option-case-sensitive', 'Aa'

      @div class: 'replace-container block', =>
        @label outlet: 'replaceLabel', class: 'text-subtle', 'Replace'

        @subview 'replaceEditor', new Editor(mini: true)

        @div class: 'btn-group btn-toggle', =>
          @button outlet: 'replaceButton', class: 'btn btn-mini', 'Replace'


  initialize: ({attached, @useRegex, @caseInsensitive, findHistory}={})->
    @handleEvents()
    @attach() if attached
    @findHistory = new History(@findEditor, findHistory)

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

    @on 'project-find:toggle-regex-option', => @toggleRegexOption()
    @regexOptionButton.click => @toggleRegexOption()

    @on 'project-find:toggle-case-option', => @toggleCaseOption()
    @caseOptionButton.click => @toggleCaseOption()

    @replaceButton.on 'click', => @replaceAll()
    @on 'project-find:replace', => @replaceAll()

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

  confirm: ->
    @loadingMessage.show()
    @previewBlock.hide()
    @errorMessages.empty()
    @findHistory.store()

    deferred = @search()
    deferred.done (results, errorMessages=[]) =>
      @loadingMessage.hide()

      if errorMessages.length > 0
        @errorMessages.show()
        @errorMessages.append $$ ->
          @li errorMessage for errorMessage in errorMessages
      else
        @previewBlock.show()
        @previewList.populate(results)
        if results.length > 0
          @previewCount.text("#{_.pluralize(results.length, 'match', 'matches')} in #{_.pluralize(@previewList.getPathCount(), 'file')}").show()
          @previewList.focus()
        else
          @previewCount.text("No matches found")

    deferred

  search: ->
    regex = @getRegex()
    results = []

    deferred = $.Deferred()
    promise = project.scan regex, ({path, range: bufferRange}) =>
      searchResult = new SearchResult({path, bufferRange})
      results.push(searchResult)

    promise.done -> deferred.resolve(results)

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
    regex = @getRegex()
    replacementText = @replaceEditor.getText()
    pathsReplaced = {}
    @confirm().done (results) ->
      for result in results
        buffer = result.getBuffer()
        continue if pathsReplaced[buffer.getPath()]
        pathsReplaced[buffer.getPath()] = true

        newText = buffer.getText().replace(regex, replacementText)
        buffer.setText(newText)
        buffer.save()
