_ = require 'underscore-plus'
{$$$, View} = require 'space-pen'
{TextEditorView} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'
FindModel = require './find-model'
{HistoryCycler} = require './history'


module.exports =
class FindView extends View
  @content: ->
    @div tabIndex: -1, class: 'find-and-replace', =>
      @div class: 'block', =>
        @span outlet: 'descriptionLabel', class: 'description', 'Find in Current Buffer'
        @span class: 'options-label pull-right', =>
          @span 'Finding with Options: '
          @span outlet: 'optionsLabel', class: 'options'

      @div class: 'find-container block', =>
        @div class: 'editor-container', =>
          @subview 'findEditor', new TextEditorView(mini: true, placeholderText: 'Find in current buffer')

          @div class: 'find-meta-container', =>
            @span outlet: 'resultCounter', class: 'text-subtle result-counter', ''

        @div class: 'btn-group btn-group-find', =>
          @button outlet: 'nextButton', class: 'btn', 'Find'

        @div class: 'btn-group btn-toggle btn-group-options', =>
          @button outlet: 'regexOptionButton', class: 'btn', '.*'
          @button outlet: 'caseOptionButton', class: 'btn', 'Aa'
          @button outlet: 'selectionOptionButton', class: 'btn option-selection', '"'
          @button outlet: 'wholeWordOptionButton', class: 'btn option-whole-word', '\\b'

      @div class: 'replace-container block', =>
        @div class: 'editor-container', =>
          @subview 'replaceEditor', new TextEditorView(mini: true, placeholderText: 'Replace in current buffer')

        @div class: 'btn-group btn-group-replace', =>
          @button outlet: 'replaceNextButton', class: 'btn btn-next', 'Replace'

        @div class: 'btn-group btn-group-replace-all', =>
          @button outlet: 'replaceAllButton', class: 'btn btn-all', 'Replace All'

  initialize: (@findModel, {findHistory, replaceHistory}) ->
    @subscriptions = new CompositeDisposable
    @findHistory = new HistoryCycler(@findEditor, findHistory)
    @replaceHistory = new HistoryCycler(@replaceEditor, replaceHistory)
    @handleEvents()
    @updateOptionButtons()

    @clearMessage()
    @updateOptionsLabel()

  destroy: ->
    @subscriptions.dispose()

  setPanel: (@panel) ->
    @subscriptions.add @panel.onDidChangeVisible (visible) =>
      if visible then @didShow() else @didHide()

  didShow: ->
    atom.workspaceView.addClass('find-visible')
    # unless @tooltipsInitialized
    #   @regexOptionButton.setTooltip("Use Regex", command: 'find-and-replace:toggle-regex-option', commandElement: @findEditor)
    #   @caseOptionButton.setTooltip("Match Case", command: 'find-and-replace:toggle-case-option', commandElement: @findEditor)
    #   @selectionOptionButton.setTooltip("Only In Selection", command: 'find-and-replace:toggle-selection-option', commandElement: @findEditor)
    #
    #   @nextButton.setTooltip("Find Next", command: 'find-and-replace:find-next', commandElement: @findEditor)
    #
    #   @replaceNextButton.setTooltip("Replace Next", command: 'find-and-replace:replace-next', commandElement: @replaceEditor)
    #   @replaceAllButton.setTooltip("Replace All", command: 'find-and-replace:replace-all', commandElement: @replaceEditor)
    #   @tooltipsInitialized = true

  didHide: ->
    @hideAllTooltips()
    atom.workspaceView.focus()
    atom.workspaceView.removeClass('find-visible')

  hideAllTooltips: ->
  #   @regexOptionButton.hideTooltip()
  #   @caseOptionButton.hideTooltip()
  #   @selectionOptionButton.hideTooltip()
  #
  #   @nextButton.hideTooltip()
  #
  #   @replaceNextButton.hideTooltip()
  #   @replaceAllButton.hideTooltip()

  handleEvents: ->
    @handleFindEvents()
    @handleReplaceEvents()

    @findEditor.on 'core:confirm', => @confirm()
    @findEditor.on 'find-and-replace:confirm', => @confirm()
    @findEditor.on 'find-and-replace:show-previous', => @showPrevious()
    @findEditor.on 'find-and-replace:find-all', => @findAll()

    @replaceEditor.on 'core:confirm', => @replaceNext()

    @on 'find-and-replace:focus-next', @toggleFocus
    @on 'find-and-replace:focus-previous', @toggleFocus
    @on 'focus', (e) => @findEditor.focus()

    @subscriptions.add atom.commands.add this[0],
      'core:close': => @panel?.hide()
      'core:cancel': => @panel?.hide()
      'find-and-replace:toggle-regex-option': @toggleRegexOption
      'find-and-replace:toggle-case-option': @toggleCaseOption
      'find-and-replace:toggle-selection-option': @toggleSelectionOption
      'find-and-replace:toggle-whole-word-option': @toggleWholeWordOption

    @regexOptionButton.on 'click', @toggleRegexOption
    @caseOptionButton.on 'click', @toggleCaseOption
    @selectionOptionButton.on 'click', @toggleSelectionOption
    @wholeWordOptionButton.on 'click', @toggleWholeWordOption

    @subscriptions.add @findModel.onDidUpdate @markersUpdated
    @subscriptions.add @findModel.onDidError @findError
    @subscriptions.add @findModel.onDidChangeCurrentResult @updateResultCounter

    @find('button').on 'click', =>
      atom.workspaceView.focus()

  handleFindEvents: ->
    @findEditor.getModel().onDidStopChanging => @liveSearch()
    @nextButton.on 'click', => @findNext(focusEditorAfter: true)
    @subscriptions.add atom.commands.add 'atom-workspace',
      'find-and-replace:find-next': => @findNext(focusEditorAfter: true)
      'find-and-replace:find-previous': => @findPrevious(focusEditorAfter: true)
      'find-and-replace:use-selection-as-find-pattern': @setSelectionAsFindPattern

  handleReplaceEvents: ->
    @replaceNextButton.on 'click', @replaceNext
    @replaceAllButton.on 'click', @replaceAll
    @subscriptions.add atom.commands.add 'atom-workspace',
      'find-and-replace:replace-previous': @replacePrevious
      'find-and-replace:replace-next': @replaceNext
      'find-and-replace:replace-all': @replaceAll

  focusFindEditor: =>
    selectedText = atom.workspace.getActiveEditor()?.getSelectedText?()
    if selectedText and selectedText.indexOf('\n') < 0
      @findEditor.setText(selectedText)
    @findEditor.focus()
    @findEditor.getModel().selectAll()

  focusReplaceEditor: =>
    @replaceEditor.focus()
    @replaceEditor.getModel().selectAll()

  toggleFocus: =>
    if @findEditor.find(':focus').length > 0
      @replaceEditor.focus()
    else
      @findEditor.focus()

  confirm: ->
    @findNext(focusEditorAfter: atom.config.get('find-and-replace.focusEditorAfterSearch'))

  showPrevious: ->
    @findPrevious(focusEditorAfter: atom.config.get('find-and-replace.focusEditorAfterSearch'))

  liveSearch: ->
    pattern = @findEditor.getText()
    @updateModel { pattern }

  findAll: (options={focusEditorAfter: true}) =>
    @findAndSelectResult(@selectAllMarkers, options)

  findNext: (options={focusEditorAfter: false}) =>
    @findAndSelectResult(@selectFirstMarkerAfterCursor, options)

  findPrevious: (options={focusEditorAfter: false}) =>
    @findAndSelectResult(@selectFirstMarkerBeforeCursor, options)

  findAndSelectResult: (selectFunction, {focusEditorAfter, fieldToFocus}) =>
    pattern = @findEditor.getText()
    @updateModel { pattern }
    @findHistory.store()

    if @markers.length == 0
      atom.beep()
    else
      selectFunction()
      if fieldToFocus
        fieldToFocus.focus()
      else if focusEditorAfter
        atom.workspaceView.focus()
      else
        @findEditor.focus()

  replaceNext: =>
    @replace('findNext', 'firstMarkerIndexAfterCursor')

  replacePrevious: =>
    @replace('findPrevious', 'firstMarkerIndexBeforeCursor')

  replace: (nextOrPreviousFn, nextIndexFn) ->
    pattern = @findEditor.getText()
    @updateModel { pattern }
    @findHistory.store()
    @replaceHistory.store()

    if @markers.length == 0
      atom.beep()
    else
      unless currentMarker = @findModel.currentResultMarker
        markerIndex = @[nextIndexFn]()
        currentMarker = @markers[markerIndex]

      @findModel.replace([currentMarker], @replaceEditor.getText())
      @[nextOrPreviousFn](fieldToFocus: @replaceEditor)

  replaceAll: =>
    @updateModel {pattern: @findEditor.getText()}
    @replaceHistory.store()
    @findHistory.store()
    @findModel.replace(@markers, @replaceEditor.getText())

  markersUpdated: (@markers) =>
    @findError = null
    @updateOptionButtons()
    @updateResultCounter()

    if @findModel.pattern
      results = @markers.length
      resultsStr = if results then _.pluralize(results, 'result') else 'No results'
      @setInfoMessage("#{resultsStr} found for '#{@findModel.pattern}'")
    else
      @clearMessage()

    if @findModel.pattern isnt @findEditor.getText()
      @findEditor.setText(@findModel.pattern)

  findError: (error) =>
    @setErrorMessage(error.message)

  updateModel: (options) ->
    @findModel.update(options)

  updateResultCounter: =>
    if @findModel.currentResultMarker and (index = @markers.indexOf(@findModel.currentResultMarker)) > -1
      text = "#{ index + 1} of #{@markers.length}"
    else
      if not @markers? or @markers.length == 0
        text = "no results"
      else if @markers.length == 1
        text = "1 found"
      else
        text = "#{@markers.length} found"

    @resultCounter.text text

  setInfoMessage: (infoMessage) ->
    @descriptionLabel.text(infoMessage).removeClass('text-error')

  setErrorMessage: (errorMessage) ->
    @descriptionLabel.text(errorMessage).addClass('text-error')

  clearMessage: ->
    @descriptionLabel.html('Find in Current Buffer <span class="subtle-info-message">Close this panel with the <span class="highlight">esc</span> key</span>').removeClass('text-error')

  selectFirstMarkerAfterCursor: =>
    markerIndex = @firstMarkerIndexAfterCursor()
    @selectMarkerAtIndex(markerIndex)

  firstMarkerIndexAfterCursor: ->
    editor = @findModel.getEditor()
    return -1 unless editor

    selection = editor.getLastSelection()
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
    editor = @findModel.getEditor()
    return -1 unless editor

    selection = @findModel.getEditor().getLastSelection()
    {start, end} = selection.getBufferRange()
    start = end if selection.isReversed()

    for marker, index in @markers by -1
      markerEndPosition = marker.bufferMarker.getEndPosition()
      return index if markerEndPosition.isLessThan(start)

    @markers.length - 1

  selectAllMarkers: =>
    return unless @markers?.length > 0
    ranges = (marker.getBufferRange() for marker in @markers)
    scrollMarker = @markers[@firstMarkerIndexAfterCursor()]
    editor = @findModel.getEditor()
    editor.setSelectedBufferRanges(ranges, flash: true)
    editor.scrollToBufferPosition(scrollMarker.getStartBufferPosition(), center: true)

  selectMarkerAtIndex: (markerIndex) ->
    return unless @markers?.length > 0

    if marker = @markers[markerIndex]
      editor = @findModel.getEditor()
      editor.setSelectedBufferRange(marker.getBufferRange(), flash: true)
      editor.scrollToCursorPosition(center: true)

  setSelectionAsFindPattern: =>
    pattern = @findModel.getEditor().getSelectedText()
    @updateModel {pattern}

  updateOptionsLabel: ->
    label = []
    label.push('Regex') if @findModel.useRegex
    if @findModel.caseSensitive
      label.push('Case Sensitive')
    else
      label.push('Case Insensitive')
    label.push('Within Current Selection') if @findModel.inCurrentSelection
    label.push('Whole Word') if @findModel.wholeWord
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

  toggleWholeWordOption: =>
    @updateModel {pattern: @findEditor.getText(), wholeWord: !@findModel.wholeWord}
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
    @setOptionButtonState(@wholeWordOptionButton, @findModel.wholeWord)
