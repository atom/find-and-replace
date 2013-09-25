{_, $, fs, View} = require 'atom'
MatchView = require './match-view'

module.exports =
class ResultView extends View
  @content: (filePath, matches) ->
    iconClass = if fs.isReadmePath(filePath) then 'icon-book' else 'icon-file-text'

    @li class: 'path list-nested-item', 'data-path': _.escapeAttribute(filePath), =>
      @div outlet: 'pathDetails', class: 'path-details list-item', =>
        @span class: 'disclosure-arrow'
        @span class: iconClass + ' icon'
        @span class: 'path-name bright', filePath
        @span outlet: 'description', class: 'path-match-number'
      @ul outlet: 'matches', class: 'matches list-tree', =>

  initialize: (@filePath, matches) ->
    @renderMatches(matches)

  renderMatches: (matches) ->
    @matches.empty()
    @description.text("(#{matches?.length})")

    if not matches or matches.length == 0
      @hide()
    else
      @show()
      @matches.append new MatchView({@filePath, match}) for match in matches

    null

  confirm: ->
    editSession = rootView.open(@filePath)
