{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
SearchModel = require '../search-model'

module.exports =
class ProjectFindAndReplaceView extends View

  @content: ->
    @div class: 'find-and-replace project-find-and-replace tool-panel', =>
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

  initialize: (@searchModel) ->
    @searchModel.on 'change', @onSearchModelChanged
    @updateOptionButtons()

    rootView.command 'find-and-replace:display-find-in-project', @showFind

    rootView.command 'find-and-replace:toggle-regex-option', @toggleRegexOption
    rootView.command 'find-and-replace:toggle-case-sensitive-option', @toggleCaseSensitiveOption
    rootView.command 'find-and-replace:toggle-in-selection-option', @toggleInSelectionOption

    rootView.on 'find-and-replace:search-next-in-history', => @searchModel.searchNextInHistory()
    rootView.on 'find-and-replace:search-previous-in-history', => @searchModel.searchPreviousInHistory()

    @regexOptionButton.on 'click', @toggleRegexOption
    @caseSensitiveOptionButton.on 'click', @toggleCaseSensitiveOption
    @inSelectionOptionButton.on 'click', @toggleInSelectionOption

    @findEditor.on 'core:confirm', @confirmFind
    @findEditor.on 'find-and-replace:focus-next', @focusReplace
    @findEditor.on 'find-and-replace:focus-previous', @focusReplace
    @findLabel.on 'click', @focusFind

    @on 'core:cancel', @detach

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

    console.log 'search', pattern
    @findEditor.setText(pattern)

  detach: =>
    rootView.focus()
    super()

  attach: =>
    rootView.vertical.append(this)

  confirmFind: =>
    @search()

  showFind: =>
    @attach()
    @addClass('find-mode').removeClass('replace-mode')
    @focusFind()

  focusFind: =>
    @findEditor.selectAll()
    @findEditor.focus()

  search: ->
    pattern = @findEditor.getText()
    @searchModel.setPattern(pattern)

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


