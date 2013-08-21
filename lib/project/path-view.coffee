{View} = require 'space-pen'
fsUtils = require 'fs-utils'
SearchResultView = require './search-result-view'
$ = require 'jquery'

module.exports =
class PathView extends View
  @content: ({path, previewList} = {}) ->
    classes = ['path']
    classes.push('readme') if fsUtils.isReadmePath(path)
    @li class: classes.join(' '), =>
      @div outlet: 'pathDetails', class: 'path-details', =>
        @span class: 'path-name', path
        @span outlet: 'description', class: 'path-match-number'
      @ul outlet: 'matches', class: 'matches', =>

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
    if @hasClass('is-collapsed')
      @expand()
    else
      @collapse()

  expand: ->
    @matches.show()
    @removeClass 'is-collapsed'

  scrollTo: ->
    top = @previewList.scrollTop() + @offset().top - @previewList.offset().top
    bottom = top + @pathDetails.outerHeight()
    @previewList.scrollTo(top, bottom)

  collapse: ->
    @matches.hide()
    @addClass 'is-collapsed'
    @setSelected() if @isSelected()
