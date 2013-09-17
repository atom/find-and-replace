module.exports =
class SearchResult
  constructor: ({@path, @bufferRange, @matchText, @lineText}) ->

  getPath: ->
    project.relativize(@path)

  getBufferRange: ->
    @bufferRange

  preview: ->
    range = @getBufferRange()
    prefix = @lineText[0...range.start.column]
    match = @lineText[range.start.column...range.end.column]
    suffix = @lineText[range.end.column..]

    {prefix, suffix, match, range}
