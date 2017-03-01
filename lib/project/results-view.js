const {Range, CompositeDisposable, Disposable} = require('atom');
const ResultView = require('./result-view');
const ListView = require('./list-view');
const etch = require('etch');
const resizeDetector = require('element-resize-detector');

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

    this.resolveHeightInvalidationPromise = null
    this.heightInvalidationPromise = new Promise((resolve) => { this.resolveHeightInvalidationPromise = resolve })

    etch.initialize(this);

    resizeDetector({strategy: 'scroll'}).listenTo(this.element, this.invalidateItemHeights.bind(this));
    this.element.addEventListener('mousedown', this.handleClick.bind(this));

    this.subscriptions = new CompositeDisposable(
      atom.config.observe('editor.fontFamily', this.fontFamilyChanged.bind(this)),
      this.model.onDidAddResult(this.didAddResult.bind(this)),
      this.model.onDidRemoveResult(this.didRemoveResult.bind(this)),
      this.model.onDidClearSearchState(this.didClearSearchState.bind(this)),
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

  didClearSearchState() {
    this.selectedResultIndex = 0;
    this.selectedMatchIndex = 0;
    this.collapsedResultIndices.length = 0;
    etch.update(this);
  }

  render () {
    let regex = null, replacePattern = null;
    if (this.model.replacedPathCount == null) {
      regex = this.model.regex;
      replacePattern = this.model.getFindOptions().replacePattern;
    }

    return etch.dom.div(
      {className: 'results-view focusable-panel', tabIndex: '-1'},

      etch.dom.ol(
        {
          className: 'list-tree has-collapsable-children',
          style: {visibility: 'hidden', position: 'absolute', overflow: 'hidden', left: 0, top: 0, right: 0}
        },
        etch.dom(ResultView, {
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

      etch.dom(ListView, {
        ref: 'listView',
        className: 'list-tree has-collapsable-children',
        itemComponent: ResultView,
        heightForItem: this.heightForSearchResult,
        items: this.model.getPaths().map((filePath, i) => {
          const isSelected = (i === this.selectedResultIndex);
          const isExpanded = !this.collapsedResultIndices[i];
          const selectedMatchIndex = isSelected && this.selectedMatchIndex;
          return Object.assign({
            filePath,
            isSelected,
            isExpanded,
            selectedMatchIndex,
            replacePattern,
            previewStyle: this.previewStyle,
            pathDetailsHeight: this.pathDetailsHeight,
            matchHeight: this.matchHeight
          }, this.model.results[filePath]);
        }),
      })
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
      etch.update(this).then(() => { this.resolveHeightInvalidationPromise() });
    }
  }

  didAddResult() {
    etch.update(this);
  }

  didRemoveResult() {
    etch.update(this);
  }

  handleClick(event) {
    const clickedResultElement = event.target.closest('.path');
    const clickedMatchElement = event.target.closest('.search-result');
    if (event.ctrlKey || !clickedResultElement) return;

    const clickedFilePath = clickedResultElement.dataset.path;
    this.selectedResultIndex = this.model.getPaths().indexOf(clickedFilePath);
    const clickedResult = this.model.getResult(clickedFilePath);
    if (!clickedResult) return;

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
    event.preventDefault();

    etch.update(this);
  }

  selectFirstResult() {
    this.selectedResultIndex = 0;
    if (this.collapsedResultIndices[0]) {
      this.selectedMatchIndex = -1;
    } else {
      this.selectedMatchIndex = 0;
    }

    this.scrollToSelectedMatch();
    return etch.update(this);
  }

  moveToTop() {
    this.selectFirstResult();
    this.setScrollTop(0);
  }

  moveToBottom() {
    this.selectedResultIndex = this.model.getPathCount() - 1;
    if (this.collapsedResultIndices[this.selectedResultIndex]) {
      this.selectedMatchIndex = -1;
    } else {
      this.selectedMatchIndex = this.model.getResultAt(this.selectedResultIndex).matches.length - 1;
    }

    this.scrollToSelectedMatch();
    return etch.update(this);
  }

  pageUp() {
    if (this.refs.listView) {
      const {clientHeight} = this.refs.listView.element;
      const position = this.positionOfSelectedResult(this.pathDetailsHeight, this.matchHeight);
      this.setScrollTop(this.getScrollTop() - clientHeight);
      this.selectResultAtPosition(
        position - clientHeight,
        this.pathDetailsHeight,
        this.matchHeight
      );
    }
  }

  pageDown() {
    if (this.refs.listView) {
      const {clientHeight} = this.refs.listView.element;
      const position = this.positionOfSelectedResult(this.pathDetailsHeight, this.matchHeight);
      this.setScrollTop(this.getScrollTop() + clientHeight);
      this.selectResultAtPosition(
        position + clientHeight,
        this.pathDetailsHeight,
        this.matchHeight
      );
    }
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
    if (this.refs.listView) {
      const {clientHeight} = this.refs.listView.element;
      this.selectedResultIndex = this.model.getPathCount() - 1;
      this.selectedMatchIndex = this.collapsedResultIndices[this.selectedResultIndex] ?
        -1 : this.model.getResultAt(this.selectedResultIndex).matches.length - 1;

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
          const result = this.model.getResultAt(i);
          const matchesBottom = top + result.matches.length * matchHeight;
          if (matchesBottom > position) {
            this.selectedResultIndex = i;
            this.selectedMatchIndex = Math.round((position - top) / matchHeight);
            if (this.selectedMatchIndex >= result.matches.length) {
              this.selectedMatchIndex--
            }
            top += this.selectedMatchIndex * matchHeight;
            bottom = top + matchHeight;
            break;
          }

          top = matchesBottom;
        }
      }

      if (this.getScrollTop() < bottom - clientHeight) {
        this.setScrollTop(bottom - clientHeight);
      }

      if (this.getScrollTop() > top) {
        this.setScrollTop(top);
      }

      etch.update(this);
    }
  }

  moveDown() {
    if (this.selectedResultIndex === -1) {
      this.selectFirstResult();
      return;
    }

    const selectedResult = this.model.getResultAt(this.selectedResultIndex);
    if (this.selectedMatchIndex < selectedResult.matches.length - 1 &&
        !this.collapsedResultIndices[this.selectedResultIndex]) {
      this.selectedMatchIndex++;
    } else if (this.selectedResultIndex < this.model.getPathCount() - 1) {
      this.selectedResultIndex++;
      this.selectedMatchIndex = -1;
    }

    this.scrollToSelectedMatch();
    return etch.update(this);
  }

  moveUp() {
    if (this.selectedResultIndex === -1) {
      this.selectFirstResult();
      return;
    }

    if (this.collapsedResultIndices[this.selectedResultIndex]) {
      this.selectedMatchIndex = -1;
    }

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

    this.scrollToSelectedMatch();
    etch.update(this);
  }

  expandResult() {
    if (this.selectedResultIndex !== -1) {
      this.collapsedResultIndices[this.selectedResultIndex] = false;
      if (this.selectedMatchIndex === -1) this.selectedMatchIndex = 0;
      etch.update(this);
    }
  }

  collapseResult() {
    if (this.selectedResultIndex !== -1) {
      this.collapsedResultIndices[this.selectedResultIndex] = true;
      etch.update(this);
    }
  }

  confirmResult({pending} = {}) {
    if (this.selectedResultIndex !== -1) {
      if (this.selectedMatchIndex !== -1) {
        const result = this.model.getResultAt(this.selectedResultIndex);
        if (result) {
          const match = result.matches[this.selectedMatchIndex];
          atom.workspace
            .open(result.filePath, {
              pending,
              split: reverseDirections[atom.config.get('find-and-replace.projectSearchResultsPaneSplitDirection')]
            })
            .then(editor => {
              editor.setSelectedBufferRange(match.range, {autoscroll: true})
            });
        }
      } else {
        this.collapsedResultIndices[this.selectedResultIndex] = !this.collapsedResultIndices[this.selectedResultIndex];
      }
    }
  }

  copyResult() {
    if (this.selectedResultIndex !== -1) {
      if (this.selectedMatchIndex !== -1) {
        const result = this.model.getResultAt(this.selectedResultIndex);
        if (result) {
          const match = result.matches[this.selectedMatchIndex];
          atom.clipboard.write(match.lineText);
        }
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
    this.setScrollTop(0);
    etch.update(this);
  }

  collapseAllResults() {
    this.collapsedResultIndices = new Array(this.model.getPaths().length);
    this.collapsedResultIndices.fill(true);
    this.setScrollTop(0);
    etch.update(this);
  }

  scrollToSelectedMatch() {
    if (this.refs.listView) {
      const top = this.positionOfSelectedResult(this.pathDetailsHeight, this.matchHeight);
      const bottom = top + this.matchHeight;

      if (bottom > this.getScrollTop() + this.refs.listView.element.clientHeight) {
        this.setScrollTop(bottom - this.refs.listView.element.clientHeight);
      } else if (top < this.getScrollTop()) {
        this.setScrollTop(top);
      }
    }
  }

  scrollToBottom() {
    this.setScrollTop(this.getScrollHeight());
  }

  scrollToTop() {
    this.setScrollTop(0);
  }

  setScrollTop (scrollTop) {
    if (this.refs.listView) {
      this.refs.listView.element.scrollTop = scrollTop;
      this.refs.listView.element.dispatchEvent(new UIEvent('scroll'))
    }
  }

  getScrollTop () {
    return this.refs.listView ? this.refs.listView.element.scrollTop : 0;
  }

  getScrollHeight () {
    return this.refs.listView ? this.refs.listView.element.scrollHeight : 0;
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
