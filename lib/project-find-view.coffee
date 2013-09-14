_ = require 'underscore'
$ = require 'jquery'
{View} = require 'space-pen'
Editor = require 'editor'
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

  initialize: ({attached}={})->
    @handleEvents()
    @attach() if attached

  serialize: ->
    attached: @hasParent()

  handleEvents: ->
    rootView.command 'project-find:show', => @attach()
    @on 'core:cancel', => @detach()
    @on 'core:confirm', => @confirm()

    @on 'project-find:toggle-regex-option', => @toggleRegex()
    @regexOptionButton.click => @toggleRegex()

  attach: ->
    rootView.vertical.append(this)
    @findEditor.focus()
    @findEditor.selectAll()

  detach: ->
    rootView.focus()
    super()

  toggleRegex: ->
    @useRegex = not @useRegex
    if @useRegex then @regexOptionButton.addClass('selected') else @regexOptionButton.removeClass('selected')
    @confirm()

  confirm: ->
    @loadingMessage.show()
    @previewBlock.hide()
    @errorMessages.empty()

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
    text = @findEditor.getText()
    if @useRegex
      regex = new RegExp(text)
    else
      regex = new RegExp(_.escapeRegExp(text))
    results = []

    deferred = $.Deferred()
    promise = project.scan regex, ({path, range: bufferRange}) =>
      searchResult = new SearchResult({path, bufferRange})
      results.push(searchResult)

    promise.done -> deferred.resolve(results)

    deferred.promise()
