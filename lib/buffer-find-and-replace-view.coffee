{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
Point = require 'point'
SearchModel = require './search-model'
SearchResultsView = require './search-results-view'
ResultCounterView = require './result-counter-view'
shell = require 'shell'

module.exports =
class BufferFindAndReplaceView extends View

  @content: ->
    @div class: 'buffer-find-and-replace overlay from-top', =>
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

  initialize: (@searchModel) ->
    @searchModel.on 'change', @onSearchModelChanged

    rootView.command 'buffer-find-and-replace:display-find', @showFind
    rootView.command 'buffer-find-and-replace:display-replace', @showReplace

    rootView.command 'buffer-find-and-replace:toggle-regex-option', @toggleRegexOption
    rootView.command 'buffer-find-and-replace:toggle-case-sensitive-option', @toggleCaseSensitiveOption
    rootView.command 'buffer-find-and-replace:toggle-in-selection-option', @toggleInSelectionOption

    @previousButton.on 'click', => @findPrevious(); false
    @nextButton.on 'click', => @findNext(); false

    @regexOptionButton.on 'click', @toggleRegexOption
    @caseSensitiveOptionButton.on 'click', @toggleCaseSensitiveOption
    @inSelectionOptionButton.on 'click', @toggleInSelectionOption

    @replaceNextButton.on 'click', @replaceNext
    @replaceAllButton.on 'click', @replaceAll

    @findEditor.on 'core:confirm', @confirmFind
    @findEditor.on 'buffer-find-and-replace:focus-next', @focusReplace
    @findEditor.on 'buffer-find-and-replace:focus-previous', @focusReplace
    @findLabel.on 'click', @focusFind
    @resultCounter.on 'click', @focusFind

    @replaceEditor.on 'core:confirm', @confirmReplace
    @replaceEditor.on 'buffer-find-and-replace:focus-next', @focusFind
    @replaceEditor.on 'buffer-find-and-replace:focus-previous', @focusFind
    @replaceLabel.on 'click', @focusReplace

    @on 'core:cancel', @detach

    rootView.on 'pane:became-active pane:became-inactive pane:removed', @onActiveItemChanged
    rootView.eachEditor (editor) =>
      if editor.attached and not editor.mini
        editor.underlayer.append(new SearchResultsView(@searchModel, editor))
        editor.on 'cursor:moved', @onCursorMoved

    @resultCounter.setModel(this)
    @onActiveItemChanged()

  onActiveItemChanged: =>
    return unless window.rootView
    editor = rootView.getActiveView()
    console.log 'active editor changed', editor
    @trigger('active-editor-changed', editor: editor)

  onCursorMoved: =>
    if @cursorMoveOriginatedHere
      # HACK: I want to reset the current result whenever the cursor is moved
      # so it removes the '# of' from '2 of 100'. But I cant tell if I moved
      # the cursor or the user did as it happens asynchronously. Thus this
      # crappy boolean. Open to suggestions.
      @cursorMoveOriginatedHere = false
    else
      rootView.getActiveView().trigger('buffer-find-and-replace:clear-current-result')

  onSearchModelChanged: (model) =>
    @setOptionButtonState(@regexOptionButton, model.getOption('regex'))
    @setOptionButtonState(@caseSensitiveOptionButton, model.getOption('caseSensitive'))
    @setOptionButtonState(@inSelectionOptionButton, model.getOption('inSelection'))

  detach: =>
    return unless @hasParent()

    @detaching = true

    @searchModel.hideResults()

    if @previouslyFocusedElement?.isOnDom()
      @previouslyFocusedElement.focus()
    else
      rootView.focus()

    super()

    @detaching = false

  attach: =>
    unless @hasParent()
      @previouslyFocusedElement = $(':focus')
      rootView.append(this)

    _.nextTick => @searchModel.showResults()

  confirmFind: =>
    @search()
    @findNext()
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
    rootView.getActiveView().trigger('buffer-find-and-replace:replace-next', {replacement})

  replaceAll: =>
    @search()
    replacement = @replaceEditor.getText()
    rootView.getActiveView().trigger('buffer-find-and-replace:replace-all', {replacement})

  findPrevious: =>
    @cursorMoveOriginatedHere = true # See HACK above.
    rootView.getActiveView().trigger('buffer-find-and-replace:find-previous')

  findNext: =>
    @cursorMoveOriginatedHere = true # See HACK above.
    rootView.getActiveView().trigger('buffer-find-and-replace:find-next')

  toggleRegexOption: => @toggleOption('regex')
  toggleCaseSensitiveOption: => @toggleOption('caseSensitive')
  toggleInSelectionOption: => @toggleOption('inSelection')
  toggleOption: (optionName) ->
    isset = @searchModel.getOption(optionName)
    @searchModel.setOption(optionName, !isset)

  setOptionButtonState: (optionButton, enabled) ->
    optionButton[if enabled then 'addClass' else 'removeClass']('enabled')


