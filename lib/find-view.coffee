{View} = require 'space-pen'
Editor = require 'editor'
FindModel = require './find-model'
FindResultsView = require './find-results-view'
History = require './history'

module.exports =
class FindView extends View

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

  initialize: (@findModel, {findHistory, replaceHistory}) ->
    @findHistory = new History(@findEditor, findHistory)
    @replaceHistory = new History(@replaceEditor, replaceHistory)
    @findResultsView = new FindResultsView(@findModel)
    @handleEvents()
    @updateOptionButtons()

  handleEvents: ->
    @handleFindEvents()
    @handleReplaceEvents()

    @on 'core:cancel', @detach
    @on 'click', => @focus()

    @command 'find-and-replace:toggle-regex-option', @toggleRegexOption
    @command 'find-and-replace:toggle-case-sensitive-option', @toggleCaseSensitiveOption
    @command 'find-and-replace:toggle-in-selection-option', @toggleInSelectionOption

    @regexOptionButton.on 'click', @toggleRegexOption
    @caseSensitiveOptionButton.on 'click', @toggleCaseSensitiveOption
    @inSelectionOptionButton.on 'click', @toggleInSelectionOption

    @findModel.on 'updated', @markersUpdated

  handleFindEvents: ->
    rootView.command 'find-and-replace:show', @showFind
    @findEditor.on 'core:confirm', => @findNext()
    @nextButton.on 'click', => @findNext()
    @previousButton.on 'click', => @findPrevious()
    rootView.command 'find-and-replace:find-next', @findNext
    rootView.command 'find-and-replace:find-previous', @findPrevious
    rootView.command 'find-and-replace:use-selection-as-find-pattern', @setSelectionAsFindPattern

  handleReplaceEvents: ->
    rootView.command 'find-and-replace:show-replace', @showReplace
    @replaceEditor.on 'core:confirm', @replaceNext
    @replaceNextButton.on 'click', @replaceNext
    @replaceAllButton.on 'click', @replaceAll
    rootView.command 'find-and-replace:replace-next', @replaceNext
    rootView.command 'find-and-replace:replace-all', @replaceAll

  showFind: =>
    @attach()
    @addClass('find-mode').removeClass('replace-mode')
    @focus()

  showReplace: =>
    @attach()
    @addClass('replace-mode').removeClass('find-mode')
    @focus()

  focus: =>
    @replaceEditor.selectAll()
    @findEditor.selectAll()

    if @hasClass('find-mode')
      @findEditor.focus()
    else
      @replaceEditor.focus()

  attach: =>
    @findResultsView.attach()
    rootView.vertical.append(this)

  detach: =>
    @findResultsView.detach()
    rootView.focus()
    super()

  serialize: ->
    findHistory: @findHistory.serialize()
    replaceHistory: @replaceHistory.serialize()

  findNext: =>
    @findModel.update(@findEditor.getText())
    @selectFirstMarkerAfterCursor()
    rootView.focus() unless @markers.length == 0

  findPrevious: =>
    @findModel.update(@findEditor.getText())
    @selectFirstMarkerBeforeCursor()
    rootView.focus() unless @markers.length == 0

  replaceNext: =>
    @findModel.update(@findEditor.getText(), @replaceEditor.getText())

    markerIndex = @firstMarkerIndexAfterCursor()
    currentMarker = @markers[markerIndex]
    @findModel.replace([currentMarker])

    @findModel.getEditSession().setCursorBufferPosition currentMarker.bufferMarker.getEndPosition()

  replaceAll: =>
    @findModel.update(@findEditor.getText(), @replaceEditor.getText())
    @findModel.replace(@markers)

  markersUpdated: (@markers) =>
    @updateResultCounter()
    @updateOptionButtons()
    @findEditor.setText(@findModel.findPattern)
    @replaceEditor.setText(@findModel.replacePattern)
    @findHistory.store()
    @replaceHistory.store()

  updateResultCounter: ->
    if not @markers? or @markers.length == 0
      text = "no results"
    else if @markers.length == 1
      text = "1 found"
    else
      text = "#{@markers.length} found"

    @resultCounter.text text

  selectFirstMarkerAfterCursor: ->
    markerIndex = @firstMarkerIndexAfterCursor()
    @selectMarkerAtIndex(markerIndex)

  firstMarkerIndexAfterCursor: ->
    selection = @findModel.getEditSession().getSelection()
    {start, end} = selection.getBufferRange()
    start = end if selection.isReversed()

    for marker, index in @markers
      markerStartPosition = marker.bufferMarker.getStartPosition()
      return index if markerStartPosition.isGreaterThan(start)
    0

  selectFirstMarkerBeforeCursor: ->
    markerIndex = @firstMarkerIndexBeforeCursor()
    @selectMarkerAtIndex(markerIndex)

  firstMarkerIndexBeforeCursor: ->
    selection = @findModel.getEditSession().getSelection()
    {start, end} = selection.getBufferRange()
    start = end if selection.isReversed()

    for marker, index in @markers by -1
      markerEndPosition = marker.bufferMarker.getEndPosition()
      return index if markerEndPosition.isLessThan(start)

    @markers.length - 1

  selectMarkerAtIndex: (markerIndex) ->
    return unless @markers?.length > 0

    if marker = @markers[markerIndex]
      @findModel.getEditSession().setSelectedBufferRange marker.getBufferRange()
      rootView.one 'cursor:moved', => @updateResultCounter()
      @resultCounter.text("#{markerIndex + 1} of #{@markers.length}")

  setSelectionAsFindPattern: =>
    if text = @findModel.getEditSession().getSelectedText()
      @findEditor.setText(text)

  toggleRegexOption: =>
    @findModel.toggleOption('regex')
    @findNext()

  toggleCaseSensitiveOption: =>
    @findModel.toggleOption('caseSensitive')
    @findNext()

  toggleInSelectionOption: =>
    @findModel.toggleOption('inSelection')
    @findNext()

  setOptionButtonState: (optionButton, enabled) ->
    optionButton[if enabled then 'addClass' else 'removeClass']('enabled')

  updateOptionButtons: ->
    @setOptionButtonState(@regexOptionButton, @findModel.getOption('regex'))
    @setOptionButtonState(@caseSensitiveOptionButton, @findModel.getOption('caseSensitive'))
    @setOptionButtonState(@inSelectionOptionButton, @findModel.getOption('inSelection'))
