shell = require 'shell'
{$$$, Editor, View} = require 'atom'
FindModel = require './find-model'
FindResultsView = require './find-results-view'
History = require './history'

module.exports =
class FindView extends View

  @content: ->
    @div tabIndex: -1, class: 'find-and-replace tool-panel panel-bottom', =>
      @ul outlet: 'errorMessages', class: 'error-messages block'
      @ul outlet: 'infoMessages', class: 'info-messages block'

      @div class: 'find-container block', =>
        @label class: 'text-subtle', 'Find'

        @div class: 'editor-container', =>
          @subview 'findEditor', new Editor(mini: true)

          @div class: 'find-meta-container', =>
            @span outlet: 'resultCounter', class: 'text-subtle result-counter', ''
            @a href: '#', outlet: 'previousButton', class: 'icon icon-chevron-left'
            @a href: '#', outlet: 'nextButton', class: 'icon icon-chevron-right'

        @div class: 'btn-group btn-toggle', =>
          @button outlet: 'regexOptionButton', class: 'btn btn-mini option-regex', '.*'
          @button outlet: 'caseOptionButton', class: 'btn btn-mini option-case', 'Aa'
          @button outlet: 'selectionOptionButton', class: 'btn btn-mini option-selection', '"'

      @div class: 'replace-container block', =>
        @label class: 'text-subtle', 'Replace'

        @div class: 'editor-container', =>
          @subview 'replaceEditor', new Editor(mini: true)

        @div class: 'btn-group btn-toggle', =>
          @button outlet: 'replaceNextButton', class: 'btn btn-mini btn-next', 'Next'
          @button outlet: 'replaceAllButton', class: 'btn btn-mini btn-all', 'All'


  initialize: ({showFind, showReplace, findHistory, replaceHistory, modelState}={}) ->
    @findModel = new FindModel(modelState)
    @findHistory = new History(@findEditor, findHistory)
    @replaceHistory = new History(@replaceEditor, replaceHistory)
    @findResultsView = new FindResultsView(@findModel)
    @handleEvents()
    @updateOptionButtons()

    if showFind
      @showFind()
    else if showReplace
      @showReplace()

    @clearMessages()

  serialize: ->
    findHistory: @findHistory.serialize()
    replaceHistory: @replaceHistory.serialize()
    showFind: @hasParent() and @hasClass('find-mode')
    showReplace: @hasParent() and @hasClass('replace-mode')
    modelState: @findModel.serialize()

  handleEvents: ->
    @handleFindEvents()
    @handleReplaceEvents()

    @findEditor.on 'core:confirm', => @confirm()
    @replaceEditor.on 'core:confirm', => @replaceNext()

    @on 'find-and-replace:focus-next', @toggleFocus
    @on 'find-and-replace:focus-previous', @toggleFocus

    @command 'find-and-replace:toggle-regex-option', @toggleRegexOption
    @command 'find-and-replace:toggle-case-option', @toggleCaseOption
    @command 'find-and-replace:toggle-selection-option', @toggleSelectionOption

    @regexOptionButton.on 'click', @toggleRegexOption
    @caseOptionButton.on 'click', @toggleCaseOption
    @selectionOptionButton.on 'click', @toggleSelectionOption

    @findModel.on 'updated', @markersUpdated

    rootView.on 'selection:changed', @setCurrentMarkerFromSelection

  handleFindEvents: ->
    @nextButton.on 'click', => @findNext()
    @previousButton.on 'click', => @findPrevious()
    rootView.command 'find-and-replace:find-next', @findNext
    rootView.command 'find-and-replace:find-previous', @findPrevious
    rootView.command 'find-and-replace:use-selection-as-find-pattern', @setSelectionAsFindPattern

  handleReplaceEvents: ->
    @replaceNextButton.on 'click', @replaceNext
    @replaceAllButton.on 'click', @replaceAll
    rootView.command 'find-and-replace:replace-next', @replaceNext
    rootView.command 'find-and-replace:replace-all', @replaceAll

  showFind: =>
    @attach()
    @addClass('find-mode').removeClass('replace-mode')
    @findEditor.focus()
    @findEditor.selectAll()

  showReplace: =>
    @attach()
    @addClass('replace-mode').removeClass('find-mode')
    @replaceEditor.redraw()
    @replaceEditor.focus()
    @replaceEditor.selectAll()

  attach: =>
    @findResultsView.attach()
    rootView.vertical.append(this)

  detach: =>
    @findResultsView.detach()
    rootView.focus()
    super()

  toggleFocus: =>
    if @hasClass('replace-mode') and @findEditor.find(':focus').length > 0
      @replaceEditor.focus()
    else
      @findEditor.focus()

  confirm: ->
    @findNext()

  findNext: (focusEditorAfter = true) =>
    @findAndSelectResult(@selectFirstMarkerAfterCursor, focusEditorAfter)

  findPrevious: (focusEditorAfter = true) =>
    @findAndSelectResult(@selectFirstMarkerBeforeCursor, focusEditorAfter)

  findAndSelectResult: (selectFunction, focusEditorAfter = true) =>
    @clearMessages()
    pattern = @findEditor.getText()
    @updateModel { pattern }

    if @markers.length == 0
      @addInfoMessage("No results found for '#{pattern}'") unless @hasErrors()
      shell.beep()
    else
      selectFunction()
      rootView.focus() if focusEditorAfter

  replaceNext: =>
    @clearMessages()
    pattern = @findEditor.getText()
    @updateModel { pattern }

    if @markers.length == 0
      @addInfoMessage("No results found for '#{pattern}'") unless @hasErrors()
      shell.beep()
    else
      unless currentMarker = @currentResultMarker
        markerIndex = @firstMarkerIndexAfterCursor()
        currentMarker = @markers[markerIndex]

      @findModel.replace([currentMarker], @replaceEditor.getText())
      @findNext(false)

  replaceAll: =>
    @updateModel {pattern: @findEditor.getText()}
    @findModel.replace(@markers, @replaceEditor.getText())

  markersUpdated: (@markers) =>
    @setCurrentMarkerFromSelection()
    @updateOptionButtons()
    @findResultsView.attach() if @isVisible()
    @findEditor.setText(@findModel.pattern)
    @findHistory.store()
    @replaceHistory.store()

  updateModel: (options) ->
    try
      @findModel.update(options)
    catch e
      @addErrorMessage(e.message)

  updateResultCounter: ->
    if @currentResultMarker
      index = @markers.indexOf(@currentResultMarker)
      text = "#{ index + 1} of #{@markers.length}"
    else
      if not @markers? or @markers.length == 0
        text = "no results"
      else if @markers.length == 1
        text = "1 found"
      else
        text = "#{@markers.length} found"

    @resultCounter.text text

  selectFirstMarkerAfterCursor: =>
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

  selectFirstMarkerBeforeCursor: =>
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
      @findModel.getEditSession().setSelectedBufferRange(marker.getBufferRange(), autoscroll: true)

  setCurrentMarkerFromSelection: =>
    if @currentResultMarker
      # HACK/TODO: telepath does not emit an event when attributes change. This
      # is the event I want, so emitting myself.
      @currentResultMarker.setAttributes(isCurrent: false)
      @currentResultMarker.emit('attributes-changed', {isCurrent: false})

    @currentResultMarker = null
    if @markers? and @markers.length and editSession = @findModel.getEditSession()
      selectedBufferRange = editSession.getSelectedBufferRange()
      @currentResultMarker = @findModel.findMarker(selectedBufferRange)

      if @currentResultMarker
        # HACK/TODO: telepath does not emit an event when attributes change. This
        # is the event I want, so emitting myself.
        @currentResultMarker.setAttributes(isCurrent: true)
        @currentResultMarker.emit('attributes-changed', {isCurrent: true})

    @updateResultCounter()

  setSelectionAsFindPattern: =>
    pattern = @findModel.getEditSession().getSelectedText()
    @updateModel {pattern}

  clearMessages: ->
    @errorMessages.hide().empty()
    @infoMessages.hide().empty()

  addInfoMessage: (message) ->
    @infoMessages.append($$$ -> @li message)
    @infoMessages.show()

  addErrorMessage: (message) ->
    @errorMessages.append($$$ -> @li message)
    @errorMessages.show()

  hasErrors: ->
    !!@errorMessages.children().length

  toggleRegexOption: =>
    @updateModel {pattern: @findEditor.getText(), useRegex: !@findModel.useRegex}
    @selectFirstMarkerAfterCursor()

  toggleCaseOption: =>
    @updateModel {pattern: @findEditor.getText(), caseInsensitive: !@findModel.caseInsensitive}
    @selectFirstMarkerAfterCursor()

  toggleSelectionOption: =>
    @updateModel {pattern: @findEditor.getText(), inCurrentSelection: !@findModel.inCurrentSelection}
    @selectFirstMarkerAfterCursor()

  setOptionButtonState: (optionButton, selected) ->
    if selected
      optionButton.addClass 'selected'
    else
      optionButton.removeClass 'selected'

  updateOptionButtons: ->
    @setOptionButtonState(@regexOptionButton, @findModel.useRegex)
    @setOptionButtonState(@caseOptionButton, @findModel.caseInsensitive)
    @setOptionButtonState(@selectionOptionButton, @findModel.inCurrentSelection)
