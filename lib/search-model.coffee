{EventEmitter} = require 'events'
_ = require 'underscore'

module.exports =
class SearchModel extends EventEmitter
  # options - 
  #   regex: false
  #   caseSensitive: false
  #   inWord: false
  #   inSelection: false
  constructor: (pattern, options) ->
    @setup(pattern, options)

  setup: (pattern, options={}) ->
    return unless pattern
    return if @pattern == pattern and _.isEqual(@options, options)

    [@pattern, @options] = [pattern, options]

    @regex = @buildRegex(@pattern, @options)
    @emit 'change', this, regex: @regex

  setOptions: (options) ->
    @setup(@pattern, options)

  setPattern: (pattern) ->
    @setup(pattern, @options)

  ### Internal ###

  buildRegex: (pattern, options={}) ->
    flags = 'g'
    flags += 'i' unless options.caseSensitive
    new RegExp(pattern, flags)
