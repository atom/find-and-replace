{View, Range} = require 'atom'

module.exports =
class SearchResultView extends View
  @content: (previewList, filePath, match) ->
    range = Range.fromObject(match.range)
    prefix = match.lineText[match.lineTextOffset...(match.lineTextOffset + range.start.column)]
    suffix = match.lineText[(match.lineTextOffset + range.end.column)..]

    @li class: 'search-result list-item', =>
      @span range.start.row + 1, class: 'line-number text-subtle'
      @span class: 'preview', =>
        @span prefix
        @span match.matchText, class: 'match highlight-info'
        @span suffix

  initialize: (@previewList, @filePath, @match) ->
    @subscribe @previewList, 'core:confirm', =>
      if @hasClass('selected')
        @highlightResult()
        false
    @on 'mousedown', (e) =>
      @highlightResult()
      @previewList.find('.selected').removeClass('selected')
      @addClass('selected')

  highlightResult: ->
    editSession = rootView.open(@filePath)
    editSession.setSelectedBufferRange(@match.range, autoscroll: true)
    @previewList.focus()

  scrollTo: ->
    top = @previewList.scrollTop() + @offset().top - @previewList.offset().top
    bottom = top + @outerHeight()
    @previewList.scrollTo(top, bottom)
