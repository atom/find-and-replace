_ = require 'underscore'
Subscriber = require 'subscriber'

module.exports =
class MarkerView
  _.extend @prototype, Subscriber

  constructor: ({@editor, @marker} = {}) ->

    @regions = []
    @element = document.createElement('div')
    @element.className = 'marker'

    @updateDisplayPosition = @marker.isValid()

    @subscribe @marker, 'changed', @onMarkerChanged
    @subscribe @marker, 'destroyed', @remove
    @subscribe @editor, 'editor:display-updated', @onEditorDisplayUpdated

  remove: =>
    @unsubscribe()
    @marker = null
    @editor = null
    @element.remove()

  show: =>
    @element.style.display = ""

  hide: =>
    @element.style.display = "none"

  onMarkerChanged: ({isValid}) =>
    @updateDisplayPosition = isValid
    if isValid then @show() else @hide()

  onEditorDisplayUpdated: (eventProperties) =>
    if @updateDisplayPosition and @isMarkerVisible()
      @updateDisplay()
      @updateDisplayPosition = false

  isMarkerVisible: ->
    {start, end} = @getScreenRange()
    [firstRenderedRow, lastRenderedRow] = [@editor.firstRenderedScreenRow, @editor.lastRenderedScreenRow]
    end.row >= firstRenderedRow and start.row <= lastRenderedRow

  updateDisplay: ->
    @clearRegions()
    range = @getScreenRange()
    return if range.isEmpty()

    rowSpan = range.end.row - range.start.row

    if rowSpan == 0
      @appendRegion(1, range.start, range.end)
    else
      @appendRegion(1, range.start, null)
      if rowSpan > 1
        @appendRegion(rowSpan - 1, { row: range.start.row + 1, column: 0}, null)
      @appendRegion(1, { row: range.end.row, column: 0 }, range.end)

  appendRegion: (rows, start, end) ->
    { lineHeight, charWidth } = @editor
    css = @editor.pixelPositionForScreenPosition(start)
    css.height = lineHeight * rows
    if end
      css.width = @editor.pixelPositionForScreenPosition(end).left - css.left
    else
      css.right = 0

    region = document.createElement('div')
    region.className = 'region'
    for name, value of css
      region.style[name] = value + 'px'

    @element.appendChild(region)
    @regions.push(region)

  clearRegions: ->
    region.remove() for region in @regions
    @regions = []

  getScreenRange: ->
    @marker.getScreenRange()

  getBufferRange: ->
    @marker.getBufferRange()
