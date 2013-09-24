{_, $, ScrollView} = require 'atom'
ResultView = require './result-view'

module.exports =
class ResultsView extends ScrollView
  @content: ->
    @ol class: 'results-view list-tree', tabindex: -1

  initialize: ->
    super

    @results = []
    @pixelOverdraw = 100
    @lastRenderedResultIndex = 0

    @on 'core:move-down', =>
      @selectNextResult()

    @on 'core:move-up', =>
      @selectPreviousResult()

    @on 'scroll', =>
      @renderResults() if @scrollBottom() >= @prop('scrollHeight')

    @on 'core:confirm', =>
      @find('.selected').view?().confirm?()

    @on 'mousedown', (e) =>
      @find('.selected').removeClass('selected')
      console.log e
      # @addClass('selected')

  beforeRemove: ->
    @clear()

  hasResults: ->
    @results.length > 0

  addResult: (result) ->
    @results.push(result)
    @renderResults()
    if @results.length == 1
      @find('.search-result:first').addClass('selected')

  renderResults: ({renderAll}={}) ->
    renderAll ?= false
    for result in @results[@lastRenderedResultIndex..]
      break if not renderAll and @prop('scrollHeight') > @height() + @pixelOverdraw
      resultView = new ResultView(result)
      @append(resultView)
      @lastRenderedResultIndex++

  selectNextResult: ->
    selectedView = @find('.selected').view()
    nextView = selectedView.next().view()

    if selectedView instanceof PathView
      nextView = selectedView.find('.search-result:first').view()
    else
      nextView ?= selectedView.closest('.path').next().view()

    if nextView?
      selectedView.removeClass('selected')
      nextView.addClass('selected')
      @scrollTo(nextView)

  selectPreviousResult: ->
    selectedView = @find('.selected').view()
    previousView = selectedView.prev().view()

    if selectedView instanceof PathView
      previousView = previousView.find('.search-result:last').view()
    else
      previousView ?= selectedView.closest('.path').view()

    if previousView?
      selectedView.removeClass('selected')
      previousView.addClass('selected')
      @scrollTo(previousView)

  getPathCount: ->
    @results.length

  getMatchCount: ->
    _.reduce @results, ((count, result) -> count + result.matches.length), 0

  clear: ->
    @results = []
    @lastRenderedResultIndex = 0
    @empty()

  scrollTo: (element) ->
    top = @scrollTop() + element.offset().top - @offset().top
    bottom = top + element.outerHeight()

    @scrollBottom(bottom) if bottom > @scrollBottom()
    @scrollTop(top) if top < @scrollTop()

  scrollToBottom: ->
    @renderResults(renderAll: true)

    super()

    @find('.selected').removeClass('selected')
    lastPath = @find('.path:last')
    lastPath.find('.search-result:last').addClass('selected')

  scrollToTop: ->
    super()

    @find('.selected').removeClass('selected')
    @find('.path:first').addClass('selected')
