{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
Point = require 'point'
SearchModel = require './search-model'
SearchResultsView = require './search-results-view'
ResultCounterView = require './result-counter-view'

module.exports =
class SearchInBufferView extends View

  @content: ->
    @div class: 'search-in-buffer overlay from-top', =>
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

    rootView.command 'search-in-buffer:display-find', @showFind
    rootView.command 'search-in-buffer:display-replace', @showReplace

    rootView.command 'search-in-buffer:find-previous', @findPrevious
    rootView.command 'search-in-buffer:find-next', @findNext

    @previousButton.on 'click', => @findPrevious(); false
    @nextButton.on 'click', => @findNext(); false

    @regexOptionButton.on 'click', @toggleRegexOption
    @caseSensitiveOptionButton.on 'click', @toggleCaseSensitiveOption

    @findEditor.on 'core:confirm', @confirmFind
    @replaceEditor.on 'core:confirm', @confirmReplace

    @on 'core:cancel', @detach

    rootView.on 'pane:became-active pane:active-item-changed editor:attached', @onActiveItemChanged
    rootView.eachEditor (editor) =>
      if editor.attached and not editor.mini
        editor.underlayer.append(new SearchResultsView(@searchModel, editor))
        editor.on 'editor:will-be-removed', @onActiveItemChanged
        editor.on 'cursor:moved', @onCursorMoved

    @onActiveItemChanged()
    @resultCounter.setModel(@searchModel)

  onActiveItemChanged: =>
    return unless rootView
    editor = rootView.getActiveView()
    @searchModel.setActiveId(if editor then editor.id else null)

  onCursorMoved: =>
    if @cursorMoveOriginatedHere
      # HACK: I want to reset the current result whenever the cursor is moved
      # so it removes the '# of' from '2 of 100'. But I cant tell if I moved
      # the cursor or the user did as it happens asynchronously. Thus this
      # crappy boolean. Open to suggestions.
      @cursorMoveOriginatedHere = false
    else
      @searchModel.getActiveResultsModel()?.setCurrentResultIndex(null)

  onSearchModelChanged: (model) =>
    @setOptionButtonState(@regexOptionButton, model.getOption('regex'))
    @setOptionButtonState(@caseSensitiveOptionButton, model.getOption('caseSensitive'))

  detach: =>
    return unless @hasParent()

    @detaching = true

    @searchModel.hideResults()

    if @previouslyFocusedElement?.isOnDom()
      @previouslyFocusedElement.focus()
    else
      rootView.focus()

    super

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

    @findEditor.selectAll()
    @findEditor.focus()

  showReplace: =>
    @attach()
    @addClass('replace-mode').removeClass('find-mode')

    @replaceEditor.selectAll()
    @replaceEditor.focus()

  search: ->
    pattern = @findEditor.getText()
    @searchModel.setPattern(pattern)

  replaceNext: =>
    replaceText = @replaceEditor.getText()
    editSession = rootView.getActiveView().activeEditSession
    currentBufferRange = editSession.getSelectedBufferRange()
    bufferRange = @searchModel.getActiveResultsModel().replaceCurrentResultAndFindNext(replaceText, currentBufferRange).range
    @highlightSearchResult(bufferRange)

  findPrevious: =>
    @jumpToSearchResult('findPrevious')

  findNext: =>
    @jumpToSearchResult('findNext')

  jumpToSearchResult: (functionName) ->
    editSession = rootView.getActiveView().activeEditSession
    bufferRange = @searchModel.getActiveResultsModel()[functionName](editSession.getSelectedBufferRange()).range
    @highlightSearchResult(bufferRange)

  highlightSearchResult: (bufferRange) ->
    @cursorMoveOriginatedHere = true # See HACK above.
    editSession = rootView.getActiveView().activeEditSession
    editSession.setSelectedBufferRange(bufferRange, autoscroll: true) if bufferRange

  toggleRegexOption: => @toggleOption('regex')
  toggleCaseSensitiveOption: => @toggleOption('caseSensitive')
  toggleOption: (optionName) ->
    isset = @searchModel.getOption(optionName)
    @searchModel.setOption(optionName, !isset)

  setOptionButtonState: (optionButton, enabled) ->
    optionButton[if enabled then 'addClass' else 'removeClass']('enabled')


