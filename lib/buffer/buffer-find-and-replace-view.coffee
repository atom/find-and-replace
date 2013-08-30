{View} = require 'space-pen'
Editor = require 'editor'
SearchModel = require '../search-model'
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

  initialize: (@searchModel, history) ->
    @findHistory = new History(@findEditor, history)
    @handleEvents()
    @updateOptionButtons()

  handleEvents: ->
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

    @searchModel.on 'change', @searchModelChanged
    @searchModel.on 'markers-updated', @markersUpdated

  showFind: =>
    @attach()
    @addClass('find-mode').removeClass('replace-mode')
    @focusFind()

  focusFind: =>
    @replaceEditor.selectAll()
    @findEditor.selectAll()
    @findEditor.focus()

  attach: =>
    rootView.vertical.append(this)

  detach: =>
    rootView.focus()
    super()

  search: ->
    @searchModel.setPattern(@findEditor.getText())
    @searchModel.search()

  markersUpdated: (@markers) =>
    rootView.one 'cursor:moved', => @updateResultCounter()

    @updateResultCounter()
    if markers.length > 0
      cursorPosition = @searchModel.getEditSession().getCursorBufferPosition()
      @currentMarkerIndex = @firstMarkerIndexGreaterThanPosition(cursorPosition)
      @selectMarkerAtIndex(@currentMarkerIndex)

  updateResultCounter: ->
    if not @markers? or @markers.length == 0
      text = "no results"
    else if @markers.length == 1
      text = "1 found"
    else
      text = "#{@markers.length} found"

    @resultCounter.text text

  searchModelChanged: =>
    @updateOptionButtons()
    @findEditor.setText(@searchModel.pattern)

  firstMarkerIndexGreaterThanPosition: (bufferPosition) ->
    for marker, index in @markers
      markerStartPosition = marker.bufferMarker.getStartPosition()
      return index if markerStartPosition.isGreaterThanOrEqual(bufferPosition)
    0

  selectMarkerAtIndex: (markerIndex) ->
    marker = @markers[markerIndex]
    @searchModel.getEditSession().setSelectedBufferRange marker.getBufferRange()
    @resultCounter.text("#{markerIndex + 1} of #{@markers.length}")

  selectNext: =>
    @currentMarkerIndex = ++@currentMarkerIndex % @markers.length
    @selectMarkerAtIndex(@currentMarkerIndex)

  selectPrevious: =>
    @currentMarkerIndex--
    @currentMarkerIndex = @markers.length - 1 if @currentMarkerIndex < 0
    @selectMarkerAtIndex(@currentMarkerIndex)

  setSelectionAsSearchPattern: =>
    editSession = @searchModel.getEditSession()

    if pattern = editSession.getSelectedText()
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

  # handleReplaceEvents: ->
  #   @replaceEditor.on 'core:confirm', @replaceNext
  #   @findEditor.on 'find-and-replace:focus-next', @focusReplace
  #   @findEditor.on 'find-and-replace:focus-previous', @focusReplace
  #   rootView.command 'find-and-replace:display-replace', @showReplace
  #   @replaceNextButton.on 'click', @replaceNext
  #   @replaceAllButton.on 'click', @replaceAll
  #   @replaceEditor.on 'find-and-replace:focus-next', @focusFind
  #   @replaceEditor.on 'find-and-replace:focus-previous', @focusFind
  #   @replaceLabel.on 'click', @focusReplace
  #
  #
  # showReplace: =>
  #   @attach()
  #   @addClass('replace-mode').removeClass('find-mode')
  #   @focusReplace()
  #
  # focusReplace: =>
  #   return unless @hasClass('replace-mode')
  #   @findEditor.clearSelections()
  #   @replaceEditor.selectAll()
  #   @replaceEditor.focus()
  #
  # replaceNext: =>
  #   @storePattern()
  #   replacement = @replaceEditor.getText()
  #   @currentEditor().trigger('find-and-replace:replace-next', {replacement})
  #
  # replaceAll: =>
  #   @storePattern()
  #   replacement = @replaceEditor.getText()
  #   @currentEditor().trigger('find-and-replace:replace-all', {replacement})
