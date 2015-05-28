module.exports =
class DefaultSearchDirectoryProvider
  # Public: Determines whether this provider supports search for a `Directory`.
  #
  # * `directory` {Directory} whose search needs might be supported by this provider.
  #
  # Returns a `boolean` indicating whether this provider can search this `Directory`.
  canSearchDirectory: (directory) -> true

  # Public: Performs a text search for files in the specified `Directory`, subject to the
  # specified parameters.
  #
  # Results are streamed back to the caller via `recordSearchResult()` and `recordSearchError()`.
  #
  # * `directory` {Directory} that has been accepted by this provider's `canSearchDirectory()`
  # predicate.
  # * `regex` {RegExp} to search with. (Note this reflects the "Use Regex" and "Match Case" options
  # exposed via the ProjectFindView UI.)
  # * `recordNumPathsSearched` {Function} callback that should be invoked periodically with the number of
  # paths searched.
  # * `recordSearchResult` {Function} Should be called with each matching search result.
  #   * `searchResult` {Object} with the following keys:
  #     * `filePath` {String} absolute path to the matching file.
  #     * `matches` {Array} with object elements with the following keys:
  #       * `lineText` {String} The full text of the matching line (without a line terminator character).
  #       * `lineTextOffset` {Number} (This always seems to be 0?)
  #       * `matchText` {String} The text that matched the `regex` used for the search.
  #       * `range` {Range} Identifies the matching region in the file. (Likely as an array of numeric arrays.)
  # * `recordSearchError` {Function}
  # * `options` {Object} with the following properties:
  #   * `includePatterns` An {Array} of glob patterns (as strings) to search within. Note that this
  #   array may be empty, indicating that all files should be searched.
  #
  #   Each item in the array is a file/directory pattern, e.g., `src` to search in the "src"
  #   directory or `*.js` to search all JavaScript files. In practice, this often comes from the
  #   comma-delimited list of patterns in the bottom text input of the ProjectFindView dialog.
  #
  # Returns a `Promise` that includes a `cancel()` method. If invoked before the `Proimse` is
  # determined, it will reject the `Promise`.
  search: (directory, regex, recordNumPathsSearched, recordSearchResult, recordSearchError, options) ->
    scanOptions =
      paths: options.includePatterns
      onPathsSearched: recordNumPathsSearched
      rootDirectories: [directory]
    # Note that atom.workspace.scan takes care of searching open buffers that may have local
    # modifications.
    atom.workspace.scan regex, scanOptions, (result, error) ->
      if result
        recordSearchResult(result)
      else
        recordSearchError(error)
