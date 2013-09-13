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

      @ul class: 'error-messages block', outlet: 'errorMessages'

      @div class: 'find-container block', =>
        @label outlet: 'findLabel', 'Find'

        @subview 'findEditor', new Editor(mini: true)

        @div class: 'btn-group btn-toggle', =>
          @button outlet: 'regexOptionButton', class: 'btn btn-mini option-regex', '.*'
          @button outlet: 'caseSensitiveOptionButton', class: 'btn btn-mini option-case-sensitive', 'Aa'

  initialize: ->
    @handleEvents()

  handleEvents: ->
    @on 'core:cancel', => @detach()
    @on 'core:confirm', => @confirm()
    rootView.command 'project-find:show', => @attach()

  attach: ->
    rootView.vertical.append(this)
    @findEditor.focus()

  detach: ->
    rootView.focus()
    super()

  confirm: ->
    @loadingMessage.show()
    @previewBlock.hide()
    @errorMessages.empty()

    deferred = @search()
    deferred.done (results, errorMessages=[]) =>
      @loadingMessage.hide()

      if errorMessages.length > 0
        @flashError()
        @errorMessages.show()
        @errorMessages.append $$ ->
          @li errorMessage for errorMessage in errorMessages
      else if results.length
        @previewBlock.show()
        @previewList.populate(results)
        @previewCount.text("#{_.pluralize(results.length, 'match', 'matches')} in #{_.pluralize(@previewList.getPathCount(), 'file')}").show()
        @previewList.focus()
      else
        @previewCount.text("No matches found").show()

    deferred

  search: ->
    text = @findEditor.getText()
    regex = new RegExp(_.escapeRegExp(text))
    results = []

    deferred = $.Deferred()
    promise = project.scan regex, ({path, range: bufferRange}) =>
      searchResult = new SearchResult({path, bufferRange})
      results.push(searchResult)

    promise.done -> deferred.resolve(results)

    deferred.promise()
