_ = require 'underscore-plus'
{$, View} = require 'atom'
fs = require 'fs-plus'
MatchView = require './match-view'
path = require 'path'

module.exports =
class ResultView extends View
  @content: (model, filePath, result) ->
    iconClass = if fs.isReadmePath(filePath) then 'icon-book' else 'icon-file-text'

    @li class: 'path list-nested-item', 'data-path': _.escapeAttribute(filePath), =>
      @div outlet: 'pathDetails', class: 'path-details list-item', =>
        @span class: 'disclosure-arrow'
        @span class: iconClass + ' icon'
        @span class: 'path-name bright', filePath.replace(atom.project.getPath()+path.sep, '')
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

    if not matches or matches.length == 0
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
        @find('.search-result:first').addClass('selected')
        
    else
      @addClass('collapsed')
      
      selected = @find('.selected').view()
      if selected?
        selected.removeClass('selected')
        @addClass('selected')
      
      selectedItem = @find('.selected').view()
        
    @isExpanded = expanded

  confirm: ->
    # unselect child element and select parent
    @find('.selected').removeClass('selected')
    @addClass('selected')

    @expand(not @isExpanded)
