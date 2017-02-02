const _ = require('underscore-plus');
const {Range, CompositeDisposable} = require('atom');
const ResultView = require('./result-view');
const etch = require('etch')
const $ = require('../dom-helpers')

const reverseDirections = {
  left: 'right',
  right: 'left',
  up: 'down',
  down: 'up'
};

module.exports =
class ResultsView {
  constructor({model}) {
    this.model = model;
    this.pixelOverdraw = 100;
    this.searchResults = [];
    this.selectedResultIndex = 0;
    this.selectedMatchIndex = -1;
    this.collapsedResultIndices = [];

    etch.initialize(this);

    this.element.addEventListener('mousedown', this.handleClick.bind(this));
    this.element.addEventListener('scroll', () => this.renderResults())
    this.element.addEventListener('resize', () => this.renderResults())

    this.subscriptions = new CompositeDisposable(
      this.model.onDidAddResult(this.addResult.bind(this)),
      this.model.onDidRemoveResult(this.removeResult.bind(this)),
      this.model.onDidClearSearchState(this.clear.bind(this)),
      this.model.getFindOptions().onDidChangeReplacePattern(() => etch.update(this)),

      atom.commands.add(this.element, {
        'core:move-up': this.moveUp.bind(this),
        'core:move-down': this.moveDown.bind(this),
        'core:move-left': this.collapseResult.bind(this),
        'core:move-right': this.expandResult.bind(this),
        'core:page-up': this.pageUp.bind(this),
        'core:page-down': this.pageDown.bind(this),
        'core:move-to-top': this.moveToTop.bind(this),
        'core:move-to-bottom': this.moveToBottom.bind(this),
        'core:confirm': this.confirmResult.bind(this),
        'core:copy': this.copyResult.bind(this),
        'find-and-replace:copy-path': this.copyPath.bind(this)
      })
    );

    this.renderResults();
  }

  update() {}

  destroy() {
    this.subscriptions.dispose();
  }

  clear() {
    this.searchResults = [];
    this.selectedResultIndex = -1;
    this.selectedMatchIndex = -1;
    etch.update(this);
  }

  render () {
    let regex = null, replacePattern = null;
    if (this.model.replacedPathCount == null) {
      regex = this.model.regex;
      replacePattern = this.model.getFindOptions().replacePattern;
    }

    return (
      $.ol(
        {
          className: 'results-view list-tree focusable-panel has-collapsable-children',
          tabIndex: -1
        },

        ...this.searchResults.map(({filePath, matches}, i) => {
          const isSelected = (i === this.selectedResultIndex);
          const isExpanded = !this.collapsedResultIndices[i];
          const selectedMatchIndex = isSelected && this.selectedMatchIndex;

          return $(ResultView, {
            filePath, matches, isSelected, isExpanded, selectedMatchIndex,
            regex, replacePattern
          });
        })
      )
    );
  }

  addResult({filePath, result, filePathInsertedIndex}) {
    result = Object.assign({filePath}, result);

    const existingIndex = this.searchResults.findIndex(existingResult =>
      existingResult.filePath === filePath
    );
    if (existingIndex !== -1) {
      this.searchResults[existingIndex] = result;
      return;
    }

    if (filePathInsertedIndex < this.searchResults.length || this.shouldRenderMoreResults()) {
      this.searchResults.splice(filePathInsertedIndex, 0, result);
    }

    if (!this.userMovedSelection || this.model.getPathCount() === 1) {
      this.selectFirstResult();
    }

    etch.update(this);
  }

  removeResult({filePath}) {
    const index = this.results.findIndex(result => result.filePath === filePath);
    if (index !== -1) {
      this.results.splice(index, 1);
      etch.update(this);
    }
  }

  renderResults(scrollTop) {
    for (const filePath of this.model.getPaths().slice(this.searchResults.length)) {
      if (!this.shouldRenderMoreResults(scrollTop)) break;
      this.searchResults.push(this.model.getResult(filePath));
    }

    return etch.update(this);
  }

  shouldRenderMoreResults(scrollTop) {
    if (scrollTop == null) scrollTop = this.element.scrollTop;
    const pathDetailsElement = this.element.querySelector('.path-details');
    const matchElement = this.element.querySelector('.path:not(.collapsed) .search-result');
    const pathDetailsHeight = pathDetailsElement ? pathDetailsElement.offsetHeight : 0;
    const matchHeight = matchElement ? matchElement.offsetHeight : 0;

    let renderedHeight = 0;
    for (let i = 0; i < this.searchResults.length; i++) {
      renderedHeight += pathDetailsHeight;
      if (!this.collapsedResultIndices[i]) {
        renderedHeight += this.searchResults[i].matches.length * matchHeight;
      }
    }

    return renderedHeight < scrollTop + this.element.offsetHeight + this.pixelOverdraw;
  }

  handleClick(event) {
    const clickedResultElement = event.target.closest('.path');
    const clickedMatchElement = event.target.closest('.search-result');
    if (event.ctrlKey || !clickedResultElement) return;

    const clickedFilePath = clickedResultElement.dataset.path;
    this.selectedResultIndex = this.searchResults.findIndex(searchResult =>
      searchResult.filePath === clickedFilePath
    );
    const clickedResult = this.searchResults[this.selectedResultIndex];

    if (clickedMatchElement) {
      const clickedRange = clickedMatchElement.dataset.range;
      this.selectedMatchIndex = clickedResult.matches.findIndex(match =>
        Range.fromObject(match.range).toString() === clickedRange
      );
      this.confirmResult({pending: event.detail === 1});
    } else {
      this.selectedMatchIndex = -1;
      this.confirmResult();
    }

    this.renderResults();
  }

  selectFirstResult() {
    this.selectedResultIndex = 0;
    if (this.collapsedResultIndices[0]) {
      this.selectedMatchIndex = -1;
    } else {
      this.selectedMatchIndex = 0;
    }
    etch.update(this);
  }

  moveToTop() {
    this.element.scrollTop = 0;
    this.selectFirstResult();
  }

  moveToBottom() {
    return this.renderResults(Infinity).then(() => {
      this.selectedResultIndex = this.searchResults.length - 1;
      if (this.collapsedResultIndices[this.selectedResultIndex]) {
        this.selectedMatchIndex = -1;
      } else {
        this.selectedMatchIndex = this.searchResults[this.selectedResultIndex].matches.length - 1;
      }
      this.element.scrollTop = this.element.scrollHeight - this.element.offsetHeight;
      etch.update(this);
    })
  }

  pageUp() {
    const pathDetailsElement = this.element.querySelector('.path-details');
    const matchElement = this.element.querySelector('.path:not(.collapsed) .search-result');
    const pathDetailsHeight = pathDetailsElement ? pathDetailsElement.offsetHeight : 0;
    const matchHeight = matchElement ? matchElement.offsetHeight : 0;

    const position = this.positionOfSelectedResult(pathDetailsHeight, matchHeight);
    this.element.scrollTop -= this.element.offsetHeight;
    this.selectResultAtPosition(
      position - this.element.offsetHeight,
      pathDetailsHeight,
      matchHeight
    );
  }

  pageDown() {
    const pathDetailsElement = this.element.querySelector('.path-details');
    const matchElement = this.element.querySelector('.path:not(.collapsed) .search-result');
    const pathDetailsHeight = pathDetailsElement ? pathDetailsElement.offsetHeight : 0;
    const matchHeight = matchElement ? matchElement.offsetHeight : 0;

    const position = this.positionOfSelectedResult(pathDetailsHeight, matchHeight);
    const newScrollTop = this.element.scrollTop + this.element.offsetHeight;
    return this.renderResults(newScrollTop).then(() => {
      this.element.scrollTop = newScrollTop;
      this.selectResultAtPosition(
        position + this.element.offsetHeight,
        pathDetailsHeight,
        matchHeight
      );
    });
  }

  positionOfSelectedResult(pathDetailsHeight, matchHeight) {
    let result = 0;
    for (let i = 0; i < this.selectedResultIndex; i++) {
      result += pathDetailsHeight;
      if (!this.collapsedResultIndices[i]) {
        result += this.searchResults[i].matches.length * matchHeight
      }
    }

    if (this.selectedMatchIndex !== -1) {
      result += pathDetailsHeight + this.selectedMatchIndex * matchHeight;
    }

    return result;
  }

  selectResultAtPosition(position, pathDetailsHeight, matchHeight) {
    this.selectedResultIndex = this.searchResults.length - 1;
    this.selectedMatchIndex = this.collapsedResultIndices[this.selectedResultIndex] ?
      -1 : this.searchResults[this.selectedResultIndex].matches.length - 1;

    let top = 0, bottom = 0;
    for (let i = 0; i < this.searchResults.length; i++) {
      bottom = top + pathDetailsHeight;
      if (bottom > position) {
        this.selectedResultIndex = i;
        this.selectedMatchIndex = -1;
        break;
      }

      top = bottom;

      if (!this.collapsedResultIndices[i]) {
        const matchesBottom = top + this.searchResults[i].matches.length * matchHeight;
        if (matchesBottom > position) {
          this.selectedResultIndex = i;
          this.selectedMatchIndex = Math.round((position - top) / matchHeight);
          top += this.selectedMatchIndex * matchHeight;
          bottom = top + matchHeight;
          break;
        }

        top = matchesBottom;
      }
    }

    if (this.element.scrollTop > top) {
      this.element.scrollTop = top;
    }

    if (this.element.scrollTop < bottom - this.element.offsetHeight) {
      this.element.scrollTop = bottom - this.element.offsetHeight;
    }

    etch.update(this);
  }

  moveDown() {
    if (this.selectedResultIndex === -1) {
      this.selectFirstResult();
      return;
    }

    this.userMovedSelection = true;
    const selectedResult = this.searchResults[this.selectedResultIndex];
    if (this.selectedMatchIndex < selectedResult.matches.length - 1 &&
        !this.collapsedResultIndices[this.selectedResultIndex]) {
      this.selectedMatchIndex++;
    } else if (this.selectedResultIndex < this.searchResults.length - 1) {
      this.selectedResultIndex++;
      this.selectedMatchIndex = -1;
    }

    etch.update(this).then(this.scrollToSelectedMatch.bind(this));
  }

  moveUp() {
    if (this.selectedResultIndex === -1) {
      this.selectFirstResult();
      return;
    }

    this.userMovedSelection = true;
    if (this.selectedMatchIndex >= 0) {
      this.selectedMatchIndex--;
    } else if (this.selectedResultIndex > 0) {
      this.selectedResultIndex--;
      const selectedResult = this.searchResults[this.selectedResultIndex];
      if (this.collapsedResultIndices[this.selectedResultIndex]) {
        this.selectedMatchIndex = -1;
      } else {
        this.selectedMatchIndex = selectedResult.matches.length - 1;
      }
    }

    etch.update(this).then(this.scrollToSelectedMatch.bind(this));
  }

  expandResult() {
    if (this.selectedResultIndex !== -1 && this.selectedMatchIndex == -1) {
      this.collapsedResultIndices[this.selectedResultIndex] = false;
      this.selectedMatchIndex = 0;
      this.renderResults();
    }
  }

  collapseResult() {
    if (this.selectedResultIndex !== -1) {
      this.collapsedResultIndices[this.selectedResultIndex] = true;
      this.selectedMatchIndex = -1;
      this.renderResults();
    }
  }

  confirmResult({pending} = {}) {
    if (this.selectedResultIndex !== -1) {
      if (this.selectedMatchIndex !== -1) {
        const result = this.searchResults[this.selectedResultIndex];
        const match = result.matches[this.selectedMatchIndex];
        atom.workspace
          .open(result.filePath, {
            pending,
            split: reverseDirections[atom.config.get('find-and-replace.projectSearchResultsPaneSplitDirection')]
          })
          .then(editor => {
            editor.setSelectedBufferRange(match.range, {autoscroll: true})
          });
      } else {
        this.collapsedResultIndices[this.selectedResultIndex] = !this.collapsedResultIndices[this.selectedResultIndex];
        this.renderResults();
      }
    }
  }

  copyResult() {
    if (this.selectedResultIndex !== -1) {
      if (this.selectedMatchIndex !== -1) {
        const result = this.searchResults[this.selectedResultIndex];
        const match = result.matches[this.selectedMatchIndex];
        atom.clipboard.write(match.lineText);
      }
    }
  }

  copyPath(event) {
    const pathElement = event.target.closest('.path');
    if (!pathElement) return;

    const filePath = event.target.dataset.path;
    let [rootPath, relativePath] = atom.project.relativizePath(filePath);
    if (rootPath && atom.project.getDirectories().length > 1) {
      relativePath = path.join(path.basename(rootPath), relativePath);
    }
    atom.clipboard.write(relativePath);
  }

  expandAllResults() {
    this.collapsedResultIndices = new Array(this.searchResults.length);
    this.collapsedResultIndices.fill(false);
    this.renderResults(Infinity);
  }

  collapseAllResults() {
    this.collapsedResultIndices = new Array(this.model.getPaths().length);
    this.collapsedResultIndices.fill(true);
    this.renderResults(Infinity);
  }

  scrollToSelectedMatch() {
    const resultElement = this.element.children[this.selectedResultIndex];

    let top = resultElement.offsetTop;
    let bottom = top + resultElement.offsetHeight;

    if (this.selectedMatchIndex !== -1) {
      const matchElement = resultElement.querySelectorAll('.search-result');
      top += matchElement.offsetTop;
      bottom = top + matchElement.offsetHeight;
    }

    if (bottom > this.element.scrollTop + this.element.scrollHeight) {
      this.element.scrollTop = bottom - this.element.scrollHeight;
    }

    if (top < this.scrollTop) {
      this.element.scrollTop = top;
    }
  }

  scrollToBottom() {
    this.renderResults(Infinity);
    this.element.scrollTop = this.element.scrollHeight;
  }

  scrollToTop() {
    this.element.scrollTop = 0;
  }

  selectedResultView() {
    const element = this.selectedElement()
    if (element) return this.resultViewsByElement.get(element)
  }
};
