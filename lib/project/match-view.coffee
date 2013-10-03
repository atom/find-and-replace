{View, Range} = require 'atom'

module.exports =
class SearchResultView extends View
  @content: ({filePath, match}) ->
    range = Range.fromObject(match.range)
    matchStart = range.start.column - match.lineTextOffset
    matchEnd = range.end.column - match.lineTextOffset
    prefix = match.lineText[match.lineTextOffset...matchStart]
    suffix = match.lineText[matchEnd..]

    @li class: 'search-result list-item', =>
      @span range.start.row + 1, class: 'line-number text-subtle'
      @span class: 'preview', =>
        @span prefix
        @span match.matchText, class: 'match highlight-info'
        @span suffix

  initialize: ({@filePath, @match}) ->

  confirm: ->
    editSession = rootView.open(@filePath)
    editSession.setSelectedBufferRange(@match.range, autoscroll: true)
