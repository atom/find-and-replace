SearchModel = require './search-model'
BufferFindAndReplaceView = require './buffer-find-and-replace-view'

module.exports =
  activate: -> 
    new BufferFindAndReplaceView new SearchModel '',
      regex: false
      caseSensitive: false
      inWord: false
      inSelection: false
