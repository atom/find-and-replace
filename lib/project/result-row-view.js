const getIconServices = require('../get-icon-services');
const { Point, Range } = require('atom');
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

    etch.initialize(this);
    getIconServices().updateIcon(this, groupData.filePath);
  }

  destroy() {
    return etch.destroy(this)
  }

  update({groupData, isSelected}) {
    const props = {groupData, isSelected};

    if (!_.isEqual(props, this.props)) {
      this.props = Object.assign({}, props);
      etch.update(this);
    }
  }

  writeAfterUpdate() {
    getIconServices().updateIcon(this, this.props.groupData.filePath);
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
          className: [
            // This triggers the CSS displaying the "expand / collapse" arrows
            // See `styles/lists.less` in the atom-ui repository for details
            'list-nested-item',
            groupData.isCollapsed ? 'collapsed' : '',
            this.props.isSelected ? 'selected' : ''
          ].join(' ').trim(),
          key: groupData.filePath
        },
        $.div(
          {
            className: 'list-item path-row',
            dataset: { filePath: groupData.filePath }
          },
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
    const previewData = {matches: rowData.matches, replacePattern, regex};

    this.props = Object.assign({}, props);
    this.previewData = previewData;
    this.previewNode = this.generatePreviewNode(previewData);

    etch.initialize(this);
  }

  update({rowData, groupData, isSelected, replacePattern, regex}) {
    const props = {rowData, groupData, isSelected, replacePattern, regex};
    const previewData = {matches: rowData.matches, replacePattern, regex};

    if (!_.isEqual(props, this.props)) {
      if (!_.isEqual(previewData, this.previewData)) {
        this.previewData = previewData;
        this.previewNode = this.generatePreviewNode(previewData);
      }
      this.props = Object.assign({}, props);
      etch.update(this);
    }
  }

  generatePreviewNode({matches, replacePattern, regex}) {
    const TYPE = {
      MATCH: 1,
      TEXT: 2,
      ELLIPSIS: 3
    };

    const segments = [];

    for (const match of matches) {
      if (segments.length) {
        const previousRange = segments[segments.length - 1].range;
        const currentRange = new Range(
          new Point(0, match.lineTextOffset),
          new Point(0, match.lineTextOffset + match.lineText.length)
        );

        if (previousRange.intersectsWith(currentRange)) {
          const segment = segments.pop();
          // current range starts before previous range, therefore it should contain everything from previous range
          if (previousRange.start.isGreaterThanOrEqual(currentRange.start)) {
            // Delete everything up to previous match from the beginning of current range
            match.lineText = match.lineText.substring(previousRange.start.column - currentRange.start.column);
            match.lineTextOffset = previousRange.start.column;
          } else { // current range starts midway through previous range
            // Prepend non-overlapping part of previous range to current range
            const preprefix = segment.content.substring(0, currentRange.start.column - previousRange.start.column);
            match.lineText = preprefix + match.lineText;
            match.lineTextOffset -= preprefix.length;
          }
        } else { // current range does not intersect and comes after previous range
          segments.push({ type: TYPE.ELLIPSIS, range: new Range(previousRange.end, currentRange.start) });
        }
      }

      const prefix = match.lineText.substring(0, match.range.start.column - match.lineTextOffset);
      const suffix = match.lineText.substring(match.range.end.column - match.lineTextOffset);

      if (prefix) {
        segments.push({
          type: TYPE.TEXT,
          content: prefix,
          range: new Range(
            new Point(0, match.lineTextOffset),
            new Point(0, match.range.start.column)
          )
        });
      }

      let replacementText
      if (replacePattern) {
        replacementText = regex ? match.matchText.replace(regex, replacePattern) : replacePattern;
      }

      segments.push({
        type: TYPE.MATCH,
        content: match.matchText,
        range: new Range(
          new Point(0, match.range.start.column),
          new Point(0, match.range.end.column)
        ),
        replacement: replacementText
      });

      if (suffix) {
        segments.push({
          type: TYPE.TEXT,
          content: suffix,
          range: new Range(
            new Point(0, match.range.end.column),
            new Point(0, match.lineTextOffset + match.lineText.length)
          )
        });
      }
    }

    const subnodes = [];

    for (const segment of segments) {
      if (segment.type === TYPE.TEXT) {
        subnodes.push($.span({}, segment.content));
      }

      if (segment.type === TYPE.MATCH) {
        subnodes.push(
          $.span({ className: `match ${segment.replacement ? 'highlight-error' : 'highlight-info'}` }, segment.content)
        );

        if (segment.replacement) {
          subnodes.push($.span({ className: 'replacement highlight-success' }, segment.replacement));
        }
      }

      if (segment.type === TYPE.ELLIPSIS) {
        subnodes.push($.span({}, '…'));
      }
    }

    return $.span({ className: 'preview' }, ...subnodes);
  }

  render() {
    return (
      $.li(
        {
          className: [
            'list-item',
            'match-row',
            this.props.isSelected ? 'selected' : '',
            this.props.rowData.separator ? 'separator' : ''
          ].join(' ').trim(),
          dataset: {
            filePath: this.props.groupData.filePath,
            matchLineNumber: this.props.rowData.lineNumber,
          }
        },
        $.span(
          {className: 'line-number text-subtle'},
          this.props.rowData.lineNumber + 1
        ),
        this.previewNode
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
          className: [
            'list-item',
            'context-row',
            this.props.rowData.separator ? 'separator' : ''
          ].join(' ').trim(),
          dataset: {
            filePath: this.props.groupData.filePath,
            matchLineNumber: this.props.rowData.matchLineNumber
          },
        },
        $.span({className: 'line-number text-subtle'}, this.props.rowData.lineNumber + 1),
        $.span({className: 'preview'}, $.span({}, this.props.rowData.line))
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
