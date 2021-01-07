# Find and Replace package
[![macOS Build Status](https://travis-ci.org/atom/find-and-replace.svg?branch=master)](https://travis-ci.org/atom/find-and-replace)
[![Windows Build Status](https://ci.appveyor.com/api/projects/status/6w4baiiq5mw4nxky/branch/master?svg=true)](https://ci.appveyor.com/project/Atom/find-and-replace/branch/master)
[![Dependency Status](https://david-dm.org/atom/find-and-replace.svg)](https://david-dm.org/atom/find-and-replace)

Find and replace in the current buffer or across the entire project in Atom.

![Find in buffer](https://f.cloud.github.com/assets/69169/1625938/a859fa70-56d9-11e3-8b2a-ac37c5033159.png)

![Find in project](https://f.cloud.github.com/assets/69169/1625945/b216d7b8-56d9-11e3-8b14-6afc33467be9.png)

## Usage
You can open find and replace for each individual buffer by navigating to _Find > Find in Buffer_ or find and replace for an entire project by navigating to _Find > Find in Project_.  To close, press _Find in Buffer_ or _Find in Project_ again, respectively.

Once opened, the first text box is used to find phrases that can also be replaced by content in the second text box.  `Replace All` will replace all instances of the first text box's text.  If using find in project, there is also an additional text box that allows you to specify which directories/files are to be searched.

There are also multiple options available while using find and replace:
* `.*` - Use Regex
* `Aa` - Match case
* `"` - Only in selection (not available for find in project)
* `\b` - Whole word (not available for find in project)

Want to learn more?  Check out the [Using Atom: Find and Replace](http://flight-manual.atom.io/using-atom/sections/find-and-replace) section in the Atom flight manual.

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

## Contributing
Always feel free to help out!  Whether it's [filing bugs and feature requests](https://github.com/atom/find-and-replace/issues/new) or working on some of the [open issues](https://github.com/atom/find-and-replace/issues), Atom's [contributing guide](https://github.com/atom/atom/blob/master/CONTRIBUTING.md) will help get you started while the [guide for contributing to packages](https://github.com/atom/atom/blob/master/docs/contributing-to-packages.md) has some extra information.

## License
MIT License.  See [the license](LICENSE.md) for more details.
