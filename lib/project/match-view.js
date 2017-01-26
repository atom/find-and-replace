const { Range, CompositeDisposable } = require('atom');
const etch = require('etch')
const {showIf} = require('./util')
const $ = require('../dom-helpers')

module.exports =
class MatchView {
  constructor({match, regex, replacePattern, isSelected, previewStyle}) {
    this.match = match;
    this.regex = regex;
    this.replacePattern = replacePattern;
    this.previewStyle = previewStyle;
    this.isSelected = isSelected;
    etch.initialize(this);
  }

  update({match, regex, replacePattern, previewStyle, isSelected}) {
    const changed =
      match !== this.match ||
      regex !== this.regex ||
      replacePattern !== this.replacePattern ||
      previewStyle !== this.previewStyle ||
      isSelected !== this.isSelected;

    if (changed) {
      this.match = match;
      this.regex = regex;
      this.replacePattern = replacePattern;
      this.previewStyle = previewStyle;
      this.isSelected = isSelected;
      etch.update(this);
    }
  }

  render() {
    const range = Range.fromObject(this.match.range);
    const matchStart = range.start.column - this.match.lineTextOffset;
    const matchEnd = range.end.column - this.match.lineTextOffset;
    const prefix = this.match.lineText.slice(0, matchStart).trimLeft();
    const suffix = this.match.lineText.slice(matchEnd);

    let replacementText = ''
    if (this.replacePattern && this.regex) {
      replacementText = this.match.matchText.replace(this.regex, this.replacePattern);
    } else if (this.replacePattern) {
      replacementText = this.replacePattern;
    }

    return (
      $.li(
        {
          key: range.toString(),
          dataset: {range: range.toString()},
          className: `search-result list-item ${this.isSelected ? 'selected' : ''}`
        },

        $.span({className: 'line-number text-subtle'},
          range.start.row + 1
        ),

        $.span({className: 'preview', style: this.previewStyle},
          $.span({}, prefix),
          $.span({className: `match ${replacementText ? 'highlight-error' : 'highlight-info'}`},
            this.match.matchText
          ),
          $.span({className: 'replacement highlight-success', style: showIf(replacementText)},
            replacementText
          ),
          $.span({}, suffix)
        )
      )
    );
  }
};
