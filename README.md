# Find and Replace package [![Build Status](https://travis-ci.org/atom/find-and-replace.svg?branch=master)](https://travis-ci.org/atom/find-and-replace)

Find and replace in the current buffer or across the entire project in Atom.

## Find in buffer (cmd-f)

![screen shot 2013-11-26 at 12 25 22 pm](https://f.cloud.github.com/assets/69169/1625938/a859fa70-56d9-11e3-8b2a-ac37c5033159.png)

## Find in project (cmd-shift-f)

![screen shot 2013-11-26 at 12 26 02 pm](https://f.cloud.github.com/assets/69169/1625945/b216d7b8-56d9-11e3-8b14-6afc33467be9.png)

## Provided Service

If you need access the marker layer containing result markers for a given editor, use the `find-and-replace@0.0.1` service. The service exposes one method, `resultsMarkerLayerForTextEditor`, which takes a `TextEditor` and returns a `TextEditorMarkerLayer` that you can interact with. Keep in mind that any work you do in synchronous event handlers on this layer will impact the performance of find and replace.
