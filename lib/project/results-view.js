const {Range, CompositeDisposable, Disposable} = require('atom');
const ResultView = require('./result-view');
const ListView = require('./list-view');
const etch = require('etch');
const $ = require('../dom-helpers');
const resizeDetector = require('element-resize-detector')({strategy: 'scroll'});

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
    this.selectedResultIndex = 0;
    this.selectedMatchIndex = -1;
    this.collapsedResultIndices = [];
    this.heightForSearchResult = this.heightForSearchResult.bind(this);

    etch.initialize(this);

    resizeDetector.listenTo(this.element, this.invalidateItemHeights.bind(this));
    this.element.addEventListener('mousedown', this.handleClick.bind(this));

    this.subscriptions = new CompositeDisposable(
      atom.config.observe('editor.fontFamily', this.fontFamilyChanged.bind(this)),
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
  }

  update() {}

  destroy() {
    this.subscriptions.dispose();
  }

  clear() {
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

    return $.div(
      {className: 'results-view'},

      $.ol(
        {
          className: 'list-tree',
          style: {visibility: 'hidden', position: 'absolute'}
        },
        $(ResultView, {
          ref: 'dummyResultView',
          top: 0,
          bottom: Infinity,
          item: {
            filePath: 'fake-file-path',
            matches: [{
              range: [[0, 1], [0, 2]],
              lineTextOffset: 1,
              lineText: 'fake-line-text',
              matchText: 'fake-match-text',
              isSelected: false,
            }],
            matchHeight: 1,
            pathDetailsHeight: 1,
            isSelected: false,
            isExpanded: true,
            previewStyle: this.previewStyle
          }
        })
      ),

      this.pathDetailsHeight != null ?
        $(ListView, {
          className: 'list-tree',
          itemComponent: ResultView,
          heightForItem: this.heightForSearchResult,
          items: this.model.getPaths().map((filePath, i) => {
            const isSelected = (i === this.selectedResultIndex);
            const isExpanded = !this.collapsedResultIndices[i];
            const selectedMatchIndex = isSelected && this.selectedMatchIndex;
            return Object.assign({
              isSelected,
              isExpanded,
              selectedMatchIndex,
              previewStyle: this.previewStyle,
              pathDetailsHeight: this.pathDetailsHeight,
              matchHeight: this.matchHeight
            }, this.model.results[filePath]);
          }),
        }) :
        $.div()
    );
  }

  heightForSearchResult(searchResult, i) {
    if (this.collapsedResultIndices[i]) {
      return this.pathDetailsHeight;
    } else {
      return this.pathDetailsHeight + searchResult.matches.length * this.matchHeight;
    }
  }

  invalidateItemHeights() {
    const pathDetailsHeight = this.refs.dummyResultView.refs.pathDetails.offsetHeight;
    const matchHeight = this.refs.dummyResultView.element.getElementsByClassName('search-result')[0].offsetHeight;
    if (pathDetailsHeight !== this.pathDetailsHeight || matchHeight !== this.matchHeight) {
      this.pathDetailsHeight = pathDetailsHeight;
      this.matchHeight = matchHeight;
      etch.update(this);
    }
  }

  addResult() {
    etch.update(this);
  }

  removeResult({filePath}) {
    etch.update(this);
  }

  handleClick(event) {
    const clickedResultElement = event.target.closest('.path');
    const clickedMatchElement = event.target.closest('.search-result');
    if (event.ctrlKey || !clickedResultElement) return;

    const clickedFilePath = clickedResultElement.dataset.path;
    this.selectedResultIndex = this.model.getPaths().indexOf(clickedFilePath);
    const clickedResult = this.model.getResult(clickedFilePath)

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

    etch.update(this);
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
    this.selectedResultIndex = this.model.getPathCount() - 1;
    if (this.collapsedResultIndices[this.selectedResultIndex]) {
      this.selectedMatchIndex = -1;
    } else {
      this.selectedMatchIndex = this.model.getResultAt(this.selectedResultIndex).matches.length - 1;
    }
    this.element.scrollTop = this.element.scrollHeight - this.element.offsetHeight;
    etch.update(this);
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
    this.element.scrollTop = newScrollTop;
    this.selectResultAtPosition(
      position + this.element.offsetHeight,
      pathDetailsHeight,
      matchHeight
    );
  }

  positionOfSelectedResult(pathDetailsHeight, matchHeight) {
    let result = 0;
    for (let i = 0; i < this.selectedResultIndex; i++) {
      result += pathDetailsHeight;
      if (!this.collapsedResultIndices[i]) {
        result += this.model.getResultAt(i).matches.length * matchHeight
      }
    }

    if (this.selectedMatchIndex !== -1) {
      result += pathDetailsHeight + this.selectedMatchIndex * matchHeight;
    }

    return result;
  }

  selectResultAtPosition(position, pathDetailsHeight, matchHeight) {
    this.selectedResultIndex = this.model.getPathCount() - 1;
    this.selectedMatchIndex = this.collapsedResultIndices[this.selectedResultIndex] ?
      -1 : this.getResultAt(this.selectedResultIndex).matches.length - 1;

    let top = 0, bottom = 0;
    for (let i = 0; i < this.model.getPathCount(); i++) {
      bottom = top + pathDetailsHeight;
      if (bottom > position) {
        this.selectedResultIndex = i;
        this.selectedMatchIndex = -1;
        break;
      }

      top = bottom;

      if (!this.collapsedResultIndices[i]) {
        const matchesBottom = top + this.model.getResultAt(i).matches.length * matchHeight;
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
    const selectedResult = this.model.getResultAt(this.selectedResultIndex);
    if (this.selectedMatchIndex < selectedResult.matches.length - 1 &&
        !this.collapsedResultIndices[this.selectedResultIndex]) {
      this.selectedMatchIndex++;
    } else if (this.selectedResultIndex < this.model.getPathCount() - 1) {
      this.selectedResultIndex++;
      this.selectedMatchIndex = -1;
    }

    this.scrollToSelectedMatch();
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
      const selectedResult = this.model.getResultAt(this.selectedResultIndex);
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
    }
  }

  collapseResult() {
    if (this.selectedResultIndex !== -1) {
      this.collapsedResultIndices[this.selectedResultIndex] = true;
      this.selectedMatchIndex = -1;
    }
  }

  confirmResult({pending} = {}) {
    if (this.selectedResultIndex !== -1) {
      if (this.selectedMatchIndex !== -1) {
        const result = this.model.getResultAt(this.selectedResultIndex);
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
      }
    }
  }

  copyResult() {
    if (this.selectedResultIndex !== -1) {
      if (this.selectedMatchIndex !== -1) {
        const result = this.model.getResultAt(this.selectedResultIndex);
        const match = result.matches[this.selectedMatchIndex];
        atom.clipboard.write(match.lineText);
      }
    }
  }

  copyPath() {
    const {filePath} = this.model.getResultAt(this.selectedResultIndex);
    let [rootPath, relativePath] = atom.project.relativizePath(filePath);
    if (rootPath && atom.project.getDirectories().length > 1) {
      relativePath = path.join(path.basename(rootPath), relativePath);
    }
    atom.clipboard.write(relativePath);
  }

  expandAllResults() {
    this.collapsedResultIndices = new Array(this.model.getPathCount());
    this.collapsedResultIndices.fill(false);
    this.element.scrollTop = 0
    etch.update(this)
  }

  collapseAllResults() {
    this.collapsedResultIndices = new Array(this.model.getPaths().length);
    this.collapsedResultIndices.fill(true);
    this.element.scrollTop = 0
    etch.update(this)
  }

  scrollToSelectedMatch() {
    const resultElement = this.element.children[this.selectedResultIndex];
    if (!resultElement) return;

    let element;
    if (this.selectedMatchIndex === -1) {
      element = resultElement.querySelector('.path-details');
    } else {
      element = resultElement.querySelectorAll('.search-result')[this.selectedMatchIndex];
    }

    const top = element.offsetTop;
    const bottom = top + element.offsetHeight;

    if (bottom > this.element.scrollTop + this.element.offsetHeight) {
      this.element.scrollTop = bottom - this.element.offsetHeight;
    }

    if (top < this.element.scrollTop) {
      this.element.scrollTop = top;
    }
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight;
  }

  scrollToTop() {
    this.element.scrollTop = 0;
  }

  selectedResultView() {
    const element = this.selectedElement()
    if (element) return this.resultViewsByElement.get(element)
  }

  fontFamilyChanged(fontFamily) {
    this.previewStyle = {fontFamily};
    etch.update(this);
  }
};
