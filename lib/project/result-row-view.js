const getIconServices = require('../get-icon-services');
const { Range } = require('atom');
const {
  LeadingContextRow,
  TrailingContextRow,
  ResultPathRow,
  MatchRow,
  ResultRowGroup
} = require('./result-row');
const {showIf} = require('./util');

const _ = require('underscore-plus');
const path = require('path');
const assert = require('assert');
const etch = require('etch');
const $ = etch.dom;

class ResultPathRowView {
  constructor({groupData, isSelected}) {
    const props = {groupData, isSelected};
    this.props = Object.assign({}, props);
    this.filePath = groupData.filePath;

    etch.initialize(this);
    getIconServices().updateIcon(this);
  }

  destroy() {
    return etch.destroy(this)
  }

  update({groupData, isSelected}) {
    const props = {groupData, isSelected};

    if (!_.isEqual(props, this.props)) {
      this.props = Object.assign({}, props);
      this.filePath = groupData.filePath;
      etch.update(this);
    }
  }

  writeAfterUpdate() {
    getIconServices().updateIcon(this);
  }

  render() {
    let relativePath = this.props.groupData.filePath;
    if (atom.project) {
      let rootPath;
      [rootPath, relativePath] = atom.project.relativizePath(this.props.groupData.filePath);
      if (rootPath && atom.project.getDirectories().length > 1) {
        relativePath = path.join(path.basename(rootPath), relativePath);
      }
    }
    const groupData = this.props.groupData;
    return (
      $.li(
        {
          dataset: { filePath: groupData.filePath },
          key: groupData.filePath,
          className: 'list-item',
        },
        $.div(
          {
            className: [
              'path-row',
              this.props.isSelected ? 'selected' : '',
              groupData.isCollapsed ? 'collapsed' : ''
            ].join(' ').trim()
          },
          $.span({className: 'disclosure-arrow'}),
          $.span({
            dataset: {name: path.basename(groupData.filePath)},
            ref: 'icon',
            className: 'icon'
          }),
          $.span({className: 'path-name bright'}, relativePath),
          $.span(
            {ref: 'description', className: 'path-match-number'},
            `(${groupData.matchCount} match${groupData.matchCount === 1 ? '' : 'es'})`
          )
        )
      )
    )
  }
};

class MatchRowView {
  constructor({rowData, groupData, isSelected, replacePattern, regex}) {
    const props = {rowData, groupData, isSelected, replacePattern, regex};
    const previewData = {match: rowData.match, replacePattern, regex};

    this.props = Object.assign({}, props);
    this.previewData = previewData;
    this.previewNode = this.generatePreviewNode(previewData);

    etch.initialize(this);
  }

  update({rowData, groupData, isSelected, replacePattern, regex}) {
    const props = {rowData, groupData, isSelected, replacePattern, regex};
    const previewData = {match: rowData.match, replacePattern, regex};

    if (!_.isEqual(props, this.props)) {
      if (!_.isEqual(previewData, this.previewData)) {
        this.previewData = previewData;
        this.previewNode = this.generatePreviewNode(previewData);
      }
      this.props = Object.assign({}, props);
      etch.update(this);
    }
  }

  generatePreviewNode({match, replacePattern, regex}) {
    const range = Range.fromObject(match.range);
    const matchStart = range.start.column - match.lineTextOffset;
    const matchEnd = range.end.column - match.lineTextOffset;

    const prefix = match.lineText.slice(0, matchStart);
    const suffix = match.lineText.slice(matchEnd);

    let replacementText = ''
    if (replacePattern && regex) {
      replacementText = match.matchText.replace(regex, replacePattern);
    } else if (replacePattern) {
      replacementText = replacePattern;
    }

    return $.span(
      {className: 'preview'},
      $.span({}, prefix),
      $.span(
        {className: `match ${replacementText ? 'highlight-error' : 'highlight-info'}`},
        match.matchText
      ),
      $.span(
        {className: 'replacement highlight-success', style: showIf(replacementText)},
        replacementText
      ),
      $.span({}, suffix)
    );
  }

  render() {
    return (
      $.li(
        {
          dataset: {
            filePath: this.props.groupData.filePath,
            matchLineNumber: this.props.rowData.lineNumber,
          },
          className: 'list-item',
        },
        $.div(
          {
            className: [
              'match-row',
              this.props.isSelected ? 'selected' : '',
              this.props.rowData.separator ? 'separator' : ''
            ].join(' ').trim()
          },
          $.span(
            {className: 'line-number text-subtle'},
            this.props.rowData.lineNumber + 1
          ),
          this.previewNode
        )
      )
    );
  }
};

class ContextRowView {
  constructor({rowData, groupData, isSelected}) {
    const props = {rowData, groupData, isSelected};
    this.props = Object.assign({}, props);

    etch.initialize(this);
  }

  destroy() {
    return etch.destroy(this)
  }

  update({rowData, groupData, isSelected}) {
    const props = {rowData, groupData, isSelected};

    if (!_.isEqual(props, this.props)) {
      this.props = Object.assign({}, props);
      etch.update(this);
    }
  }

  render() {
    return (
      $.li(
        {
          dataset: {
            filePath: this.props.groupData.filePath,
            matchLineNumber: this.props.rowData.matchLineNumber
          },
          className: 'list-item',
        },
        $.div(
          {className: `context-row ${this.props.rowData.separator ? 'separator' : ''}`},
          $.span({className: 'line-number text-subtle'}, this.props.rowData.lineNumber + 1),
          $.span({className: 'preview'}, $.span({}, this.props.rowData.line))
        )
      )
    )
  }
}

function getRowViewType(row) {
  if (row instanceof ResultPathRow) {
    return ResultPathRowView;
  }
  if (row instanceof MatchRow) {
    return MatchRowView;
  }
  if (row instanceof LeadingContextRow) {
    return ContextRowView;
  }
  if (row instanceof TrailingContextRow) {
    return ContextRowView;
  }
  assert(false);
}

module.exports =
class ResultRowView {
  constructor({item}) {
    const props = {
      rowData: Object.assign({}, item.row.data),
      groupData: Object.assign({}, item.row.group.data),
      isSelected: item.isSelected,
      replacePattern: item.replacePattern,
      regex: item.regex
    };
    this.props = props;
    this.rowViewType = getRowViewType(item.row);

    etch.initialize(this);
  }

  destroy() {
    return etch.destroy(this);
  }

  update({item}) {
    const props = {
      rowData: Object.assign({}, item.row.data),
      groupData: Object.assign({}, item.row.group.data),
      isSelected: item.isSelected,
      replacePattern: item.replacePattern,
      regex: item.regex
    }
    this.props = props;
    this.rowViewType = getRowViewType(item.row);
    etch.update(this);
  }

  render() {
    return $(this.rowViewType, this.props);
  }
};
