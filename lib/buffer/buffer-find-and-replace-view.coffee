{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
{Point} = require 'telepath'
SearchModel = require '../search-model'
SearchResultsView = require '../search-results-view'
ResultCounterView = require './result-counter-view'

module.exports =
class BufferFindAndReplaceView extends View

  @content: ->
    @div class: 'find-and-replace buffer-find-and-replace tool-panel', =>
      @div class: 'find-container', =>
        @label outlet: 'findLabel', 'Find'

        @div class: 'btn-group pull-right btn-toggle', =>
          @button outlet: 'regexOptionButton', class: 'btn btn-mini option-regex', '.*'
          @button outlet: 'caseSensitiveOptionButton', class: 'btn btn-mini option-case-sensitive', 'Aa'
          @button outlet: 'inSelectionOptionButton', class: 'btn btn-mini option-in-selection', '"'

        @div class: 'find-editor-container editor-container', =>
          @div class: 'find-meta-container', =>
            @subview 'resultCounter', new ResultCounterView()
            @a href: '#', outlet: 'previousButton', class: 'icon-previous'
            @a href: '#', outlet: 'nextButton', class: 'icon-next'
          @subview 'findEditor', new Editor(mini: true)

      @div outlet: 'replaceContainer', class: 'replace-container', =>
        @label outlet: 'replaceLabel', 'Replace'

        @div class: 'btn-group pull-right btn-toggle', =>
          @button outlet: 'replaceNextButton', class: 'btn btn-mini btn-next', 'Next'
          @button outlet: 'replaceAllButton', class: 'btn btn-mini btn-all', 'All'

        @div class: 'replace-editor-container editor-container', =>
          @subview 'replaceEditor', new Editor(mini: true)

  detaching: false
  active: false

  initialize: (@searchModel) ->
    @searchModel.on 'change', @onSearchModelChanged

    rootView.command 'find-and-replace:display-find', @showFind
    rootView.command 'find-and-replace:display-replace', @showReplace

    rootView.command 'find-and-replace:toggle-regex-option', @toggleRegexOption
    rootView.command 'find-and-replace:toggle-case-sensitive-option', @toggleCaseSensitiveOption
    rootView.command 'find-and-replace:toggle-in-selection-option', @toggleInSelectionOption

    rootView.command 'find-and-replace:set-selection-as-search-pattern', @setSelectionAsSearchPattern

    rootView.on 'find-and-replace:search-next-in-history', => @searchModel.searchNextInHistory()
    rootView.on 'find-and-replace:search-previous-in-history', => @searchModel.searchPreviousInHistory()

    @previousButton.on 'click', =>
      @findEditor.focus()
      @findPrevious()
      false
    @nextButton.on 'click', =>
      @findEditor.focus()
      @findNext()
      false

    @regexOptionButton.on 'click', @toggleRegexOption
    @caseSensitiveOptionButton.on 'click', @toggleCaseSensitiveOption
    @inSelectionOptionButton.on 'click', @toggleInSelectionOption

    @replaceNextButton.on 'click', @replaceNext
    @replaceAllButton.on 'click', @replaceAll

    @findEditor.on 'core:confirm', @confirmFind
    @findEditor.on 'find-and-replace:focus-next', @focusReplace
    @findEditor.on 'find-and-replace:focus-previous', @focusReplace
    @findLabel.on 'click', @focusFind
    @resultCounter.on 'click', @focusFind

    @replaceEditor.on 'core:confirm', @confirmReplace
    @replaceEditor.on 'find-and-replace:focus-next', @focusFind
    @replaceEditor.on 'find-and-replace:focus-previous', @focusFind
    @replaceLabel.on 'click', @focusReplace

    @on 'core:cancel', @detach

    @searchResultsViews = []
    rootView.on 'pane:became-active pane:became-inactive pane:removed', @onActiveItemChanged
    rootView.eachEditor (editor) =>
      if editor.attached and not editor.mini
        view = new SearchResultsView(@searchModel, editor, {@active})
        view.on 'destroyed', =>
          @searchResultsViews = _.without(@searchResultsViews, view)
        @searchResultsViews.push(view)
        editor.underlayer.append(view)

    @findEditor.on 'keyup', (e) =>
      # When the user types something in the find box, we dont want to lose it
      # when they cycle through the history. Whatever they last typed will end
      # up as the find box's text when the user gets all the way to the end of
      # the history. Sublime effs this up and it maddens me.
      @unsearchedPattern = @findEditor.getText() if e.keyCode > 46 # Only printable chars

    @resultCounter.setModel(this)
    @onActiveItemChanged()
    @updateOptionButtons()

  onActiveItemChanged: =>
    return unless window.rootView
    editor = @currentEditor()
    @trigger('active-editor-changed', editor: editor)

  onSearchModelChanged: (model, args) =>
    @updateOptionButtons()

    pattern = model.pattern or ''
    pattern = @unsearchedPattern if @unsearchedPattern and args.historyIndex == args.history.length and @unsearchedPattern != _.last(args.history)

    @findEditor.setText(pattern)

  detach: =>
    @deactivate()
    rootView.focus()
    super()

  attach: =>
    rootView.vertical.append(this)
    @activate()

  confirmFind: =>
    @search()
    @findNext()
    editor = @currentEditor()
    editor.focus() if editor and editor.searchResults and editor.searchResults.getCurrentResult().total

  confirmReplace: =>
    @search()
    @replaceNext()

  showFind: =>
    @attach()
    @addClass('find-mode').removeClass('replace-mode')
    @focusFind()

  showReplace: =>
    @attach()
    @addClass('replace-mode').removeClass('find-mode')
    @focusReplace()

  focusFind: =>
    @replaceEditor.clearSelections()
    @findEditor.selectAll()
    @findEditor.focus()

  focusReplace: =>
    return unless @hasClass('replace-mode')
    @findEditor.clearSelections()
    @replaceEditor.selectAll()
    @replaceEditor.focus()

  search: ->
    pattern = @findEditor.getText()
    @searchModel.setPattern(pattern)

  replaceNext: =>
    @search()
    replacement = @replaceEditor.getText()
    @currentEditor().trigger('find-and-replace:replace-next', {replacement})

  replaceAll: =>
    @search()
    replacement = @replaceEditor.getText()
    @currentEditor().trigger('find-and-replace:replace-all', {replacement})

  findPrevious: =>
    @search()
    @currentEditor().trigger('find-and-replace:find-previous')

  findNext: =>
    @search()
    @currentEditor().trigger('find-and-replace:find-next')

  setSelectionAsSearchPattern: =>
    editor = @currentEditor()
    pattern = editor.getSelectedText()

    if pattern
      @searchModel.setPattern(pattern)
      _.last(editor.getSelectionViews()).highlight()

    null

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

  activate: ->
    @active = true
    view.activate() for view in @searchResultsViews

  deactivate: ->
    @active = false
    view.deactivate() for view in @searchResultsViews

  currentEditor: ->
    rootView.getActiveView()


