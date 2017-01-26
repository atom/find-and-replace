const _ = require('underscore-plus');
const FileIcons = require('../file-icons');
const MatchView = require('./match-view');
const path = require('path');
const etch = require('etch');
const $ = require('../dom-helpers');

module.exports =
class ResultView {
  constructor(params) {
    const {
      filePath, matches, isSelected, selectedMatchIndex, isExpanded,
      regex, replacePattern
    } = params;

    this.filePath = filePath
    this.matches = matches
    this.isExpanded = isExpanded;
    this.isSelected = isSelected;
    this.selectedMatchIndex = selectedMatchIndex;
    this.regex = regex;
    this.replacePattern = replacePattern;
    etch.initialize(this);
  }

  update(params) {
    const {
      filePath, matches, isSelected, selectedMatchIndex, isExpanded,
      regex, replacePattern
    } = params;

    const changed =
      matches !== this.matches ||
      isExpanded !== this.isExpanded ||
      isSelected !== this.isSelected ||
      selectedMatchIndex !== this.selectedMatchIndex ||
      regex !== this.regex ||
      replacePattern !== this.replacePattern;

    if (changed) {
      this.filePath = filePath;
      this.matches = matches;
      this.isExpanded = isExpanded;
      this.isSelected = isSelected;
      this.selectedMatchIndex = selectedMatchIndex;
      this.regex = regex;
      this.replacePattern = replacePattern;
      etch.update(this);
    }
  }

  render() {
    let iconClass = FileIcons.getService().iconClassForPath(this.filePath, "find-and-replace");
    if (!iconClass) iconClass = [];
    if (!Array.isArray(iconClass)) iconClass = iconClass.toString().split(/\s+/g);

    let relativePath = this.filePath;
    if (atom.project) {
      let rootPath;
      [rootPath, relativePath] = atom.project.relativizePath(this.filePath);
      if (rootPath && atom.project.getDirectories().length > 1) {
        relativePath = path.join(path.basename(rootPath), relativePath);
      }
    }

    return (
      $.li(
        {
          key: this.filePath,
          dataset: {path: _.escapeAttribute(this.filePath)},
          className: [
            'path',
            'list-nested-item',
            this.isSelected && this.selectedMatchIndex === -1 ? 'selected' : '',
            this.isExpanded ? '' : 'collapsed'
          ].join(' ').trim()
        },

        $.div({ref: 'pathDetails', className: 'path-details list-item'},
          $.span({className: 'disclosure-arrow'}),
          $.span({
            className: iconClass.join(' ') + ' icon',
            dataset: {name: path.basename(this.filePath)}
          }),
          $.span({className: 'path-name bright'},
            relativePath
          ),
          $.span({ref: 'description', className: 'path-match-number'},
            `(${this.matches.length} matches)`
          )
        ),

        (this.matches && this.matches.length > 0) ?
          $.ul({ref: 'matches', className: 'matches list-tree'},
            ...
            this.matches.map((match, i) =>
              $(MatchView, {
                match,
                regex: this.regex,
                replacePattern: this.replacePattern,
                isSelected: (i === this.selectedMatchIndex)
              })
            )
          ) :
          $.ul({ref: 'matches', className: 'matches list-tree'}, 'none')
      )
    );
  }
};
