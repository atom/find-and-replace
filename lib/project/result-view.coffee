_ = require 'underscore-plus'
{$, View} = require 'atom-space-pen-views'
fs = require 'fs-plus'
MatchView = require './match-view'
path = require 'path'

module.exports =
class ResultView extends View
  @content: (model, filePath, result) ->
    iconClass = if fs.isReadmePath(filePath) then 'icon-book' else 'icon-file-text'
    fileBasename = path.basename(filePath)

    if atom.project?
      [rootPath, relativePath] = atom.project.relativizePath(filePath)
      if rootPath? and atom.project.getDirectories().length > 1
        relativePath = path.join(path.basename(rootPath), relativePath)
    else
      relativePath = filePath

    @li class: 'path list-nested-item', 'data-path': _.escapeAttribute(filePath), =>
      @div outlet: 'pathDetails', class: 'path-details list-item', =>
        @span class: 'disclosure-arrow'
        @span class: iconClass + ' icon', 'data-name': fileBasename
        @span class: 'path-name bright', relativePath
        @span outlet: 'description', class: 'path-match-number'
      @ul outlet: 'matches', class: 'matches list-tree'

  initialize: (@model, @filePath, result) ->
    @isExpanded = true
    @renderResult(result)

  renderResult: (result) ->
    matches = result?.matches
    selectedIndex = @matches.find('.selected').index()

    @matches.empty()

    if result
      @description.show().text("(#{matches?.length})")
    else
      @description.hide()

    if not matches or matches.length is 0
      @hide()
    else
      @show()
      for match in matches
        @matches.append(new MatchView(@model, {@filePath, match}))

    @matches.children().eq(selectedIndex).addClass('selected') if selectedIndex > -1

  expand: (expanded) ->
    # expand or collapse the list
    if expanded
      @removeClass('collapsed')

      if @hasClass('selected')
        @removeClass('selected')
        firstResult = @find('.search-result:first').view()
        firstResult.addClass('selected')

        # scroll to the proper place
        resultView = firstResult.closest('.results-view').view()
        resultView.scrollTo(firstResult)

    else
      @addClass('collapsed')

      selected = @find('.selected').view()
      if selected?
        selected.removeClass('selected')
        @addClass('selected')

        resultView = @closest('.results-view').view()
        resultView.scrollTo(this)

      selectedItem = @find('.selected').view()

    @isExpanded = expanded

  confirm: ->
    @expand(not @isExpanded)
