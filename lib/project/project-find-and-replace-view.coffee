{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
PreviewList = require './preview-list'
SearchResult = require './search-result'
EditSession = require 'edit-session'

module.exports =
class ProjectFindAndReplaceView extends View

  @content: ->
    @div class: 'find-and-replace project-find-and-replace tool-panel', =>

      @div class: 'loading is-loading', outlet: 'loadingMessage', =>
        @span 'Searching...'

      @div class: 'header', outlet: 'previewHeader', =>
        @button outlet: 'collapseAll', class: 'btn btn-mini pull-right', 'Collapse All'
        @button outlet: 'expandAll', class: 'btn btn-mini pull-right', 'Expand All'
        @span outlet: 'previewCount', class: 'preview-count'

      @subview 'previewList', new PreviewList(rootView)
      @ul class: 'error-messages', outlet: 'errorMessages'

      @div class: 'find-container', =>
        @label outlet: 'findLabel', 'Find'

        @div class: 'btn-group pull-right btn-toggle', =>
          @button outlet: 'regexOptionButton', class: 'btn btn-mini option-regex', '.*'
          @button outlet: 'caseSensitiveOptionButton', class: 'btn btn-mini option-case-sensitive', 'Aa'
          @button outlet: 'inSelectionOptionButton', class: 'btn btn-mini option-in-selection', '"'

        @div class: 'find-editor-container editor-container', =>
          @subview 'findEditor', new Editor(mini: true)

  detaching: false
  active: false

  initialize: (@project, @searchModel) ->
    @searchModel.on 'change', @onSearchModelChanged
    @updateOptionButtons()

    rootView.command 'find-and-replace:display-find-in-project', @showFind

    rootView.command 'find-and-replace:toggle-regex-option', @toggleRegexOption
    rootView.command 'find-and-replace:toggle-case-sensitive-option', @toggleCaseSensitiveOption
    rootView.command 'find-and-replace:toggle-in-selection-option', @toggleInSelectionOption

    rootView.on 'find-and-replace:search-next-in-history', '.project-find-and-replace', => @searchModel.searchNextInHistory()
    rootView.on 'find-and-replace:search-previous-in-history', '.project-find-and-replace', => @searchModel.searchPreviousInHistory()

    @regexOptionButton.on 'click', @toggleRegexOption
    @caseSensitiveOptionButton.on 'click', @toggleCaseSensitiveOption
    @inSelectionOptionButton.on 'click', @toggleInSelectionOption

    @expandAll.on 'click', @onExpandAll
    @collapseAll.on 'click', @onCollapseAll

    @findEditor.on 'core:confirm', @confirmFind
    @findEditor.on 'find-and-replace:focus-next', @focusReplace
    @findEditor.on 'find-and-replace:focus-previous', @focusReplace
    @findLabel.on 'click', @focusFind

    @on 'core:cancel', @detach

    @previewList.hide()
    @previewHeader.hide()
    @errorMessages.hide()
    @loadingMessage.hide()

    @findEditor.on 'keyup', (e) =>
      # When the user types something in the find box, we dont want to lose it
      # when they cycle through the history. Whatever they last typed will end
      # up as the find box's text when the user gets all the way to the end of
      # the history. Sublime effs this up and it maddens me.
      @unsearchedPattern = @findEditor.getText() if e.keyCode > 46 # Only printable chars

  onSearchModelChanged: (model, args) =>
    @updateOptionButtons()

    pattern = model.pattern or ''
    pattern = @unsearchedPattern if @unsearchedPattern and args.historyIndex == args.history.length and @unsearchedPattern != _.last(args.history)

    @findEditor.setText(pattern)

  destroy: ->
    @previewList.destroy()
    @remove()

  detach: =>
    rootView.focus()
    super()

  attach: =>
    rootView.vertical.append(this)

  confirmFind: =>
    @searchAndDisplayResults()

  showFind: =>
    @attach()
    @addClass('find-mode').removeClass('replace-mode')
    @focusFind()

  focusFind: =>
    @findEditor.selectAll()
    @findEditor.focus()

  search: ->
    deferred = $.Deferred()

    pattern = @findEditor.getText()
    @searchModel.setPattern(pattern)

    results = []
    if @searchModel.regex
      promise = project.scan @searchModel.regex, ({path, range}) =>
        results.push(new SearchResult(
          project: project
          path: path
          bufferRange: range
        ))
      promise.done -> deferred.resolve(results)

    deferred.promise()

  searchAndDisplayResults: ->
    @loadingMessage.show()
    @previewList.hide()
    @previewHeader.hide()
    @errorMessages.empty()

    activePaneItem = rootView.getActivePaneItem()
    editSession = activePaneItem if activePaneItem instanceof EditSession

    deferred = @search()
    deferred.done (results, errorMessages=[]) =>
      @loadingMessage.hide()

      if errorMessages.length > 0
        @flashError()
        @errorMessages.show()
        @errorMessages.append $$ ->
          @li errorMessage for errorMessage in errorMessages
      else if results.length
        @previewHeader.show()
        @previewList.populate(results)
        @previewList.focus()
        @previewCount.text("#{_.pluralize(results.length, 'match', 'matches')} in #{_.pluralize(@previewList.getPathCount(), 'file')}").show()
      else
        @previewCount.text("No matches found").show()

    deferred

  onExpandAll: (event) =>
    @previewList.expandAllPaths()
    @previewList.focus()

  onCollapseAll: (event) =>
    @previewList.collapseAllPaths()
    @previewList.focus()

  toggleRegexOption: => @toggleOption('regex')

  toggleCaseSensitiveOption: => @toggleOption('caseSensitive')

  toggleInSelectionOption: => @toggleOption('inSelection')

  toggleOption: (optionName) ->
    isset = @searchModel.getOption(optionName)
    @searchModel.setOption(optionName, !isset)

  setOptionButtonState: (optionButton, enabled) ->
    optionButton[if enabled then 'addClass' else 'removeClass']('enabled')

  updateOptionButtons: ->
    @setOptionButtonState(@regexOptionButton, @searchModel.getOption('regex'))
    @setOptionButtonState(@caseSensitiveOptionButton, @searchModel.getOption('caseSensitive'))
    @setOptionButtonState(@inSelectionOptionButton, @searchModel.getOption('inSelection'))
