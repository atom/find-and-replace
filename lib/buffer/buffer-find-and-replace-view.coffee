{View} = require 'space-pen'
Editor = require 'editor'
EditSession = require 'edit-session'
$ = require 'jquery'
_ = require 'underscore'
{Point} = require 'telepath'
SearchModel = require '../search-model'
SearchResultsView = require '../search-results-view'
History = require '../history'

module.exports =
class BufferFindAndReplaceView extends View

  @content: ->
    @div class: 'find-and-replace buffer-find-and-replace tool-panel', =>
      @div class: 'find-container', =>
        @div class: 'btn-group pull-right btn-toggle', =>
          @button outlet: 'regexOptionButton', class: 'btn btn-mini option-regex', '.*'
          @button outlet: 'caseSensitiveOptionButton', class: 'btn btn-mini option-case-sensitive', 'Aa'
          @button outlet: 'inSelectionOptionButton', class: 'btn btn-mini option-in-selection', '"'

        @div class: 'find-editor-container editor-container', =>
          @div class: 'find-meta-container', =>
            @span outlet: 'resultCounter', class: 'result-counter', ''
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

  initialize: (@searchModel, history) ->
    @markerIndex = 0

    @findHistory = new History(@findEditor, history)
    @handleEvents()
    @updateOptionButtons()

  handleEvents: ->
    @searchModel.on 'change', @searchModelChanged

    rootView.command 'find-and-replace:show', @showFind
    @on 'core:cancel', @detach
    @on 'click', => @focusFind()

    @findEditor.on 'core:confirm', => @search()

    @previousButton.on 'click', => @selectPrevious()
    @nextButton.on 'click', => @selectNext()
    rootView.command 'find-and-replace:find-next', @selectNext
    rootView.command 'find-and-replace:find-previous', @selectPrevious

    @command 'find-and-replace:toggle-regex-option', @toggleRegexOption
    @command 'find-and-replace:toggle-case-sensitive-option', @toggleCaseSensitiveOption
    @command 'find-and-replace:toggle-in-selection-option', @toggleInSelectionOption
    @command 'find-and-replace:set-selection-as-search-pattern', @setSelectionAsSearchPattern

    @regexOptionButton.on 'click', @toggleRegexOption
    @caseSensitiveOptionButton.on 'click', @toggleCaseSensitiveOption
    @inSelectionOptionButton.on 'click', @toggleInSelectionOption

    # # #
    @replaceEditor.on 'core:confirm', @replaceNext
    @findEditor.on 'find-and-replace:focus-next', @focusReplace
    @findEditor.on 'find-and-replace:focus-previous', @focusReplace
    rootView.command 'find-and-replace:display-replace', @showReplace
    @replaceNextButton.on 'click', @replaceNext
    @replaceAllButton.on 'click', @replaceAll
    @replaceEditor.on 'find-and-replace:focus-next', @focusFind
    @replaceEditor.on 'find-and-replace:focus-previous', @focusFind
    @replaceLabel.on 'click', @focusReplace

    rootView.on 'pane-container:active-pane-item-changed', (event, item) =>
      if item instanceof EditSession
        @editSession = item
        @search()
      else
        @detach()

  search: ->
    @storePattern()
    @markers = @searchModel.getMarkers(@editSession)
    return if @markers.length == 0

    cursorPosition = @editSession.getCursorBufferPosition()
    @markerIndex = @firstMarkerIndexGreaterThanPosition(cursorPosition)
    @selectMarkerAtIndex(@markerIndex)

  firstMarkerIndexGreaterThanPosition: (bufferPosition) ->
    for marker, index in @markers
      markerStartPosition = marker.bufferMarker.getStartPosition()
      return index if markerStartPosition.isGreaterThanOrEqual(bufferPosition)

    0

  selectMarkerAtIndex: (markerIndex) ->
    marker = @markers[@markerIndex]
    @editSession.setSelectedBufferRange marker.getBufferRange()
    @resultCounter.text("#{markerIndex + 1} of #{@markers.length}")

  selectNext: =>
    @markerIndex = ++@markerIndex % @markers.length
    @selectMarkerAtIndex(@markerIndex)

  selectPrevious: =>
    @markerIndex--
    @markerIndex = @markers.length - 1 if @markerIndex < 0
    @selectMarkerAtIndex(@markerIndex)

  storePattern: ->
    pattern = @findEditor.getText()
    @searchModel.setPattern(pattern)

  searchModelChanged: =>
    @updateOptionButtons()
    @findEditor.setText(@searchModel.pattern)

  detach: =>
    @deactivate()
    rootView.focus()
    super()

  attach: =>
    paneItem = rootView.getActivePaneItem()
    if paneItem instanceof EditSession
      console.log "wtf"
      @editSession = paneItem
      rootView.vertical.append(this)
      @activate()

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

  replaceNext: =>
    @storePattern()
    replacement = @replaceEditor.getText()
    @currentEditor().trigger('find-and-replace:replace-next', {replacement})

  replaceAll: =>
    @storePattern()
    replacement = @replaceEditor.getText()
    @currentEditor().trigger('find-and-replace:replace-all', {replacement})

  setSelectionAsSearchPattern: =>
    editor = @currentEditor()
    pattern = editor.getSelectedText()

    if pattern
      @searchModel.setPattern(pattern)
      _.last(editor.getSelectionViews()).highlight()

    null

  toggleRegexOption: => @toggleOption('regex')

  toggleCaseSensitiveOption: =>
    @toggleOption('caseSensitive')

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
    # @active = true
    # view.activate() for view in @searchResultsViews

  deactivate: ->
    # @active = false
    # view.deactivate() for view in @searchResultsViews

  currentEditor: ->
    rootView.getActiveView()
