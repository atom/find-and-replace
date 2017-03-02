const _ = require('underscore-plus');
const {CompositeDisposable} = require('atom');
const ResultsView = require('./results-view');
const {showIf, getSearchResultsMessage, escapeHtml} = require('./util');
const etch = require('etch');
const $ = etch.dom;

module.exports =
class ResultsPaneView {
  constructor() {
    this.model = this.constructor.model;
    this.model.setActive(true);
    this.isLoading = false;
    this.searchErrors = [];
    this.searchResults = null;
    this.searchingIsSlow = false;
    this.numberOfPathsSearched = 0;

    etch.initialize(this);

    this.onFinishedSearching(this.model.getResultsSummary());
    this.element.addEventListener('focus', this.focused.bind(this));
    this.element.addEventListener('click', event => {
      switch (event.target) {
        case this.refs.collapseAll:
          this.collapseAllResults();
          break;
        case this.refs.expandAll:
          this.expandAllResults();
          break;
      }
    })

    this.subscriptions = new CompositeDisposable(
      this.model.onDidStartSearching(this.onSearch.bind(this)),
      this.model.onDidFinishSearching(this.onFinishedSearching.bind(this)),
      this.model.onDidClear(this.onCleared.bind(this)),
      this.model.onDidClearReplacementState(this.onReplacementStateCleared.bind(this)),
      this.model.onDidSearchPaths(this.onPathsSearched.bind(this)),
      this.model.onDidErrorForPath(error => this.appendError(error.message))
    );
  }

  update() {}

  destroy() {
    this.model.setActive(false);
    this.subscriptions.dispose();
  }

  render() {
    const matchCount = this.searchResults && this.searchResults.matchCount;

    return (
      $.div(
        {
          tabIndex: -1,
          className: `preview-pane pane-item ${matchCount === 0 ? 'no-results' : ''}`,
        },

        $.div({className: 'preview-header'},
          $.span({
            ref: 'previewCount',
            className: 'preview-count inline-block',
            innerHTML: this.isLoading
              ? 'Searching...'
              : (getSearchResultsMessage(this.searchResults) || 'Project search results')
          }),

          $.div(
            {
              ref: 'previewControls',
              className: 'preview-controls',
              style: {visibility: matchCount > 0 ? 'visible' : 'hidden'}
            },

            $.div({className: 'btn-group'},
              $.button({ref: 'collapseAll', className: 'btn'}, 'Collapse All'),
              $.button({ref: 'expandAll', className: 'btn'}, 'Expand All')
            )
          ),

          $.div({className: 'inline-block', style: showIf(this.isLoading)},
            $.div({className: 'loading loading-spinner-tiny inline-block'}),

            $.div(
              {
                className: 'inline-block',
                style: showIf(this.isLoading && this.searchingIsSlow)
              },

              $.span({ref: 'searchedCount', className: 'searched-count'},
                this.numberOfPathsSearched.toString()
              ),
              $.span({}, ' paths searched')
            )
          )
        ),

        $.ul(
          {
            ref: 'errorList',
            className: 'error-list list-group padded',
            style: showIf(this.searchErrors.length > 0)
          },

          ...this.searchErrors.map(message =>
            $.li({className: 'text-error'}, escapeHtml(message))
          )
        ),

        etch.dom(ResultsView, {ref: 'resultsView', model: this.model}),

        $.ul(
          {
            className: 'centered background-message no-results-overlay',
            style: showIf(matchCount === 0)
          },
          $.li({}, 'No Results')
        )
      )
    );
  }

  copy() {
    return new ResultsPaneView();
  }

  getTitle() {
    return 'Project Find Results';
  }

  getIconName() {
    return 'search';
  }

  getURI() {
    return this.constructor.URI;
  }

  focused() {
    this.refs.resultsView.element.focus();
  }

  appendError(message) {
    this.searchErrors.push(message)
    etch.update(this);
  }

  onSearch(searchPromise) {
    this.isLoading = true;
    this.searchingIsSlow = false;
    this.numberOfPathsSearched = 0;

    setTimeout(() => {
      this.searchingIsSlow = true;
      etch.update(this);
    }, 500);

    etch.update(this);

    let stopLoading = () => {
      this.isLoading = false;
      etch.update(this);
    };
    return searchPromise.then(stopLoading, stopLoading);
  }

  onPathsSearched(numberOfPathsSearched) {
    this.numberOfPathsSearched = numberOfPathsSearched;
    etch.update(this);
  }

  onFinishedSearching(results) {
    this.searchResults = results;
    if (results.searchErrors || results.replacementErrors) {
      this.searchErrors =
        _.pluck(results.replacementErrors, 'message')
        .concat(_.pluck(results.searchErrors, 'message'));
    } else {
      this.searchErrors = [];
    }
    etch.update(this);
  }

  onReplacementStateCleared(results) {
    this.searchResults = results;
    this.searchErrors = [];
    etch.update(this);
  }

  onCleared() {
    this.isLoading = false;
    this.searchErrors = [];
    this.searchResults = {};
    this.searchingIsSlow = false;
    this.numberOfPathsSearched = 0;
    etch.update(this);
  }

  collapseAllResults() {
    this.refs.resultsView.collapseAllResults();
    this.refs.resultsView.element.focus();
  }

  expandAllResults() {
    this.refs.resultsView.expandAllResults();
    this.refs.resultsView.element.focus();
  }
}

module.exports.URI = "atom://find-and-replace/project-results";
