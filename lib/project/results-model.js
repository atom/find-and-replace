const _ = require('underscore-plus')
const {Emitter, TextEditor} = require('atom')
const escapeHelper = require('../escape-helper')

class Result {
  static create (result) {
    if (result && result.matches && result.matches.length) {
      const matches = result.matches.map(m =>
        ({
          matchText: m.matchText,
          lineText: m.lineText,
          lineTextOffset: m.lineTextOffset,
          range: m.range,
          leadingContextLines: m.leadingContextLines,
          trailingContextLines: m.trailingContextLines
        })
      )
      return new Result({filePath: result.filePath, matches})
    } else {
      return null
    }
  }

  constructor (result) {
    _.extend(this, result)
  }
}

module.exports = class ResultsModel {
  constructor (findOptions) {
    this.onContentsModified = this.onContentsModified.bind(this)
    this.findOptions = findOptions
    this.emitter = new Emitter()

    atom.workspace.getCenter().observeActivePaneItem(item => {
      if (item instanceof TextEditor) {
        return item.onDidStopChanging(() => this.onContentsModified(item))
      }
    })

    this.clear()
  }

  onDidClear (callback) {
    return this.emitter.on('did-clear', callback)
  }

  onDidClearSearchState (callback) {
    return this.emitter.on('did-clear-search-state', callback)
  }

  onDidClearReplacementState (callback) {
    return this.emitter.on('did-clear-replacement-state', callback)
  }

  onDidSearchPaths (callback) {
    return this.emitter.on('did-search-paths', callback)
  }

  onDidErrorForPath (callback) {
    return this.emitter.on('did-error-for-path', callback)
  }

  onDidNoopSearch (callback) {
    return this.emitter.on('did-noop-search', callback)
  }

  onDidStartSearching (callback) {
    return this.emitter.on('did-start-searching', callback)
  }

  onDidCancelSearching (callback) {
    return this.emitter.on('did-cancel-searching', callback)
  }

  onDidFinishSearching (callback) {
    return this.emitter.on('did-finish-searching', callback)
  }

  onDidStartReplacing (callback) {
    return this.emitter.on('did-start-replacing', callback)
  }

  onDidFinishReplacing (callback) {
    return this.emitter.on('did-finish-replacing', callback)
  }

  onDidSearchPath (callback) {
    return this.emitter.on('did-search-path', callback)
  }

  onDidReplacePath (callback) {
    return this.emitter.on('did-replace-path', callback)
  }

  onDidAddResult (callback) {
    return this.emitter.on('did-add-result', callback)
  }

  onDidRemoveResult (callback) {
    return this.emitter.on('did-remove-result', callback)
  }

  clear () {
    this.clearSearchState()
    this.clearReplacementState()
    return this.emitter.emit('did-clear', this.getResultsSummary())
  }

  clearSearchState () {
    this.pathCount = 0
    this.matchCount = 0
    this.regex = null
    this.results = {}
    this.paths = []
    this.active = false
    this.searchErrors = null

    if (this.inProgressSearchPromise != null) {
      this.inProgressSearchPromise.cancel()
      this.inProgressSearchPromise = null
    }

    return this.emitter.emit('did-clear-search-state', this.getResultsSummary())
  }

  clearReplacementState () {
    this.replacePattern = null
    this.replacedPathCount = null
    this.replacementCount = null
    this.replacementErrors = null
    return this.emitter.emit('did-clear-replacement-state', this.getResultsSummary())
  }

  shouldRerunSearch (findPattern, pathsPattern, replacePattern, options) {
    if (options == null) { options = {} }
    const {onlyRunIfChanged} = options
    return !(onlyRunIfChanged && (findPattern != null) && (pathsPattern != null) &&
      (findPattern === this.lastFindPattern) && (pathsPattern === this.lastPathsPattern))
  }

  search (findPattern, pathsPattern, replacePattern, options) {
    if (options == null) { options = {} }
    if (!this.shouldRerunSearch(findPattern, pathsPattern, replacePattern, options)) {
      this.emitter.emit('did-noop-search')
      return Promise.resolve()
    }

    const {keepReplacementState} = options
    if (keepReplacementState) {
      this.clearSearchState()
    } else {
      this.clear()
    }

    this.lastFindPattern = findPattern
    this.lastPathsPattern = pathsPattern
    this.findOptions.set(_.extend({findPattern, replacePattern, pathsPattern}, options))
    this.regex = this.findOptions.getFindPatternRegex()

    this.active = true
    const searchPaths = this.pathsArrayFromPathsPattern(pathsPattern)

    const onPathsSearched = numberOfPathsSearched => {
      return this.emitter.emit('did-search-paths', numberOfPathsSearched)
    }

    const leadingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountBefore')
    const trailingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountAfter')
    this.inProgressSearchPromise = atom.workspace.scan(this.regex, {paths: searchPaths,
      onPathsSearched,
      leadingContextLineCount,
      trailingContextLineCount}, (result, error) => {
        if (result) {
          return this.setResult(result.filePath, Result.create(result))
        } else {
          if (this.searchErrors == null) { this.searchErrors = [] }
          this.searchErrors.push(error)
          return this.emitter.emit('did-error-for-path', error)
        }
      })

    this.emitter.emit('did-start-searching', this.inProgressSearchPromise)
    return this.inProgressSearchPromise.then(message => {
      if (message === 'cancelled') {
        return this.emitter.emit('did-cancel-searching')
      } else {
        this.inProgressSearchPromise = null
        return this.emitter.emit('did-finish-searching', this.getResultsSummary())
      }
    })
  }

  replace (pathsPattern, replacePattern, replacementPaths) {
    if (!this.findOptions.findPattern || (this.regex == null)) { return }

    this.findOptions.set({replacePattern, pathsPattern})

    if (this.findOptions.useRegex) { replacePattern = escapeHelper.unescapeEscapeSequence(replacePattern) }

    this.active = false // not active until the search is finished
    this.replacedPathCount = 0
    this.replacementCount = 0

    const promise = atom.workspace.replace(this.regex, replacePattern, replacementPaths, (result, error) => {
      if (result) {
        if (result.replacements) {
          this.replacedPathCount++
          this.replacementCount += result.replacements
        }
        return this.emitter.emit('did-replace-path', result)
      } else {
        if (this.replacementErrors == null) { this.replacementErrors = [] }
        this.replacementErrors.push(error)
        return this.emitter.emit('did-error-for-path', error)
      }
    })

    this.emitter.emit('did-start-replacing', promise)
    return promise.then(() => {
      this.emitter.emit('did-finish-replacing', this.getResultsSummary())
      return this.search(this.findOptions.findPattern, this.findOptions.pathsPattern,
        this.findOptions.replacePattern, {keepReplacementState: true})
    }).catch(e => console.error(e.stack))
  }

  setActive (isActive) {
    if ((isActive && this.findOptions.findPattern) || !isActive) {
      this.active = isActive
      return isActive
    }
  }

  getActive () { return this.active }

  getFindOptions () { return this.findOptions }

  getLastFindPattern () { return this.lastFindPattern }

  getResultsSummary () {
    const findPattern = this.lastFindPattern != null ? this.lastFindPattern : this.findOptions.findPattern
    const { replacePattern } = this.findOptions
    return {
      findPattern,
      replacePattern,
      pathCount: this.pathCount,
      matchCount: this.matchCount,
      searchErrors: this.searchErrors,
      replacedPathCount: this.replacedPathCount,
      replacementCount: this.replacementCount,
      replacementErrors: this.replacementErrors
    }
  }

  getPathCount () {
    return this.pathCount
  }

  getMatchCount () {
    return this.matchCount
  }

  getPaths () {
    return this.paths
  }

  getResult (filePath) {
    return this.results[filePath]
  }

  getResultAt (index) {
    return this.results[this.paths[index]]
  }

  setResult (filePath, result) {
    if (result) {
      return this.addResult(filePath, result)
    } else {
      return this.removeResult(filePath)
    }
  }

  addResult (filePath, result) {
    let filePathInsertedIndex = null
    let filePathUpdatedIndex = null
    if (this.results[filePath]) {
      this.matchCount -= this.results[filePath].matches.length
      filePathUpdatedIndex = this.paths.indexOf(filePath)
    } else {
      this.pathCount++
      filePathInsertedIndex = binaryIndex(this.paths, filePath, stringCompare)
      this.paths.splice(filePathInsertedIndex, 0, filePath)
    }

    this.matchCount += result.matches.length

    this.results[filePath] = result
    return this.emitter.emit('did-add-result', {filePath, result, filePathInsertedIndex, filePathUpdatedIndex})
  }

  removeResult (filePath) {
    if (this.results[filePath]) {
      this.pathCount--
      this.matchCount -= this.results[filePath].matches.length

      const filePathRemovedIndex = this.paths.indexOf(filePath)
      this.paths = _.without(this.paths, filePath)
      delete this.results[filePath]
      return this.emitter.emit('did-remove-result', {filePath, filePathRemovedIndex})
    }
  }

  onContentsModified (editor) {
    if (!this.active || !this.regex || !editor.getPath()) { return }

    const matches = []
    const leadingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountBefore')
    const trailingContextLineCount = atom.config.get('find-and-replace.searchContextLineCountAfter')
    editor.scan(this.regex, {leadingContextLineCount, trailingContextLineCount}, match => matches.push(match))

    const result = Result.create({filePath: editor.getPath(), matches})
    this.setResult(editor.getPath(), result)
    return this.emitter.emit('did-finish-searching', this.getResultsSummary())
  }

  pathsArrayFromPathsPattern (pathsPattern) {
    return pathsPattern.trim().split(',').map((inputPath) => inputPath.trim())
  }
}

var stringCompare = (a, b) => a.localeCompare(b)

var binaryIndex = function (array, value, comparator) {
  // Lifted from underscore's _.sortedIndex ; adds a flexible comparator
  let low = 0
  let high = array.length
  while (low < high) {
    const mid = Math.floor((low + high) / 2)
    if (comparator(array[mid], value) < 0) {
      low = mid + 1
    } else {
      high = mid
    }
  }
  return low
}
