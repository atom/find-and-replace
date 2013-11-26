{_, $$$, Editor, View} = require 'atom'
FindModel = require './find-model'
FindResultsView = require './find-results-view'
History = require './history'

module.exports =
class FindView extends View

  @content: ->
    @div tabIndex: -1, class: 'find-and-replace tool-panel panel-bottom', =>
      @div class: 'block', =>
        @span outlet: 'descriptionLabel', class: 'description', 'Find in Current Buffer'
        @span class: 'options-label pull-right', =>
          @span 'Finding with Options: '
          @span outlet: 'optionsLabel', class: 'options'

      @ul outlet: 'errorMessages', class: 'error-messages block'

      @div class: 'find-container block', =>
        @div class: 'editor-container', =>
          @subview 'findEditor', new Editor(mini: true, placeholderText: 'Find in current buffer')

          @div class: 'find-meta-container', =>
            @span outlet: 'resultCounter', class: 'text-subtle result-counter', ''

        @div class: 'btn-group btn-group-find', =>
          @button outlet: 'previousButton', class: 'btn', 'Find Prev'
          @button outlet: 'nextButton', class: 'btn', 'Find Next'

        @div class: 'btn-group btn-toggle btn-group-options', =>
          @button outlet: 'regexOptionButton', class: 'btn', '.*'
          @button outlet: 'caseOptionButton', class: 'btn', 'Aa'
          @button outlet: 'selectionOptionButton', class: 'btn option-selection', '"'

      @div class: 'replace-container block', =>
        @div class: 'editor-container', =>
          @subview 'replaceEditor', new Editor(mini: true, placeholderText: 'Replace in current buffer')

        @div class: 'btn-group btn-group-replace', =>
          @button outlet: 'replacePreviousButton', class: 'btn btn-prev', 'Replace Prev'
          @button outlet: 'replaceNextButton', class: 'btn btn-next', 'Replace Next'

        @div class: 'btn-group btn-group-replace-all', =>
          @button outlet: 'replaceAllButton', class: 'btn btn-all', 'Replace All'

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
    @updateOptionsLabel()

  afterAttach: ->
    unless @tooltipsInitialized
      @regexOptionButton.setTooltip("Use Regex", command: 'find-and-replace:toggle-regex-option', commandElement: @findEditor)
      @caseOptionButton.setTooltip("Match Case", command: 'find-and-replace:toggle-case-option', commandElement: @findEditor)
      @selectionOptionButton.setTooltip("Only In Selection", command: 'find-and-replace:toggle-selection-option', commandElement: @findEditor)

      @previousButton.setTooltip("Find Previous", command: 'find-and-replace:find-previous', commandElement: @findEditor)
      @nextButton.setTooltip("Find Next", command: 'find-and-replace:find-next', commandElement: @findEditor)

      @replacePreviousButton.setTooltip("Replace Previous", command: 'find-and-replace:replace-previous', commandElement: @replaceEditor)
      @replaceNextButton.setTooltip("Replace Next", command: 'find-and-replace:replace-next', commandElement: @replaceEditor)
      @replaceAllButton.setTooltip("Replace All", command: 'find-and-replace:replace-all', commandElement: @replaceEditor)
      @tooltipsInitialized = true

  hideAllTooltips: ->
    @regexOptionButton.hideTooltip()
    @caseOptionButton.hideTooltip()
    @selectionOptionButton.hideTooltip()

    @previousButton.hideTooltip()
    @nextButton.hideTooltip()

    @replacePreviousButton.hideTooltip()
    @replaceNextButton.hideTooltip()
    @replaceAllButton.hideTooltip()

  serialize: ->
    findHistory: @findHistory.serialize()
    replaceHistory: @replaceHistory.serialize()
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

    atom.workspaceView.on 'selection:changed', @setCurrentMarkerFromSelection

  handleFindEvents: ->
    @nextButton.on 'click', => @findNext()
    @previousButton.on 'click', => @findPrevious()
    atom.workspaceView.command 'find-and-replace:find-next', @findNext
    atom.workspaceView.command 'find-and-replace:find-previous', @findPrevious
    atom.workspaceView.command 'find-and-replace:use-selection-as-find-pattern', @setSelectionAsFindPattern

  handleReplaceEvents: ->
    @replacePreviousButton.on 'click', @replacePrevious
    @replaceNextButton.on 'click', @replaceNext
    @replaceAllButton.on 'click', @replaceAll
    atom.workspaceView.command 'find-and-replace:replace-previous', @replacePrevious
    atom.workspaceView.command 'find-and-replace:replace-next', @replaceNext
    atom.workspaceView.command 'find-and-replace:replace-all', @replaceAll

  showFind: =>
    @attach() if not @hasParent()
    @findEditor.focus()
    @findEditor.selectAll()

  showReplace: =>
    @attach()
    @replaceEditor.redraw()
    @replaceEditor.focus()
    @replaceEditor.selectAll()

  attach: =>
    @findResultsView.attach()
    atom.workspaceView.vertical.append(this)

  detach: =>
    @hideAllTooltips()
    @findResultsView.detach()
    atom.workspaceView.focus()
    super()

  toggleFocus: =>
    if @findEditor.find(':focus').length > 0
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
    pattern = @findEditor.getText()
    @updateModel { pattern }

    if @markers.length == 0
      atom.beep()
    else
      selectFunction()
      atom.workspaceView.focus() if focusEditorAfter

  replaceNext: =>
    @replace('findNext', 'firstMarkerIndexAfterCursor')

  replacePrevious: =>
    @replace('findPrevious', 'firstMarkerIndexBeforeCursor')

  replace: (nextOrPreviousFn, nextIndexFn) ->
    pattern = @findEditor.getText()
    @updateModel { pattern }

    if @markers.length == 0
      atom.beep()
    else
      unless currentMarker = @currentResultMarker
        markerIndex = @[nextIndexFn]()
        currentMarker = @markers[markerIndex]

      @findModel.replace([currentMarker], @replaceEditor.getText())
      @[nextOrPreviousFn](false)

  replaceAll: =>
    @updateModel {pattern: @findEditor.getText()}
    @findModel.replace(@markers, @replaceEditor.getText())

  markersUpdated: (@markers) =>
    @setCurrentMarkerFromSelection()
    @updateOptionButtons()
    @updateDescription()
    @findResultsView.attach() if @isVisible()
    @findEditor.setText(@findModel.pattern)
    @findHistory.store()
    @replaceHistory.store()

  updateModel: (options) ->
    @clearMessages()
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

  updateDescription: ->
    results = @markers.length
    resultsStr = if results then _.pluralize(results, 'result') else 'No results'
    @descriptionLabel.text("#{resultsStr} found for '#{@findModel.pattern}'")

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

  addErrorMessage: (message) ->
    @errorMessages.append($$$ -> @li message)
    @errorMessages.show()

  hasErrors: ->
    !!@errorMessages.children().length

  updateOptionsLabel: ->
    label = []
    label.push('Regex') if @findModel.useRegex
    if @findModel.caseSensitive
      label.push('Case Sensitive')
    else
      label.push('Case Insensitive')
    label.push('Within Current Selection') if @findModel.inCurrentSelection
    @optionsLabel.text(label.join(', '))

  toggleRegexOption: =>
    @updateModel {pattern: @findEditor.getText(), useRegex: !@findModel.useRegex}
    @selectFirstMarkerAfterCursor()
    @updateOptionsLabel()

  toggleCaseOption: =>
    @updateModel {pattern: @findEditor.getText(), caseSensitive: !@findModel.caseSensitive}
    @selectFirstMarkerAfterCursor()
    @updateOptionsLabel()

  toggleSelectionOption: =>
    @updateModel {pattern: @findEditor.getText(), inCurrentSelection: !@findModel.inCurrentSelection}
    @selectFirstMarkerAfterCursor()
    @updateOptionsLabel()

  setOptionButtonState: (optionButton, selected) ->
    if selected
      optionButton.addClass 'selected'
    else
      optionButton.removeClass 'selected'

  updateOptionButtons: ->
    @setOptionButtonState(@regexOptionButton, @findModel.useRegex)
    @setOptionButtonState(@caseOptionButton, @findModel.caseSensitive)
    @setOptionButtonState(@selectionOptionButton, @findModel.inCurrentSelection)
