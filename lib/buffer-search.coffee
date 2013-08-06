{EventEmitter} = require 'events'
_ = require 'underscore'

module.exports =
class BufferSearch extends EventEmitter
  # options - 
  #   regex: false
  #   caseSensitive: false
  #   inWord: false
  #   inSelection: false
  constructor: (buffer, pattern, options) ->
    @ranges = []
    @search(buffer, pattern, options)

  search: (buffer, pattern, options={}) ->
    return unless buffer and pattern
    return if @buffer == buffer and @pattern == pattern and _.isEqual(@options, options)

    [@buffer, @pattern, @options] = [buffer, pattern, options]

    @regex = @buildRegex(@pattern, @options)
    @ranges = @findRanges(@buffer, @regex, @options)

    @emit 'search', ranges: @ranges

  setBuffer: (buffer) ->
    @search(buffer, @pattern, @options)

  setPattern: (pattern) ->
    @search(@buffer, pattern, @options)

  setOptions: (options) ->
    @search(@buffer, @pattern, options)

  findNext: (range) ->
    return null unless @ranges and @ranges.length

    for foundRange in @ranges
      return foundRange if foundRange.compare(range) > 0

    @ranges[0]

  findPrevious: (range) ->

  ### Internal ###

  buildRegex: (pattern, options={}) ->
    flags = 'g'
    flags += 'i' unless options.caseSensitive
    new RegExp(pattern, flags)

  findRanges: (buffer, regex, {inSelection}={}) -> 
    ranges = []
    buffer.scanInRange regex, buffer.getRange(), ({range}) ->
      ranges.push(range)

    console.log 'found', ranges

    ranges
