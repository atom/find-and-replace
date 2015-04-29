# Find and Replace [![Build Status](https://travis-ci.org/atom/find-and-replace.svg?branch=master)](https://travis-ci.org/atom/find-and-replace) [![Dependency Status](https://david-dm.org/atom/find-and-replace.svg)](https://david-dm.org/atom/find-and-replace/)

Find and replace in the current buffer or across the entire project in Atom.

## Usage
You can open find and replace for each individual buffer by navigating to _Find > Find in Buffer_ or find and replace for an entire project by navigating to _Find > Find in Project_.  To close, press _Find in Buffer_ or _Find in Project_ again, respectively.

Once opened, the first text box is used to find phrases that can also be replaced by content in the second text box.  `Replace All` will replace all instances of the first text box's text.  If using find in project, there is also an additional text box that allows you to specify which directories/files are to be searched.

There are also multiple options available while using find and replace:
* `.*` - Use Regex
* `Aa` - Match case
* `"` - Only in selection (not available for find in project)
* `\b` - Whole word (not available for find in project)

Want to learn more?  Check out the [Using Atom: Find and Replace](https://atom.io/docs/latest/using-atom-find-and-replace) section in the Atom flight manual.

## Commands
|Command|Selector|Description|
|--------|-------|-----------|
`project-find:show`|`atom-workspace`|Toggles the project find and replace dialog
`project-find:toggle`|`atom-workspace`|Toggles the project find and replace dialog
`project-find:show-in-current-directory`|`atom-workspace`|Only searches within the current directory
`project-find:use-selection-as-find-pattern`|`atom-workspace`|Uses the current text selection as the search pattern
`find-and-replace:toggle`|`atom-workspace`|Toggles the buffer find and replace dialog
`find-and-replace:show-replace`|`atom-workspace`|Toggles the buffer find and replace dialog and focuses the replace text box
`find-and-replace:select-next`|`.editor:not(.mini)`|Select the next occurence of the phrase
`find-and-replace:select-all`|`.editor:not(.mini)`|Select all occurences of the phrase
`find-and-replace:select-undo`|`.editor:not(.mini)`|Undo the last selection
`find-and-replace:select-skip`|`.editor:not(.mini)`|Skip the current selection
`find-and-replace:confirm`|`.find-and-replace`|Find the next occurence of the phrase
`find-and-replace:show-previous`|`.find-and-replace`|Show the previous phrase
`find-and-replace:find-all`|`.find-and-replace`|Find all occurences of the phrase
`find-and-replace:focus-next`|`.find-and-replace`|Focus the next text box in the find and replace dialog
`find-and-replace:focus-previous`|`.find-and-replace`|Focus the previous text box in the find and replace dialog
`find-and-replace:toggle-regex-option`|`.find-and-replace`|Toggle the "regex" option
`find-and-replace:toggle-case-option`|`.find-and-replace`|Toggle the "match case" option
`find-and-replace:toggle-selection-option`|`.find-and-replace`|Toggle the "only in selection" option
`find-and-replace:toggle-whole-word-option`|`.find-and-replace`|Toggle the "whold word" option
`find-and-replace:find-next`|`atom-workspace`|Find the next occurence of the phrase
`find-and-replace:find-previous`|`atom-workspace`|Find the previous occurence of the phrase
`find-and-replace:use-selection-as-find-pattern`|`atom-workspace`|Uses the current text selection as the search pattern
`find-and-replace:replace-previous`|`atom-workspace`|Replace the previous occurence of the phrase
`find-and-replace:replace-next`|`atom-workspace`|Replace the next occurence of the phrase
`find-and-replace:replace-all`|`atom-workspace`|Replace all occurences of the phrase
