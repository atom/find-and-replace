_ = require 'underscore-plus'

module.exports =
  escapeHtml: (str) ->
    @escapeNode ?= document.createElement('div')
    @escapeNode.innerText = str
    @escapeNode.innerHTML

  escapeRegex: (str) ->
    str.replace /[.?*+^$[\]\\(){}|-]/g, (match) ->
      "\\" + match

  sanitizePattern: (pattern) ->
    pattern = @escapeHtml(pattern)
    pattern.replace(/\n/g, '\\n').replace(/\t/g, '\\t')

  getReplacementResultsMessage: ({findPattern, replacePattern, replacedPathCount, replacementCount}) ->
    if replacedPathCount
      "<span class=\"text-highlight\">Replaced <span class=\"highlight-error\">#{@sanitizePattern(findPattern)}</span> with <span class=\"highlight-success\">#{@sanitizePattern(replacePattern)}</span> #{_.pluralize(replacementCount, 'time')} in #{_.pluralize(replacedPathCount, 'file')}</span>"
    else
      "<span class=\"text-highlight\">Nothing replaced</span>"

  getSearchResultsMessage: ({findPattern, matchCount, pathCount, replacedPathCount}) ->
    if matchCount
      "#{_.pluralize(matchCount, 'result')} found in #{_.pluralize(pathCount, 'file')} for <span class=\"highlight-info\">#{@sanitizePattern(findPattern)}</span>"
    else
      "No #{if replacedPathCount? then 'more' else ''} results found for '#{@sanitizePattern(findPattern)}'"
