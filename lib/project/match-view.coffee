{View} = require 'atom-space-pen-views'
{Range, CompositeDisposable} = require 'atom'

LeadingWhitespace = /^\s+/
removeLeadingWhitespace = (string) -> string.replace(LeadingWhitespace, '')

module.exports =
class MatchView extends View
  @content: (model, {filePath, match}) ->
    range = Range.fromObject(match.range)
    matchStart = range.start.column - match.lineTextOffset
    matchEnd = range.end.column - match.lineTextOffset
    prefix = removeLeadingWhitespace(match.lineText[0...matchStart])
    suffix = match.lineText[matchEnd..]
    contextBefore = match.contextBefore or []
    contextAfter = match.contextAfter or []

    @li class: 'search-result list-item', style: 'padding-top: 0; padding-bottom: 0', =>
      for i in [0...contextBefore.length]
        line = contextBefore[i]
        @div class: 'context context-before', =>
          @span range.start.row + 1 - (contextBefore.length - i), class: 'line-number text-subtle'
          @span line, class: 'preview', outlet: 'preview'
      @div class: 'matching-line', =>
        @span range.start.row + 1, class: 'line-number text-subtle'
        @span class: 'preview', outlet: 'preview', =>
          @span prefix
          @span match.matchText, class: 'match highlight-info', outlet: 'matchText'
          @span match.matchText, class: 'replacement highlight-success', outlet: 'replacementText'
          @span suffix
      for i in [0...contextAfter.length]
        line = contextAfter[i]
        @div class: 'context context-after', =>
          @span range.start.row + 1 + (i + 1), class: 'line-number text-subtle'
          @span line, class: 'preview', outlet: 'preview'
      if match.gapAfter
        @div '...', class: 'context gap-after'

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
    openInRightPane = atom.config.get('find-and-replace.openProjectFindResultsInRightPane')
    options.split = 'left' if openInRightPane
    editorPromise = atom.workspace.open(@filePath, options)
    editorPromise.then (editor) =>
      editor.setSelectedBufferRange(@match.range, autoscroll: true)
    editorPromise

  copy: ->
    atom.clipboard.write(@match.lineText)
