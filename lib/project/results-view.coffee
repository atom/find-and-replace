{_, $, ScrollView} = require 'atom'
ResultView = require './result-view'

module.exports =
class ResultsView extends ScrollView
  @content: ->
    @ol class: 'results-view list-tree focusable-panel', tabindex: -1

  initialize: ->
    super

    @pixelOverdraw = 100
    @lastRenderedResultIndex = 0

    @on 'core:move-down', =>
      @selectNextResult()

    @on 'core:move-up', =>
      @selectPreviousResult()

    @on 'scroll', =>
      @renderResults() if @shouldRenderMoreResults()

    @on 'core:confirm', =>
      @find('.selected').view?().confirm?()
      false

    @on 'mousedown', '.match-result, .path', (e) =>
      @find('.selected').removeClass('selected')
      view = $(e.srcElement).view()
      view.addClass('selected')
      view.confirm()

  setModel: (@model) ->
    @model.on 'result-added', @addResult
    @model.on 'result-removed', @removeResult

  beforeRemove: ->
    @clear()

  hasResults: ->
    @model.getResultCount() > 0

  addResult: (filePath, matches) =>
    resultView = @getResultView(filePath)

    if resultView
      resultView.renderMatches(matches)
    else
      @renderResults()
      @find('.search-result:first').addClass('selected') if @getPathCount() == 1

  removeResult: (filePath) =>
    resultView = @getResultView(filePath)
    resultView.renderMatches(null) if resultView

  renderResults: ({renderAll}={}) ->
    return unless renderAll or @shouldRenderMoreResults()

    paths = @model.getPaths()
    for filePath in paths[@lastRenderedResultIndex..]
      result = @model.getResult(filePath)
      break if not renderAll and not @shouldRenderMoreResults()
      resultView = new ResultView(filePath, result)
      @append(resultView)
      @lastRenderedResultIndex++

    null # dont return an array

  shouldRenderMoreResults: ->
    @prop('scrollHeight') <= @height() + @pixelOverdraw or @scrollBottom() + @pixelOverdraw >= @prop('scrollHeight')

  selectNextResult: ->
    selectedView = @find('.selected').view()
    nextView = selectedView.next().view()

    if selectedView instanceof ResultView
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

    if selectedView instanceof ResultView
      previousView = previousView?.find('.search-result:last').view()
    else
      previousView ?= selectedView.closest('.path').view()

    if previousView?
      selectedView.removeClass('selected')
      previousView.addClass('selected')
      @scrollTo(previousView)

  getPathCount: ->
    @model.getPathCount()

  getMatchCount: ->
    @model.getMatchCount()

  clear: ->
    @model.clear()
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

  getResultView: (filePath) ->
    el = @find("[data-path=\"#{_.escapeAttribute(filePath)}\"]")
    if el.length then el.view() else null
