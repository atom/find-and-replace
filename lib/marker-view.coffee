{View, $$} = require 'space-pen'

module.exports =
class MarkerView extends View

  @content: ->
    @div class: 'marker'

  regions: null
  needsRemoval: false

  initialize: ({@editor, @marker} = {}) ->
    @regions = []

    @isMarkerValid = @marker.isValid()
    @updateDisplayPosition = @isMarkerValid
    @marker.on 'changed', ({newHeadScreenPosition, newTailScreenPosition, valid}) =>
      @updateDisplayPosition = valid
      if valid != @isMarkerValid
        # @isMarkerValid is an optimization so we dont call into show or hide unless necessary
        if valid then @show() else @hide()
        @isMarkerValid = valid

    @marker.on 'destroyed', => @remove()

    @subscribe @editor, 'editor:display-updated', =>
      @updateDisplay() if @updateDisplayPosition

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

    region = ($$ -> @div class: 'region').css(css)
    @append(region)
    @regions.push(region)

  getCenterPixelPosition: ->
    { start, end } = @getScreenRange()
    startRow = start.row
    endRow = end.row
    endRow-- if end.column == 0
    @editor.pixelPositionForScreenPosition([((startRow + endRow + 1) / 2), start.column])

  clearRegions: ->
    region.remove() for region in @regions
    @regions = []

  getScreenRange: ->
    @marker.getScreenRange()

  getBufferRange: ->
    @marker.getBufferRange()
