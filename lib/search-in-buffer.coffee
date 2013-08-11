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

  @activate: -> new SearchInBufferView

  @content: ->
    @div class: 'search-in-buffer overlay from-top', =>
      @div class: 'find-container', =>
        @div class: 'btn-group pull-right btn-toggle', =>
          @button outlet: 'regexOptionButton', class: 'btn btn-mini', '.*'
          @button outlet: 'caseSensitiveOptionButton', class: 'btn btn-mini', 'Aa'

        @div class: 'find-editor-container', =>
          @div class: 'find-meta-container', =>
            @subview 'resultCounter', new ResultCounterView()
            @a href: '#', outlet: 'previousButton', class: 'icon-previous'
            @a href: '#', outlet: 'nextButton', class: 'icon-next'
          @subview 'miniEditor', new Editor(mini: true)

  detaching: false

  initialize: ->
    @searchModel = new SearchModel

    rootView.command 'search-in-buffer:display-find', @showFind
    rootView.command 'search-in-buffer:display-replace', @showReplace

    rootView.command 'search-in-buffer:find-previous', @findPrevious
    rootView.command 'search-in-buffer:find-next', @findNext

    @previousButton.on 'click', => @findPrevious(); false
    @nextButton.on 'click', => @findNext(); false

    @on 'core:confirm', @confirm
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

    @miniEditor.selectAll()
    @miniEditor.focus()
    _.nextTick => @searchModel.showResults()

  confirm: =>
    @search()
    @findNext()

  showFind: =>
    @attach()

  showReplace: =>

  search: ->
    pattern = @miniEditor.getText()
    @searchModel.search(pattern, @getFindOptions())

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

  getFindOptions: ->
    {
      regex: false
      caseSensitive: false
      inWord: false
      inSelection: false
    }


