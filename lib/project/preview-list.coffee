{_, $, ScrollView} = require 'atom'
PathView = require './path-view'

module.exports =
class PreviewList extends ScrollView
  @content: ->
    @ol class: 'preview-list list-tree', tabindex: -1

  results: null
  viewsForPath: null
  pixelOverdraw: 100
  lastRenderedResultIndex: null

  initialize: ->
    super

    @on 'core:move-down', => @selectNextResult(); false
    @on 'core:move-up', => @selectPreviousResult(); false
    @on 'scroll', =>
      @renderResults() if @scrollBottom() >= @prop('scrollHeight')

  beforeRemove: ->
    @destroyResults() if @results

  hasResults: -> @results?

  populate: (results) ->
    @destroyResults() if @results?
    @results = results
    @lastRenderedResultIndex = 0
    @empty()
    @viewsForPath = {}

    @renderResults()

    @find('.search-result:first').addClass('selected')

  renderResults: ({renderAll}={}) ->
    renderAll ?= false
    startingScrollHeight = @prop('scrollHeight')
    for result in @results[@lastRenderedResultIndex..]
      pathView = @pathViewForPath(result.filePath)
      pathView.addResult(result)
      @lastRenderedResultIndex++
      break if not renderAll and @prop('scrollHeight') >= startingScrollHeight + @pixelOverdraw and @prop('scrollHeight') > @height() + @pixelOverdraw

  pathViewForPath: (path) ->
    pathView = @viewsForPath[path]
    if not pathView
      pathView = new PathView({path: path, previewList: this, resultCount: @getPathResultCount(path)})
      @viewsForPath[path] = pathView
      @append(pathView)
    pathView

  selectNextResult: ->
    selectedView = @find('.selected').view()
    nextView = selectedView.next().view()

    if selectedView instanceof PathView
      nextView = selectedView.find('.search-result:first').view() unless selectedView.hasClass('is-collapsed')
    else
      nextView ?= selectedView.closest('.path').next().view()

    if nextView?
      selectedView.removeClass('selected')
      nextView.addClass('selected')
      nextView.scrollTo()

  selectPreviousResult: ->
    selectedView = @find('.selected').view()
    previousView = selectedView.prev().view()

    if selectedView instanceof PathView
      if previousView? and not previousView.hasClass('is-collapsed')
        previousView = previousView.find('.search-result:last').view()
    else
      previousView ?= selectedView.closest('.path').view()

    if previousView?
      selectedView.removeClass('selected')
      previousView.addClass('selected')
      previousView.scrollTo()

  getPathCount: ->
    @results.length

  getMatchCount: ->
    count = 0
    count += matches.length for {filePath, matches} in @results
    count

  getPathResultCount: (filePath) ->
    result = _.find @results, (result) -> filePath is result.filePath
    result?.matches.length

  destroyResults: ->
    @results = null

  scrollTo: (top, bottom) ->
    @scrollBottom(bottom) if bottom > @scrollBottom()
    @scrollTop(top) if top < @scrollTop()

  scrollToBottom: ->
    @renderResults(renderAll: true)

    super()

    @find('.selected').removeClass('selected')
    lastPath = @find('.path:last')
    if lastPath.hasClass('is-collapsed')
      lastPath.addClass('selected')
    else
      lastPath.find('.search-result:last').addClass('selected')

  scrollToTop: ->
    super()

    @find('.selected').removeClass('selected')
    @find('.path:first').addClass('selected')
