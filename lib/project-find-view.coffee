{View} = require 'space-pen'
Editor = require 'editor'

module.exports =
class ProjectFindView extends View
  @content: ->
    @div tabIndex: -1, class: 'project-find tool-panel panel-bottom', =>

      @div outlet: 'loadingMessage', class: 'loading is-loading loading-spinner-small', =>
        @span 'Searching...'

      @div class: 'find-container block', =>
        @label outlet: 'findLabel', 'Find'

        @subview 'findEditor', new Editor(mini: true)

        @div class: 'btn-group btn-toggle', =>
          @button outlet: 'regexOptionButton', class: 'btn btn-mini option-regex', '.*'
          @button outlet: 'caseSensitiveOptionButton', class: 'btn btn-mini option-case-sensitive', 'Aa'

      @div class: 'replace-container block', =>
        @label outlet: 'replaceLabel', 'Replace'

        @subview 'replaceEditor', new Editor(mini: true)

        @div class: 'btn-group btn-toggle', =>
          @button outlet: 'replaceNextButton', class: 'btn btn-mini btn-next', 'Next'
          @button outlet: 'replaceAllButton', class: 'btn btn-mini btn-all', 'All'

      @div class: 'filter-container block', =>
        @label outlet: 'filterLabel', 'Where'

        @subview 'filterEditor', new Editor(mini: true)

        @div class: 'btn-group btn-toggle', =>

  initialize: ->
    @handleEvents()

  handleEvents: ->
    @on 'core:cancel', => @detach()
    rootView.command 'project-find:show', => @attach()

  attach: ->
    rootView.vertical.append(this)
    @findEditor.focus()

  detach: ->
    rootView.focus()
    super()
