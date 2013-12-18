{_} = require 'atom'

module.exports =
  escapeHtml: (str) ->
    @escapeNode ?= document.createElement('div')
    @escapeNode.innerText = str
    @escapeNode.innerHTML

  sanitizePattern: (pattern) ->
    pattern = @escapeHtml(pattern)
    pattern.replace(/\n/g, '\\n').replace(/\t/g, '\\t')

  getResultsMessage: (results) ->
    message = @getSearchResultsMessage(results)

    if results.replacedPathCount?
      replace = @getReplacementResultsMessage(results)
      message = "<span class=\"text-highlight\">#{replace}</span>. #{message}"

    message

  getReplacementResultsMessage: ({pattern, replacementPattern, replacedPathCount, replacementCount}) ->
    if replacedPathCount
      "Replaced <span class=\"highlight-error\">#{@sanitizePattern(pattern)}</span> with <span class=\"highlight-success\">#{@sanitizePattern(replacementPattern)}</span> #{_.pluralize(replacementCount, 'time')} in #{_.pluralize(replacedPathCount, 'file')}"
    else
      "Nothing replaced"

  getSearchResultsMessage: ({pattern, matchCount, pathCount, replacedPathCount}) ->
    if matchCount
      "#{_.pluralize(matchCount, 'result')} found in #{_.pluralize(pathCount, 'file')} for '#{@sanitizePattern(pattern)}'"
    else
      "No #{if replacedPathCount? then 'more' else ''} results found for '#{pattern}'"
