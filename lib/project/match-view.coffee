{View, Range} = require 'atom'

LeadingWhitespace = /^\s+/
removeLeadingWhitespace = (string) -> string.replace(LeadingWhitespace, '')

module.exports =
class MatchView extends View
  @content: ({filePath, match}) ->
    range = Range.fromObject(match.range)
    matchStart = range.start.column - match.lineTextOffset
    matchEnd = range.end.column - match.lineTextOffset
    prefix = removeLeadingWhitespace(match.lineText[match.lineTextOffset...matchStart])
    suffix = match.lineText[matchEnd..]

    @li class: 'search-result list-item', =>
      @span range.start.row + 1, class: 'line-number text-subtle'
      @span class: 'preview', =>
        @span prefix
        @span match.matchText, class: 'match highlight-info', outlet: 'matchText'
        @span suffix

  initialize: ({@filePath, @match}) ->

  updateReplacementPattern: (regex, pattern) ->
    @matchText.text(if pattern then @match.matchText.replace(regex, pattern) else @match.matchText)

  confirm: ->
    editSession = atom.workspaceView.openSingletonSync(@filePath, split: 'left')
    editSession.setSelectedBufferRange(@match.range, autoscroll: true)
