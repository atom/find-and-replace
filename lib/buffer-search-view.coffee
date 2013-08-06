_ = require 'underscore'
Selection = require 'selection'
SelectionView = require 'selection-view'

module.exports =
class BufferSearchView
  # options - 
  #   editor: an Atom Editor!
  constructor: (@bufferSearch, {@editor}={}) ->
    @searchResults = []
    @bufferSearch.on 'search', @onSearch

  setEditor: (@editor) ->

  onSearch: ({ranges}) =>
    @markRanges(ranges)

  markRanges: (ranges) ->
    @unmarkRanges()
    @searchResults = (new SearchResultView(@editor, range) for range in ranges)

  unmarkRanges: ->
    result.destroy() for result in @searchResults
    @searchResults = []


class SearchResultView
  constructor: (@editor, bufferRange) ->
    @marker = @editor.activeEditSession.markBufferRange(bufferRange, @getMarkerAttributes())
    @selection = new Selection(_.extend({editSession: @editor.activeEditSession, @marker}, @getMarkerAttributes()))
    @selectionView = new SelectionView({editor: @editor, @selection})
    @editor.underlayer.append(@selectionView.addClass('search-result'))

    @editor.on 'editor:display-updated', @onDisplayUpdated 

  destroy: ->
    @editor.off 'editor:display-updated', @onDisplayUpdated
    @selection.destroy()
    @selectionView.remove()

  onDisplayUpdated: =>
    _.nextTick =>
      @selectionView.updateDisplay()

  getMarkerAttributes: (attributes={}) ->
    _.extend attributes, 
      class: 'search-result'
      displayBufferId: @editor.activeEditSession.displayBuffer.id
      invalidationStratrgy: 'between'