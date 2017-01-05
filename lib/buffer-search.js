const _ = require('underscore-plus');
const { Point, Range, Emitter, CompositeDisposable, TextBuffer } = require('atom');
const FindOptions = require('./find-options');
const escapeHelper = require('./escape-helper');

const ResultsMarkerLayersByEditor = new WeakMap;

module.exports =
class BufferSearch {
  constructor(findOptions) {
    this.findOptions = findOptions;
    this.emitter = new Emitter;
    this.subscriptions = null;
    this.markers = [];
    this.editor = null;

    this.findOptions.onDidChange(changedParams => {
      if (changedParams && (
        changedParams.findPattern != null ||
        changedParams.useRegex != null ||
        changedParams.wholeWord != null ||
        changedParams.caseSensitive != null ||
        changedParams.inCurrentSelection != null)) {
        this.recreateMarkers();
      }
    });
  }

  onDidUpdate(callback) {
    return this.emitter.on('did-update', callback);
  }

  onDidError(callback) {
    return this.emitter.on('did-error', callback);
  }

  onDidChangeCurrentResult(callback) {
    return this.emitter.on('did-change-current-result', callback);
  }

  setEditor(editor) {
    this.editor = editor;
    if (this.subscriptions) this.subscriptions.dispose();
    if (this.editor) {
      this.subscriptions = new CompositeDisposable;
      this.subscriptions.add(this.editor.buffer.onDidStopChanging(this.bufferStoppedChanging.bind(this)));
      this.subscriptions.add(this.editor.onDidAddSelection(this.setCurrentMarkerFromSelection.bind(this)));
      this.subscriptions.add(this.editor.onDidChangeSelectionRange(this.setCurrentMarkerFromSelection.bind(this)));
      this.resultsMarkerLayer = this.resultsMarkerLayerForTextEditor(this.editor);
      if (this.resultsLayerDecoration) this.resultsLayerDecoration.destroy();
      this.resultsLayerDecoration = this.editor.decorateMarkerLayer(this.resultsMarkerLayer, {type: 'highlight', class: 'find-result'});
    }
    this.recreateMarkers();
  }

  getEditor() { return this.editor; }

  setFindOptions(newParams) { return this.findOptions.set(newParams); }

  getFindOptions() { return this.findOptions; }

  resultsMarkerLayerForTextEditor(editor) {
    let layer = ResultsMarkerLayersByEditor.get(editor)
    if (!layer) {
      layer = editor.addMarkerLayer({maintainHistory: false});
      ResultsMarkerLayersByEditor.set(editor, layer);
    }
    return layer;
  }

  patternMatchesEmptyString(findPattern) {
    const findOptions = new FindOptions(this.findOptions.serialize());
    findOptions.set({findPattern});
    try {
      return findOptions.getFindPatternRegex().test('');
    } catch (e) {
      this.emitter.emit('did-error', e);
      return false;
    }
  }

  search(findPattern, otherOptions) {
    let options = {findPattern};
    if (otherOptions != null) {
      for (let key in otherOptions) {
        options[key] = otherOptions[key];
      }
    }
    this.findOptions.set(options);
  }

  replace(markers, replacePattern) {
    if (!markers || markers.length === 0) return;

    this.findOptions.set({replacePattern});

    this.editor.transact(() => {
      let findRegex = null

      if (this.findOptions.useRegex) {
        findRegex = this.getFindPatternRegex();
        replacePattern = escapeHelper.unescapeEscapeSequence(replacePattern);
      }

      for (let i = 0, n = markers.length; i < n; i++) {
        const marker = markers[i]
        const bufferRange = marker.getBufferRange();
        const replacementText = findRegex ?
          this.editor.getTextInBufferRange(bufferRange).replace(findRegex, replacePattern) :
          replacePattern;
        this.editor.setTextInBufferRange(bufferRange, replacementText);

        marker.destroy();
        this.markers.splice(this.markers.indexOf(marker), 1);
      }
    });

    return this.emitter.emit('did-update', this.markers.slice());
  }

  destroy() {
    return this.subscriptions.dispose();
  }

  /*
  Section: Private
  */

  recreateMarkers() {
    if (this.resultsMarkerLayer) {
      // TODO: Remove this conditional once Atom 1.14 is released.
      if (this.resultsMarkerLayer.clear) {
        this.resultsMarkerLayer.clear()
      } else {
        this.markers.forEach(marker => marker.destroy())
      }
    }

    this.markers.length = 0;
    const markers = this.createMarkers(Point.ZERO, Point.INFINITY);
    if (markers) {
      this.markers = markers;
      return this.emitter.emit("did-update", this.markers.slice());
    }
  }

  createMarkers(start, end) {
    let newMarkers = [];
    if (this.findOptions.findPattern && this.editor) {
      const selectedRange = this.editor.getSelectedBufferRange()
      if (this.findOptions.inCurrentSelection && !selectedRange.isEmpty()) {
        start = Point.max(start, selectedRange.start);
        end = Point.min(end, selectedRange.end);
      }

      const regex = this.getFindPatternRegex()
      if (regex) {
        try {
          this.editor.scanInBufferRange(regex, Range(start, end), ({range}) => {
            newMarkers.push(this.createMarker(range));
          });
        } catch (error) {
          if (/RegExp too big$/.test(error.message)) {
            error.message = "Search string is too large";
          }
          this.emitter.emit('did-error', error);
          return false;
        }
      } else {
        return false;
      }
    }
    return newMarkers;
  }

  bufferStoppedChanging({changes}) {
    let marker;
    let scanEnd = Point.ZERO;
    let markerIndex = 0;

    for (let change of changes) {
      const changeStart = change.start;
      const changeEnd = change.start.traverse(change.newExtent);
      if (changeEnd.isLessThan(scanEnd)) continue;

      let precedingMarkerIndex = -1;
      while (marker = this.markers[markerIndex]) {
        if (marker.isValid()) {
          if (marker.getBufferRange().end.isGreaterThan(changeStart)) { break; }
          precedingMarkerIndex = markerIndex;
        } else {
          this.markers[markerIndex] = this.recreateMarker(marker);
        }
        markerIndex++;
      }

      let followingMarkerIndex = -1;
      while (marker = this.markers[markerIndex]) {
        if (marker.isValid()) {
          followingMarkerIndex = markerIndex;
          if (marker.getBufferRange().start.isGreaterThanOrEqual(changeEnd)) { break; }
        } else {
          this.markers[markerIndex] = this.recreateMarker(marker);
        }
        markerIndex++;
      }

      let spliceStart, scanStart
      if (precedingMarkerIndex >= 0) {
        spliceStart = precedingMarkerIndex;
        scanStart = this.markers[precedingMarkerIndex].getBufferRange().start;
      } else {
        spliceStart = 0;
        scanStart = Point.ZERO;
      }

      let spliceEnd
      if (followingMarkerIndex >= 0) {
        spliceEnd = followingMarkerIndex;
        scanEnd = this.markers[followingMarkerIndex].getBufferRange().end;
      } else {
        spliceEnd = Infinity;
        scanEnd = Point.INFINITY;
      }

      const newMarkers = this.createMarkers(scanStart, scanEnd);
      const oldMarkers = this.markers.splice(spliceStart, (spliceEnd - spliceStart) + 1, ...newMarkers);
      for (let oldMarker of oldMarkers) {
        oldMarker.destroy();
      }
      markerIndex += newMarkers.length - oldMarkers.length;
    }

    while (marker = this.markers[++markerIndex]) {
      if (!marker.isValid()) {
        this.markers[markerIndex] = this.recreateMarker(marker);
      }
    }

    this.emitter.emit('did-update', this.markers.slice());
    this.currentResultMarker = null;
    this.setCurrentMarkerFromSelection();
  }

  setCurrentMarkerFromSelection() {
    const marker = this.findMarker(this.editor.getSelectedBufferRange());

    if (marker === this.currentResultMarker) return;

    if (this.currentResultMarker) {
      this.resultsLayerDecoration.setPropertiesForMarker(this.currentResultMarker, null);
      this.currentResultMarker = null;
    }

    if (marker && !marker.isDestroyed()) {
      this.resultsLayerDecoration.setPropertiesForMarker(marker, {type: 'highlight', class: 'current-result'});
      this.currentResultMarker = marker;
    }

    this.emitter.emit('did-change-current-result', this.currentResultMarker);
  }

  findMarker(range) {
    if (this.resultsMarkerLayer) {
      return this.resultsMarkerLayer.findMarkers({
        startPosition: range.start,
        endPosition: range.end
      })[0];
    }
  }

  recreateMarker(marker) {
    const range = marker.getBufferRange()
    marker.destroy();
    return this.createMarker(range);
  }

  createMarker(range) {
    return this.resultsMarkerLayer.markBufferRange(range, {invalidate: 'inside'});
  }

  getFindPatternRegex() {
    try {
      return this.findOptions.getFindPatternRegex();
    } catch (e) {
      this.emitter.emit('did-error', e);
      return null;
    }
  }
};
