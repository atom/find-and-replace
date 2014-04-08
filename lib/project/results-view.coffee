_ = require 'underscore-plus'
{$, ScrollView} = require 'atom'
ResultView = require './result-view'

module.exports =
class ResultsView extends ScrollView
  @content: ->
    @ol class: 'results-view list-tree focusable-panel', tabindex: -1

  initialize: (@model) ->
    super

    @pixelOverdraw = 100
    @lastRenderedResultIndex = 0

    @on 'core:move-down', =>
      @selectNextResult()

    @on 'core:move-up', =>
      @selectPreviousResult()

    @on 'scroll resize', =>
      @renderResults() if @shouldRenderMoreResults()

    @on 'core:confirm', =>
      @find('.selected').view()?.confirm?()
      false

    @on 'mousedown', '.match-result, .path', ({target, which, ctrlKey}) =>
      @find('.selected').removeClass('selected')
      view = $(target).view()
      view.addClass('selected')
      view.confirm() if which is 1 and not ctrlKey

    @subscribe @model, 'result-added', @addResult
    @subscribe @model, 'result-removed', @removeResult
    @subscribe @model, 'search-state-cleared', @clear
    @renderResults()

  beforeRemove: ->
    @clear()

  hasResults: ->
    @model.getResultCount() > 0

  addResult: (filePath, result) =>
    resultView = @getResultView(filePath)

    if resultView
      resultView.renderResult(result)
    else
      @renderResults()
      @selectFirstResult() if @getPathCount() == 1

  removeResult: (filePath) =>
    resultView = @getResultView(filePath)
    resultView.renderResult(null) if resultView

  renderResults: ({renderAll}={}) ->
    return unless renderAll or @shouldRenderMoreResults()

    paths = @model.getPaths()
    for filePath in paths[@lastRenderedResultIndex..]
      result = @model.getResult(filePath)
      break if not renderAll and not @shouldRenderMoreResults()
      resultView = new ResultView(@model, filePath, result)
      @append(resultView)
      @lastRenderedResultIndex++

    null # dont return an array

  shouldRenderMoreResults: ->
    @prop('scrollHeight') <= @height() + @pixelOverdraw or @scrollBottom() + @pixelOverdraw >= @prop('scrollHeight')

  selectFirstResult: ->
    @find('.search-result:first').addClass('selected')

  selectNextResult: ->
    selectedView = @find('.selected').view()
    return @selectFirstResult() unless selectedView

    if selectedView instanceof ResultView
      nextView = selectedView.find('.search-result:first').view()
    else
      nextView = selectedView.next().view()
      nextView ?= selectedView.closest('.path').next().find('.search-result:first').view()

    if nextView?
      selectedView.removeClass('selected')
      nextView.addClass('selected')
      @scrollTo(nextView)

  selectPreviousResult: ->
    selectedView = @find('.selected').view()
    return @selectFirstResult() unless selectedView

    if selectedView instanceof ResultView
      previousView = selectedView.prev().find('.search-result:last').view()
    else
      previousView = selectedView.prev().view()
      previousView ?= selectedView.closest('.path').prev().find('.search-result:last').view()

    if previousView?
      selectedView.removeClass('selected')
      previousView.addClass('selected')
      @scrollTo(previousView)

  getPathCount: ->
    @model.getPathCount()

  getMatchCount: ->
    @model.getMatchCount()

  clear: =>
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
