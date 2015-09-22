_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'
ResultView = require './result-view'

module.exports =
class ResultsView extends ScrollView
  @content: ->
    @ol class: 'results-view list-tree focusable-panel has-collapsable-children', tabindex: -1

  initialize: (@model) ->
    commandsDisposable = super()
    commandsDisposable.dispose() # turn off default scrolling behavior from ScrollView

    @pixelOverdraw = 100
    @lastRenderedResultIndex = 0

    @on 'mousedown', '.match-result, .path', ({target, which, ctrlKey}) =>
      @find('.selected').removeClass('selected')
      view = $(target).view()
      view.addClass('selected')
      view.confirm() if which is 1 and not ctrlKey
      @renderResults()

    @on 'scroll', => @renderResults()
    @on 'resize', => @renderResults()

  attached: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add @element,
      'core:move-down': =>
        @userMovedSelection = true
        @selectNextResult()
      'core:move-up': =>
        @userMovedSelection = true
        @selectPreviousResult()
      'core:move-left': => @collapseResult()
      'core:move-right': => @expandResult()
      'core:confirm': =>
        @find('.selected').view()?.confirm?()
        false
      'core:copy': =>
        @find('.selected').view()?.copy?()
        false

    @subscriptions.add @model.onDidAddResult @addResult
    @subscriptions.add @model.onDidRemoveResult @removeResult
    @subscriptions.add @model.onDidClearSearchState @clear

    @renderResults()

  detached: ->
    @clear()
    @subscriptions.dispose()

  hasResults: ->
    @model.getResultCount() > 0

  addResult: ({filePath, result, filePathInsertedIndex}) =>
    resultView = @getResultView(filePath)
    return resultView.renderResult(result) if resultView

    if filePathInsertedIndex? and (filePathInsertedIndex < @lastRenderedResultIndex or @shouldRenderMoreResults())
      children = @children()
      resultView = new ResultView(@model, filePath, result)

      if children.length is 0 or filePathInsertedIndex is children.length
        @append(resultView)
      else if filePathInsertedIndex is 0
        @prepend(resultView)
      else
        @element.insertBefore(resultView.element, children[filePathInsertedIndex])

      @lastRenderedResultIndex++

    @selectFirstResult() if not @userMovedSelection or @getPathCount() is 1

  removeResult: ({filePath}) =>
    @getResultView(filePath)?.remove()

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
    @prop('scrollHeight') <= @height() + @pixelOverdraw or @prop('scrollHeight') <= @scrollBottom() + @pixelOverdraw

  selectFirstResult: ->
    @find('.search-result:first').addClass('selected')

  selectNextResult: ->
    selectedView = @find('.selected').view()
    return @selectFirstResult() unless selectedView

    if selectedView.isExpanded
      nextView = selectedView.find('.search-result:first').view()
    else
      nextView = selectedView.next().view()

      unless nextView?
        nextParent = selectedView.closest('.path').next()
        nextView = if (not nextParent.hasClass('collapsed')) then nextParent.find('.search-result:first').view() else nextParent.view()
      else if nextView.isExpanded
        nextView = nextView.find('.search-result:first').view()

    # only select the next view if we found something
    if nextView?
      selectedView.removeClass('selected')
      nextView.addClass('selected')
      @scrollTo(nextView)

  selectPreviousResult: ->
    selectedView = @find('.selected').view()
    return @selectFirstResult() unless selectedView

    if selectedView.isExpanded
      prevView = selectedView.find('.search-result:last').view()
    else
      prevView = selectedView.prev().view()
      unless prevView?
        prevParent = selectedView.closest('.path').prev()
        prevView = if (not prevParent.hasClass('collapsed')) then prevParent.find('.search-result:last').view() else prevParent.view()
      else if prevView.isExpanded
        prevView = prevView.find('.search-result:last').view()

    # only select the prev view if we found something
    if prevView?
      selectedView.removeClass('selected')
      prevView.addClass('selected')
      @scrollTo(prevView)

  collapseResult: ->
    parent = @find('.selected').closest('.path').view()
    parent.expand(false) if parent instanceof ResultView
    @renderResults()

  expandResult: ->
    selectedView = @find('.selected').view()
    selectedView.expand(true) if selectedView instanceof ResultView
    @renderResults()

  getPathCount: ->
    @model.getPathCount()

  getMatchCount: ->
    @model.getMatchCount()

  clear: =>
    @userMovedSelection = false
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
