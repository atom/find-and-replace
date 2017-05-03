_ = require 'underscore-plus'

escapeNode = null

escapeHtml = (str) ->
  escapeNode ?= document.createElement('div')
  escapeNode.innerText = str
  escapeNode.innerHTML

escapeRegex = (str) ->
  str.replace /[.?*+^$[\]\\(){}|-]/g, (match) -> "\\" + match

sanitizePattern = (pattern) ->
  pattern = escapeHtml(pattern)
  pattern.replace(/\n/g, '\\n').replace(/\t/g, '\\t')

getReplacementResultsMessage = ({findPattern, replacePattern, replacedPathCount, replacementCount}) ->
  if replacedPathCount
    "<span class=\"text-highlight\">Replaced <span class=\"highlight-error\">#{sanitizePattern(findPattern)}</span> with <span class=\"highlight-success\">#{sanitizePattern(replacePattern)}</span> #{_.pluralize(replacementCount, 'time')} in #{_.pluralize(replacedPathCount, 'file')}</span>"
  else
    "<span class=\"text-highlight\">Nothing replaced</span>"

getSearchResultsMessage = (results) ->
  if results?.findPattern?
    {findPattern, matchCount, pathCount, replacedPathCount} = results
    if matchCount
      "#{_.pluralize(matchCount, 'result')} found in #{_.pluralize(pathCount, 'file')} for <span class=\"highlight-info\">#{sanitizePattern(findPattern)}</span>"
    else
      "No #{if replacedPathCount? then 'more' else ''} results found for '#{sanitizePattern(findPattern)}'"
  else
    ''

showIf = (condition) ->
  if condition
    null
  else
    {display: 'none'}

parseSearchResult = ->
  searchResult = []
  summary = document.querySelector('span.preview-count').textContent
  searchResult.push summary, ''

  orderList = document.querySelectorAll('.results-view ol.list-tree.has-collapsable-children')
  orderListArray = Array.prototype.slice.call(orderList) # only visible item shown in DOM, you cannot query all search results
  resItems = orderListArray[1].querySelectorAll('div > li') # omit first element which is dummy

  resItems.forEach (el) ->
    path = el.querySelector('div > span.path-name').textContent
    matches = el.querySelector('div > span.path-match-number').textContent
    searchResult.push "#{path} #{matches}"

    el.querySelectorAll('li.search-result').forEach (e) ->
      return if e.offsetParent is null  # skip invisible elements
      lineNumber = e.querySelector('span.line-number').textContent
      preview = e.querySelector('span.preview').textContent
      searchResult.push "\t#{lineNumber}\t#{preview}"
    searchResult.push ''
  searchResult.join('\n')

module.exports = {
  escapeHtml, escapeRegex, sanitizePattern, getReplacementResultsMessage,
  getSearchResultsMessage, showIf, parseSearchResult
}
