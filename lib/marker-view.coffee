{$} = require 'atom'
{Subscriber} = require 'emissary'

module.exports =
class MarkerView
  Subscriber.includeInto(this)

  constructor: ({@editor, @marker} = {}) ->
    @regions = []
    @editSession = @editor.editor
    @element = document.createElement('div')
    @element.className = 'marker'
    @updateNeeded = @marker.isValid()
    @oldScreenRange = @getScreenRange()

    @subscribe @marker, 'changed', (event) => @onMarkerChanged(event)
    @subscribe @marker, 'attributes-changed', ({isCurrent}) => @updateCurrentClass(isCurrent)
    @subscribe @marker, 'destroyed', => @remove()
    @subscribe @editor, 'editor:display-updated', => @updateDisplay()

  remove: ->
    @unsubscribe()
    @marker = null
    @editor = null
    @element.remove()

  show: ->
    @element.style.display = ""

  hide: ->
    @element.style.display = "none"

  onMarkerChanged: ({isValid}) ->
    @updateNeeded = isValid
    if isValid then @show() else @hide()

  isUpdateNeeded: ->
    return false unless @updateNeeded and @editSession == @editor.editor

    oldScreenRange = @oldScreenRange
    newScreenRange = @getScreenRange()
    @oldScreenRange = newScreenRange
    @intersectsRenderedScreenRows(oldScreenRange) or @intersectsRenderedScreenRows(newScreenRange)

  intersectsRenderedScreenRows: (range) ->
    range.intersectsRowRange(@editor.firstRenderedScreenRow, @editor.lastRenderedScreenRow)

  updateCurrentClass: (isCurrent) ->
    if isCurrent
      $(@element).addClass('current-result')
    else
      $(@element).removeClass('current-result')

  updateDisplay: ->
    return unless @isUpdateNeeded()

    @updateNeeded = false
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
