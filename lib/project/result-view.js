const FileIcons = require('../file-icons');
const MatchView = require('./match-view');
const path = require('path');
const etch = require('etch');
const $ = etch.dom;

module.exports =
class ResultView {
  constructor({item, top, bottom} = {}) {
    const {
      filePath, matches, isSelected, selectedMatchIndex, isExpanded, regex,
      replacePattern, previewStyle, pathDetailsHeight, matchHeight, contextLineHeight
    } = item;

    this.top = top;
    this.bottom = bottom;
    this.pathDetailsHeight = pathDetailsHeight;
    this.matchHeight = matchHeight;
    this.contextLineHeight = contextLineHeight;

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
      filePath, matches, isSelected, selectedMatchIndex, isExpanded, regex,
      replacePattern, previewStyle, pathDetailsHeight, matchHeight, contextLineHeight
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
      contextLineHeight !== this.contextLineHeight ||
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
      this.contextLineHeight = contextLineHeight;
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

    const isPathSelected = this.isSelected && (
      !this.isExpanded ||
      this.selectedMatchIndex === -1
    );

    return (
      $.li(
        {
          key: this.filePath,
          dataset: {path: this.filePath},
          className: [
            'path',
            'list-nested-item',
            isPathSelected ? 'selected' : '',
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
            `(${this.matches.length} match${this.matches.length === 1 ? '' : 'es'})`
          )
        ),

        this.renderList()
      )
    );
  }

  renderList() {
    const children = [];
    const top = Math.max(0, this.top - this.pathDetailsHeight);
    const bottom = this.bottom - this.pathDetailsHeight;

    let i = 0;
    let itemTopPosition = 0;

    for (; i < this.matches.length; i++) {
      const match = this.matches[i];
      let itemBottomPosition = itemTopPosition + this.matchHeight;
      if (match.leadingContextLines) itemBottomPosition += match.leadingContextLines.length * this.contextLineHeight;
      if (match.trailingContextLines) itemBottomPosition += match.trailingContextLines.length * this.contextLineHeight;

      if (itemBottomPosition > top) break;
      itemTopPosition = itemBottomPosition;
    }

    for (; i < this.matches.length; i++) {
      const match = this.matches[i];
      let itemBottomPosition = itemTopPosition + this.matchHeight;
      if (match.leadingContextLines) itemBottomPosition += match.leadingContextLines.length * this.contextLineHeight;
      if (match.trailingContextLines) itemBottomPosition += match.trailingContextLines.length * this.contextLineHeight;

      children.push(
        etch.dom(MatchView, {
          match,
          key: i,
          regex: this.regex,
          replacePattern: this.replacePattern,
          isSelected: (i === this.selectedMatchIndex),
          previewStyle: this.previewStyle,
          top: itemTopPosition
        })
      );

      if (itemBottomPosition >= bottom) break;
      itemTopPosition = itemBottomPosition;
    }

    return $.ol(
      {
        ref: 'list',
        className: 'matches list-tree',
        style: {height: `${itemTopPosition}px`, position: 'relative'}
      },
      ...children
    )
  }
};
