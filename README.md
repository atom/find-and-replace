# Find and Replace package
[![macOS Build Status](https://travis-ci.org/atom/find-and-replace.svg?branch=master)](https://travis-ci.org/atom/find-and-replace) [![Windows Build Status](https://ci.appveyor.com/api/projects/status/6w4baiiq5mw4nxky/branch/master?svg=true)](https://ci.appveyor.com/project/Atom/find-and-replace/branch/master) [![Dependency Status](https://david-dm.org/atom/find-and-replace.svg)](https://david-dm.org/atom/find-and-replace)

Find and replace in the current buffer or across the entire project in Atom.

## Find in buffer

Using the shortcut <kbd>cmd-f</kbd> (macOS) or <kbd>ctrl-f</kbd> (Windows and Linux).
![screen shot 2013-11-26 at 12 25 22 pm](https://f.cloud.github.com/assets/69169/1625938/a859fa70-56d9-11e3-8b2a-ac37c5033159.png)

## Find in project

Using the shortcut <kbd>cmd-shift-f</kbd> (macOS) or <kbd>ctrl-shift-f</kbd> (Windows and Linux).
![screen shot 2013-11-26 at 12 26 02 pm](https://f.cloud.github.com/assets/69169/1625945/b216d7b8-56d9-11e3-8b14-6afc33467be9.png)

## Commands and Keybindings
|Command|Description|Keybinding (Linux)|Keybinding (macOS)|Keybinding (Windows)|
|-------|-----------|------------------|-----------------|--------------------|
|`project-find:show`|Show the project find and replace dialog|<kbd>ctrl-shift-f</kbd>|<kbd>cmd-shift-f</kbd>|<kbd>ctrl-shift-f</kbd>|
|`project-find:confirm`|Find the next occurence of the phrase||<kbd>cmd-enter</kbd>|<kbd>ctrl-enter</kbd>|
|`project-find:toggle-regex-option`|Toggle the "regex" option||<kbd>cmd-alt-/</kbd>|<kbd>ctrl-alt-/</kbd>|
|`project-find:toggle-case-option`|Toggle the "match case" option||<kbd>cmd-alt-c</kbd>|<kbd>ctrl-alt-c</kbd>|
|`project-find:toggle-whole-word-option`|Toggle the "whold word" option||<kbd>cmd-alt-w</kbd>|<kbd>ctrl-alt-w</kbd>|
|`project-find:replace-all`|Replace all occurences of the phrase|<kbd>ctrl-enter</kbd>|<kbd>cmd-enter</kbd>|<kbd>ctrl-enter</kbd>|
|`find-and-replace:show`|Show the buffer find and replace dialog|<kbd>ctrl-f</kbd>|<kbd>cmd-f</kbd>|<kbd>ctrl-f</kbd>|
|`find-and-replace:show-replace`|Toggle the buffer find and replace dialog and focuses the replace text box|<kbd>ctrl-alt-f</kbd>|<kbd>cmd-alt-f</kbd>|<kbd>ctrl-alt-f</kbd>|
|`find-and-replace:confirm`|Find the next occurence of the phrase||<kbd>cmd-enter</kbd>|<kbd>ctrl-enter</kbd>|
|`find-and-replace:toggle-regex-option`|Toggle the "regex" option||<kbd>cmd-alt-/</kbd>|<kbd>ctrl-alt-/</kbd>|
|`find-and-replace:toggle-case-option`|Toggle the "match case" option||<kbd>cmd-alt-c</kbd>|<kbd>ctrl-alt-c</kbd>|
|`find-and-replace:toggle-selection-option`|Toggle the "obly in selection" option||<kbd>cmd-alt-s</kbd>|<kbd>ctrl-alt-s</kbd>|
|`find-and-replace:toggle-whole-word-option`|Toggle the "whold word" option||<kbd>cmd-alt-w</kbd>|<kbd>ctrl-alt-s</kbd>|
|`find-and-replace:find-all`|Find all occurences of the pharase|<kbd>ctrl-enter</kbd>|<kbd>cmd-enter</kbd>|<kbd>ctrl-enter</kbd>|
|`find-and-replace:find-next`|Find the next occurence of the phrase|<kbd>f3</kbd>|<kbd>cmd-g</kbd>|<kbd>f3</kbd>|
|`find-and-replace:find-previous`|Find the previous occurence of the phrase|<kbd>shift-f3</kbd>|<kbd>cmd-shift-g</kbd>|<kbd>shift-f3</kbd>|
|`find-and-replace:find-next-selected`|Find the next occurence of the phrase selected|<kbd>ctrl-f3</kbd>|<kbd>cmd-f3</kbd>|<kbd>ctrl-f3</kbd>|
|`find-and-replace:find-previous-selected`|Find the previous occurence of the phrase selected|<kbd>ctrl-shift-f3</kbd>|<kbd>cmd-shift-f3</kbd>|<kbd>ctrl-shift-f3</kbd>|
|`find-and-replace:select-all`|Select all occurences of the phrase|<kbd>alt-f3</kbd>|<kbd>cmd-ctrl-g</kbd>|<kbd>alt-f3</kbd>|
|`find-and-replace:select-next`|Select the next occurence of the phrase|<kbd>ctrl-d</kbd>|<kbd>cmd-d</kbd>|<kbd>ctrl-d</kbd>|
|`find-and-replace:select-undo`|Undo the last selection|<kbd>ctrl-u</kbd>|<kbd>cmd-u</kbd>|<kbd>ctrl-u</kbd>|
|`find-and-replace:select-skip`|Skip the current selection|<kbd>ctrl-k ctrl-d</kbd>|<kbd>cmd-k cmd-u</kbd>|<kbd>ctrl-k ctrl-u</kbd>|
|`find-and-replace:focus-next`|Focus the next text box in the find and replace dialog|<kbd>tab</kbd>|<kbd>tab</kbd>|<kbd>tab</kbd>|
|`find-and-replace:focus-previous`|Focus the previous text box in the find and replace dialog|<kbd>shift-tab</kbd>|<kbd>shift-tab</kbd>|<kbd>shift-tab</kbd>|
|`find-and-replace:replace-all`|Replace all occurences of the phrase|<kbd>ctrl-enter</kbd>|<kbd>cmd-enter</kbd>|<kbd>ctrl-enter</kbd>|

## Provided Service

If you need access the marker layer containing result markers for a given editor, use the `find-and-replace@0.0.1` service. The service exposes one method, `resultsMarkerLayerForTextEditor`, which takes a `TextEditor` and returns a `TextEditorMarkerLayer` that you can interact with. Keep in mind that any work you do in synchronous event handlers on this layer will impact the performance of find and replace.
