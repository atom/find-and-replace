{View} = require 'atom-space-pen-views'
{Range, CompositeDisposable} = require 'atom'

LeadingWhitespace = /^\s+/
removeLeadingWhitespace = (string) -> string.replace(LeadingWhitespace, '')

module.exports =
class MatchView extends View
  @content: (model, {filePath, match}) ->
    range = Range.fromObject(match.range)
    contextBefore = match.contextBefore or []
    contextAfter = match.contextAfter or []

    liClass = if match.CONTEXT_LINES == 0 then 'no-context' else ''
    @li class: 'search-result list-item ' + liClass, =>
      for i in [0...contextBefore.length]
        line = contextBefore[i]
        @div class: 'context context-before', =>
          @span range.start.row + 1 - (contextBefore.length - i), class: 'line-number text-subtle'
          @span line, class: 'preview', outlet: 'preview'
      @div class: 'matching-line', =>
        @span range.start.row + 1, class: 'line-number text-subtle'
        @span class: 'preview', outlet: 'preview', =>
          for rangeIndex in [0...@rangesCount(match)]
            [prefix, matchText, suffix] = @getPrefixAndSuffix(match, rangeIndex)
            @span prefix
            @span matchText, class: 'match highlight-info', outlet: 'matchText'
            @span '', class: 'replacement', outlet: 'replacementText'
            @span suffix
      for i in [0...contextAfter.length]
        line = contextAfter[i]
        @div class: 'context context-after', =>
          @span range.start.row + 1 + (i + 1), class: 'line-number text-subtle'
          @span line, class: 'preview', outlet: 'preview'
      if match.gapAfter
        @div '...', class: 'context gap-after'

  @rangesCount: (match) ->
    1 + (match.extraRanges or []).length

  @getPrefixAndSuffix: (match, rangeIndex) ->
    prevRange = @getRange(match, rangeIndex - 1)
    range = @getRange(match, rangeIndex)
    nextRange = @getRange(match, rangeIndex + 1)

    matchStart = range.start.column - match.lineTextOffset
    matchEnd = range.end.column - match.lineTextOffset

    matchText = match.lineText[matchStart...matchEnd]

    if !prevRange
      prefix = match.lineText[0...matchStart]
    else
      prefix = ''

    if !nextRange
      suffix = match.lineText[matchEnd..]
    else
      nextMatchStart = nextRange.start.column - match.lineTextOffset
      suffix = match.lineText[matchEnd...nextMatchStart]

    [prefix, matchText, suffix]

  @getRange: (match, rangeIndex) ->
    if rangeIndex == 0
      Range.fromObject(match.range)
    else if rangeIndex > 0 && match.extraRanges && (rangeIndex - 1 < match.extraRanges.length)
      Range.fromObject(match.extraRanges[rangeIndex - 1])


  initialize: (@model, {@filePath, @match}) ->
    @render()
    if fontFamily = atom.config.get('editor.fontFamily')
      @preview.css('font-family', fontFamily)

  attached: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add @model.getFindOptions().onDidChangeReplacePattern @render

  detached: -> @subscriptions.dispose()

  render: =>
    if @model.getFindOptions().replacePattern and @model.regex and not @model.replacedPathCount?
      replacementText = @match.matchText.replace(@model.regex, @model.getFindOptions().replacePattern)
      @replacementText.text(replacementText)
      @replacementText.show()
      @matchText.removeClass('highlight-info').addClass('highlight-error')
    else
      @replacementText.text('').hide()
      @matchText.removeClass('highlight-error').addClass('highlight-info')

  confirm: (options = {}) ->
    reverseDirections =
        left: 'right'
        right: 'left'
        up: 'down'
        down: 'up'
    openDirection = atom.config.get('find-and-replace.projectSearchResultsPaneSplitDirection')
    options.split = reverseDirections[openDirection] unless openDirection is 'none'
    editorPromise = atom.workspace.open(@filePath, options)
    editorPromise.then (editor) =>
      editor.setSelectedBufferRange(@match.range, autoscroll: true)
    editorPromise

  copy: ->
    atom.clipboard.write(@match.lineText)
