SearchModel = require './search-model'
SearchInBufferView = require './search-in-buffer-view'

module.exports =
  activate: -> 
    new SearchInBufferView new SearchModel '',
      regex: false
      caseSensitive: false
      inWord: false
      inSelection: false
