const FileIcons = require('../file-icons');
const MatchView = require('./match-view');
const path = require('path');
const etch = require('etch');
const $ = require('../dom-helpers');

module.exports =
class ResultView {
  constructor({item, top, bottom} = {}) {
    const {
      filePath, matches, isSelected, selectedMatchIndex, isExpanded,
      regex, replacePattern, previewStyle, pathDetailsHeight, matchHeight
    } = item;

    this.top = top;
    this.bottom = bottom;
    this.pathDetailsHeight = pathDetailsHeight;
    this.matchHeight = matchHeight;

    this.filePath = filePath
    this.matches = matches
    this.isExpanded = isExpanded;
    this.isSelected = isSelected;
    this.selectedMatchIndex = selectedMatchIndex;
    this.regex = regex;
    this.replacePattern = replacePattern;
    this.previewStyle = previewStyle;
    etch.initialize(this);
  }

  update({item, top, bottom} = {}) {
    const {
      filePath, matches, isSelected, selectedMatchIndex, isExpanded,
      regex, replacePattern, previewStyle, pathDetailsHeight, matchHeight
    } = item;

    const changed =
      matches !== this.matches ||
      isExpanded !== this.isExpanded ||
      isSelected !== this.isSelected ||
      selectedMatchIndex !== this.selectedMatchIndex ||
      regex !== this.regex ||
      replacePattern !== this.replacePattern ||
      previewStyle !== this.previewStyle ||
      top !== this.top ||
      bottom !== this.bottom ||
      pathDetailsHeight !== this.pathDetailsHeight ||
      matchHeight !== this.matchHeight;

    if (changed) {
      this.filePath = filePath;
      this.matches = matches;
      this.isExpanded = isExpanded;
      this.isSelected = isSelected;
      this.selectedMatchIndex = selectedMatchIndex;
      this.regex = regex;
      this.replacePattern = replacePattern;
      this.previewStyle = previewStyle;
      this.top = top;
      this.bottom = bottom;
      this.pathDetailsHeight = pathDetailsHeight;
      this.matchHeight = matchHeight;
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
          dataset: {path: this.filePath},
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

        this.renderList()
      )
    );
  }

  renderList() {
    const children = [];
    let itemTopPosition = this.pathDetailsHeight;
    let i = 0;

    for (; i < this.matches.length; i++) {
      let itemBottomPosition = itemTopPosition + this.matchHeight;
      if (itemBottomPosition > this.top) break;
      itemTopPosition = itemBottomPosition;
    }

    for (; i < this.matches.length; i++) {
      const match = this.matches[i];
      children.push(
        $.div(
          {
            style: {
              position: 'absolute',
              height: this.matchHeight + 'px',
              minWidth: '100%',
              top: itemTopPosition - this.pathDetailsHeight + 'px'
            },
            key: i
          },
          $(MatchView, {
            match,
            regex: this.regex,
            replacePattern: this.replacePattern,
            isSelected: (i === this.selectedMatchIndex),
            previewStyle: this.previewStyle
          })
        )
      );

      itemTopPosition += this.matchHeight;
      if (itemTopPosition >= this.bottom) break;
    }

    return $.ol(
      {
        ref: 'list',
        className: 'matches list-tree',
        style: {height: itemTopPosition + 'px', position: 'relative'}
      },
      ...children
    )
  }
};
