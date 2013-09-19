{View} = require 'atom'

module.exports =
class SearchResultView extends View
  @content: ({searchResult} = {}) ->
    {prefix, suffix, match, range} = searchResult.preview()
    @li class: 'search-result list-item', =>
      @span range.start.row + 1, class: 'line-number text-subtle'
      @span class: 'preview', =>
        @span prefix
        @span match, class: 'match highlight-info'
        @span suffix

  initialize: ({@previewList, @searchResult}) ->
    @subscribe @previewList, 'core:confirm', =>
      if @hasClass('selected')
        @highlightResult()
        false
    @on 'mousedown', (e) =>
      @highlightResult()
      @previewList.find('.selected').removeClass('selected')
      @addClass('selected')

  highlightResult: ->
    editSession = rootView.open(@searchResult.getPath())
    bufferRange = @searchResult.getBufferRange()
    editSession.setSelectedBufferRange(bufferRange, autoscroll: true) if bufferRange
    @previewList.focus()

  scrollTo: ->
    top = @previewList.scrollTop() + @offset().top - @previewList.offset().top
    bottom = top + @outerHeight()
    @previewList.scrollTo(top, bottom)
