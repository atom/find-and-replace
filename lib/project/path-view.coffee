{$, fs, View} = require 'atom-api'
SearchResultView = require './search-result-view'

module.exports =
class PathView extends View
  @content: ({path, previewList} = {}) ->
    iconClass = if fs.isReadmePath(path) then 'icon-book' else 'icon-file-text'
    @li class: 'path list-nested-item', =>
      @div outlet: 'pathDetails', class: 'path-details list-item', =>
        @span class: 'disclosure-arrow'
        @span class: iconClass + ' icon'
        @span class: 'path-name bright', path
        @span outlet: 'description', class: 'path-match-number'
      @ul outlet: 'matches', class: 'matches list-tree', =>

  initialize: ({@previewList, resultCount}) ->
    @pathDetails.on 'mousedown', => @toggle(true)
    @subscribe @previewList, 'find-and-replace:collapse-result', =>
      if @isSelected()
        @collapse()
        @previewList.renderResults()
    @subscribe @previewList, 'find-and-replace:expand-result', =>
      @expand() if @isSelected()
    @subscribe @previewList, 'core:confirm', =>
      if @hasClass('selected')
        @toggle(true)
        false

    @description.text("(#{resultCount})")

  addResult: (searchResult) ->
    @matches.append new SearchResultView({searchResult, @previewList})

  isSelected: ->
    @hasClass('selected') or @find('.selected').length

  setSelected: ->
    @previewList.find('.selected').removeClass('selected')
    @addClass('selected')

  toggle: ->
    if @hasClass('collapsed')
      @expand()
    else
      @collapse()

  expand: ->
    @removeClass 'collapsed'

  scrollTo: ->
    top = @previewList.scrollTop() + @offset().top - @previewList.offset().top
    bottom = top + @pathDetails.outerHeight()
    @previewList.scrollTo(top, bottom)

  collapse: ->
    @addClass 'collapsed'
    @setSelected() if @isSelected()
