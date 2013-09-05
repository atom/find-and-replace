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

    @subscribe @marker, 'changed', @onMarkerChanged
    @subscribe @marker, 'destroyed', @remove
    @subscribe @editor, 'editor:display-updated', @onEditorDisplayUpdated

  remove: =>
    @marker = null
    @editor = null
    super()

  onMarkerChanged: ({isValid}) =>
    @updateDisplayPosition = isValid
    if isValid != @isMarkerValid
      # @isMarkerValid is an optimization so we dont call into show or hide unless necessary
      if isValid then @show() else @hide()
      @isMarkerValid = isValid

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
    # FIXME: pixelPositionForScreenPosition is a major bottleneck with many
    # markers on the page.
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

  clearRegions: ->
    region.remove() for region in @regions
    @regions = []

  getScreenRange: ->
    @marker.getScreenRange()

  getBufferRange: ->
    @marker.getBufferRange()
