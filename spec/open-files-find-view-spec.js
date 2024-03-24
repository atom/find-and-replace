/** @babel */

const os = require('os');
const path = require('path');
const temp = require('temp');
const fs = require('fs-plus');
const {TextBuffer} = require('atom');
const {PathReplacer, PathSearcher} = require('scandal');
const ResultsPaneView = require('../lib/project/results-pane');
const etch = require('etch');
const {beforeEach, it, fit, ffit, fffit, conditionPromise} = require('./async-spec-helpers')

describe('OpenFilesFindView', () => {
  const {stoppedChangingDelay} = TextBuffer.prototype;
  let activationPromise, searchPromise, editor, editorElement, findView,
      openFilesFindView, pathSearcher, workspaceElement;

  function getAtomPanel() {
    return workspaceElement.querySelector('.open-files-find').parentNode;
  }

  function getExistingResultsPane() {
    const pane = atom.workspace.paneForURI(ResultsPaneView.URI);
    if (pane) {

      // Allow element-resize-detector to perform batched measurements
      advanceClock(1);

      return pane.itemForURI(ResultsPaneView.URI);
    }
  }

  function getResultsView() {
    return getExistingResultsPane().refs.resultsView;
  }

  beforeEach(async () => {
    pathSearcher = new PathSearcher();
    workspaceElement = atom.views.getView(atom.workspace);
    atom.config.set('core.excludeVcsIgnoredPaths', false);
    atom.project.setPaths([path.join(__dirname, 'fixtures')]);
    await atom.workspace.open(path.join(__dirname, 'fixtures', 'one-long-line.coffee'));
    await atom.workspace.open(path.join(__dirname, 'fixtures', 'sample.js'));
    jasmine.attachToDOM(workspaceElement);

    activationPromise = atom.packages.activatePackage("find-and-replace").then(function({mainModule}) {
      mainModule.createViews();
      ({findView, openFilesFindView} = mainModule);
      const spy = spyOn(openFilesFindView, 'search').andCallFake((options) => {
        return searchPromise = spy.originalValue.call(openFilesFindView, options);
      });
    });
  });

  describe("when open-files-find:show is triggered", () => {
    it("attaches openFilesFindView to the root view", async () => {
      atom.commands.dispatch(workspaceElement, 'open-files-find:show');
      await activationPromise;

      openFilesFindView.findEditor.setText('items');
      expect(getAtomPanel()).toBeVisible();
      expect(openFilesFindView.findEditor.getSelectedBufferRange()).toEqual([[0, 0], [0, 5]]);
    });

    describe("with an open buffer", () => {
      beforeEach(async () => {
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        await activationPromise;
        openFilesFindView.findEditor.setText('');
        editor = await atom.workspace.open('sample.js');
      });

      it("populates the findEditor with selection when there is a selection", () => {
        editor.setSelectedBufferRange([[2, 8], [2, 13]]);
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        expect(getAtomPanel()).toBeVisible();
        expect(openFilesFindView.findEditor.getText()).toBe('items');

        editor.setSelectedBufferRange([[2, 14], [2, 20]]);
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        expect(getAtomPanel()).toBeVisible();
        expect(openFilesFindView.findEditor.getText()).toBe('length');
      });

      it("populates the findEditor with the previous selection when there is no selection", () => {
        editor.setSelectedBufferRange([[2, 14], [2, 20]]);
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        expect(getAtomPanel()).toBeVisible();
        expect(openFilesFindView.findEditor.getText()).toBe('length');

        editor.setSelectedBufferRange([[2, 30], [2, 30]]);
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        expect(getAtomPanel()).toBeVisible();
        expect(openFilesFindView.findEditor.getText()).toBe('length');
      });

      it("places selected text into the find editor and escapes it when Regex is enabled", () => {
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-regex-option');
        editor.setSelectedBufferRange([[6, 6], [6, 65]]);
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        expect(openFilesFindView.findEditor.getText()).toBe('current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);');
      });
    });

    describe("when the openFilesFindView is already attached", () => {
      beforeEach(async () => {
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        await activationPromise;

        openFilesFindView.findEditor.setText('items');
        openFilesFindView.findEditor.setSelectedBufferRange([[0, 0], [0, 0]]);
      });

      it("focuses the find editor and selects all the text", () => {
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        expect(openFilesFindView.findEditor.getElement()).toHaveFocus();
        expect(openFilesFindView.findEditor.getSelectedText()).toBe("items");
      });
    });

    it("honors config settings for find options", async () => {
      atom.config.set('find-and-replace.useRegex', true);
      atom.config.set('find-and-replace.caseSensitive', true);
      atom.config.set('find-and-replace.wholeWord', true);

      atom.commands.dispatch(workspaceElement, 'open-files-find:show');
      await activationPromise;

      expect(openFilesFindView.refs.caseOptionButton).toHaveClass('selected');
      expect(openFilesFindView.refs.regexOptionButton).toHaveClass('selected');
      expect(openFilesFindView.refs.wholeWordOptionButton).toHaveClass('selected');
    });
  });

  describe("when open-files-find:toggle is triggered", () => {
    it("toggles the visibility of the OpenFilesFindView", async () => {
      atom.commands.dispatch(workspaceElement, 'open-files-find:toggle');
      await activationPromise;

      expect(getAtomPanel()).toBeVisible();
      atom.commands.dispatch(workspaceElement, 'open-files-find:toggle');
      expect(getAtomPanel()).not.toBeVisible();
    });
  });

  describe("finding", () => {
    beforeEach(async () => {
      editor = await atom.workspace.open('sample.js');
      editorElement = atom.views.getView(editor);
      atom.commands.dispatch(workspaceElement, 'open-files-find:show');
      await activationPromise;
      workspaceElement.style.height = '800px'
    });

    describe("when the find string contains an escaped char", () => {
      beforeEach(async () => {
        let projectPath = temp.mkdirSync("atom");
        fs.writeFileSync(path.join(projectPath, "tabs.txt"), "\t\n\\\t\n\\\\t");
        await atom.workspace.open(path.join(projectPath, "tabs.txt"));
        atom.project.setPaths([projectPath]);
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
      });

      describe("when regex seach is enabled", () => {
        it("finds a literal tab character", async () => {
          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-regex-option');
          openFilesFindView.findEditor.setText('\\t');

          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          await resultsView.heightInvalidationPromise
          expect(resultsView.element).toBeVisible();
          expect(resultsView.refs.listView.element.querySelectorAll(".search-result")).toHaveLength(2);
        })
      });

      describe("when regex seach is disabled", () => {
        it("finds the escape char", async () => {
          openFilesFindView.findEditor.setText('\\t');

          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          await resultsView.heightInvalidationPromise
          expect(resultsView.element).toBeVisible();
          expect(resultsView.refs.listView.element.querySelectorAll(".search-result")).toHaveLength(1);
        });

        it("finds a backslash", async () => {
          openFilesFindView.findEditor.setText('\\');

          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          await resultsView.heightInvalidationPromise
          expect(resultsView.element).toBeVisible();
          expect(resultsView.refs.listView.element.querySelectorAll(".search-result")).toHaveLength(3);
        });

        it("doesn't insert a escaped char if there are multiple backslashs in front of the char", async () => {
          openFilesFindView.findEditor.setText('\\\\t');

          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          await resultsView.heightInvalidationPromise
          expect(resultsView.element).toBeVisible();
          expect(resultsView.refs.listView.element.querySelectorAll(".search-result")).toHaveLength(1);
        });
      });
    });

    describe("when core:cancel is triggered", () => {
      it("detaches from the root view", () => {
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        openFilesFindView.element.focus();
        atom.commands.dispatch(document.activeElement, 'core:cancel');
        expect(getAtomPanel()).not.toBeVisible();
      });
    });

    describe("when close option is true", () => {
      beforeEach(() => {
        atom.config.set('find-and-replace.closeFindPanelAfterSearch', true);
      })

      it("closes the panel after search", async () => {
        openFilesFindView.findEditor.setText('something');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        expect(getAtomPanel()).not.toBeVisible();
      });

      it("leaves the panel open after an empty search", async () => {
        openFilesFindView.findEditor.setText('');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        expect(getAtomPanel()).toBeVisible();
      });

      it("closes the panel after a no-op search", async () => {
        openFilesFindView.findEditor.setText('something');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        await activationPromise;

        expect(getAtomPanel()).toBeVisible();

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        expect(getAtomPanel()).not.toBeVisible();
      });

      it("does not close the panel after the replacement text is altered", async () => {
        openFilesFindView.replaceEditor.setText('something else');

        expect(getAtomPanel()).toBeVisible();
      });
    });

    describe("splitting into a second pane", () => {
      beforeEach(() => {
        workspaceElement.style.height = '1000px';
        atom.commands.dispatch(editorElement, 'open-files-find:show');
      });

      it("splits when option is right", async () => {
        const initialPane = atom.workspace.getActivePane();
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'right');
        openFilesFindView.findEditor.setText('items');

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        expect(atom.workspace.getActivePane()).not.toBe(initialPane);
      });

      it("splits when option is bottom", async () => {
        const initialPane = atom.workspace.getActivePane();
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'down');
        openFilesFindView.findEditor.setText('items');

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        expect(atom.workspace.getActivePane()).not.toBe(initialPane);
      });

      it("does not split when option is false", async () => {
        const initialPane = atom.workspace.getActivePane();
        openFilesFindView.findEditor.setText('items');

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        expect(atom.workspace.getActivePane()).toBe(initialPane);
      });

      it("can be duplicated on the right", async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'right');
        openFilesFindView.findEditor.setText('items');

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        const resultsPaneView1 = atom.views.getView(getExistingResultsPane());
        const pane1 = atom.workspace.getActivePane();
        const resultsView1 = pane1.getItems()[0].refs.resultsView
        pane1.splitRight({copyActiveItem: true});

        const pane2 = atom.workspace.getActivePane();
        const resultsView2 = pane2.getItems()[0].refs.resultsView
        const resultsPaneView2 = atom.views.getView(pane2.itemForURI(ResultsPaneView.URI));
        expect(pane1).not.toBe(pane2);
        expect(resultsPaneView1).not.toBe(resultsPaneView2);
        simulateResizeEvent(resultsView2.element);

        const {length: resultCount} = resultsPaneView1.querySelectorAll('.search-result');
        expect(resultCount).toBeGreaterThan(0);
        expect(resultsPaneView2.querySelectorAll('.search-result')).toHaveLength(resultCount);
        expect(resultsPaneView2.querySelector('.preview-count').innerHTML).toEqual(resultsPaneView1.querySelector('.preview-count').innerHTML);
      });

      it("can be duplicated at the bottom", async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'down');
        openFilesFindView.findEditor.setText('items');

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        const resultsPaneView1 = atom.views.getView(getExistingResultsPane());
        const pane1 = atom.workspace.getActivePane();
        const resultsView1 = pane1.getItems()[0].refs.resultsView

        pane1.splitDown({copyActiveItem: true});
        const pane2 = atom.workspace.getActivePane();
        const resultsView2 = pane2.getItems()[0].refs.resultsView
        const resultsPaneView2 = atom.views.getView(pane2.itemForURI(ResultsPaneView.URI));
        expect(pane1).not.toBe(pane2);
        expect(resultsPaneView1).not.toBe(resultsPaneView2);
        expect(resultsPaneView2.querySelector('.preview-count').innerHTML).toEqual(resultsPaneView1.querySelector('.preview-count').innerHTML);
      });
    });

    describe("serialization", () => {
      it("serializes if the case, regex and whole word options", async () => {
        atom.commands.dispatch(editorElement, 'open-files-find:show');
        expect(openFilesFindView.refs.caseOptionButton).not.toHaveClass('selected');
        openFilesFindView.refs.caseOptionButton.click();
        expect(openFilesFindView.refs.caseOptionButton).toHaveClass('selected');

        expect(openFilesFindView.refs.regexOptionButton).not.toHaveClass('selected');
        openFilesFindView.refs.regexOptionButton.click();
        expect(openFilesFindView.refs.regexOptionButton).toHaveClass('selected');

        expect(openFilesFindView.refs.wholeWordOptionButton).not.toHaveClass('selected');
        openFilesFindView.refs.wholeWordOptionButton.click();
        expect(openFilesFindView.refs.wholeWordOptionButton).toHaveClass('selected');

        atom.packages.deactivatePackage("find-and-replace");

        activationPromise = atom.packages.activatePackage("find-and-replace").then(function({mainModule}) {
          mainModule.createViews();
          return {openFilesFindView} = mainModule;
        });

        atom.commands.dispatch(editorElement, 'open-files-find:show');
        await activationPromise;

        expect(openFilesFindView.refs.caseOptionButton).toHaveClass('selected');
        expect(openFilesFindView.refs.regexOptionButton).toHaveClass('selected');
        expect(openFilesFindView.refs.wholeWordOptionButton).toHaveClass('selected');
      })
    });

    describe("description label", () => {
      beforeEach(() => {
        atom.commands.dispatch(editorElement, 'open-files-find:show');
      });

      it("indicates that it's searching, then shows the results", async () => {
        openFilesFindView.findEditor.setText('item');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

        await openFilesFindView.showResultPane();

        expect(openFilesFindView.refs.descriptionLabel.textContent).toContain('Searching...');

        await searchPromise;

        expect(openFilesFindView.refs.descriptionLabel.textContent).toContain('13 results found in 2 open files');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        expect(openFilesFindView.refs.descriptionLabel.textContent).toContain('13 results found in 2 open files');
      });

      it("shows an error when the pattern is invalid and clears when no error", async () => {
        spyOn(pathSearcher, 'searchPaths').andReturn(Promise.resolve()); // TODO: Remove?
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-regex-option');
        openFilesFindView.findEditor.setText('[');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

        await searchPromise;

        expect(openFilesFindView.refs.descriptionLabel).toHaveClass('text-error');
        expect(openFilesFindView.refs.descriptionLabel.textContent).toContain('Invalid regular expression');

        openFilesFindView.findEditor.setText('');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

        expect(openFilesFindView.refs.descriptionLabel).not.toHaveClass('text-error');
        expect(openFilesFindView.refs.descriptionLabel.textContent).toContain('Find in Project');

        openFilesFindView.findEditor.setText('items');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

        await searchPromise;

        expect(openFilesFindView.refs.descriptionLabel).not.toHaveClass('text-error');
        expect(openFilesFindView.refs.descriptionLabel.textContent).toContain('items');
      });
    });

    describe("regex", () => {
      beforeEach(() => {
        atom.commands.dispatch(editorElement, 'open-files-find:show');
        openFilesFindView.findEditor.setText('i(\\w)ems+');
        spyOn(pathSearcher, 'searchPaths').andCallFake(async () => {});
      });

      it("escapes regex patterns by default", async () => {
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        expect(pathSearcher.searchPaths.argsForCall[0][0]).toEqual(/i\(\\w\)ems\+/gi);
      });

      it("shows an error when the regex pattern is invalid", async () => {
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-regex-option');
        openFilesFindView.findEditor.setText('[');

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        expect(openFilesFindView.refs.descriptionLabel).toHaveClass('text-error');
      });

      describe("when search has not been run yet", () => {
        it("toggles regex option via an event but does not run the search", () => {
          expect(openFilesFindView.refs.regexOptionButton).not.toHaveClass('selected');
          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-regex-option');
          expect(openFilesFindView.refs.regexOptionButton).toHaveClass('selected');
          expect(pathSearcher.searchPaths).not.toHaveBeenCalled();
        })
      });

      describe("when search has been run", () => {
        beforeEach(async () => {
          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
          await searchPromise;
        });

        it("toggles regex option via an event and finds files matching the pattern", async () => {
          expect(openFilesFindView.refs.regexOptionButton).not.toHaveClass('selected');
          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-regex-option');

          await searchPromise;

          expect(openFilesFindView.refs.regexOptionButton).toHaveClass('selected');
          expect(pathSearcher.searchPaths.mostRecentCall.args[0]).toEqual(/i(\w)ems+/gi);
        });

        it("toggles regex option via a button and finds files matching the pattern", async () => {
          expect(openFilesFindView.refs.regexOptionButton).not.toHaveClass('selected');
          openFilesFindView.refs.regexOptionButton.click();

          await searchPromise;

          expect(openFilesFindView.refs.regexOptionButton).toHaveClass('selected');
          expect(pathSearcher.searchPaths.mostRecentCall.args[0]).toEqual(/i(\w)ems+/gi);
        });
      });
    });

    describe("case sensitivity", () => {
      beforeEach(async () => {
        atom.commands.dispatch(editorElement, 'open-files-find:show');
        spyOn(pathSearcher, 'searchPaths').andCallFake(() => Promise.resolve());
        openFilesFindView.findEditor.setText('ITEMS');

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;
      });

      it("runs a case insensitive search by default", () => expect(String(PathSearcher.searchPaths.argsForCall[0][0])).toEqual(String(/ITEMS/gi)));

      it("toggles case sensitive option via an event and finds files matching the pattern", async () => {
        expect(openFilesFindView.refs.caseOptionButton).not.toHaveClass('selected');

        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-case-option');
        await searchPromise;

        expect(openFilesFindView.refs.caseOptionButton).toHaveClass('selected');
        expect(pathSearcher.searchPaths.mostRecentCall.args[0]).toEqual(/ITEMS/g);
      });

      it("toggles case sensitive option via a button and finds files matching the pattern", async () => {
        expect(openFilesFindView.refs.caseOptionButton).not.toHaveClass('selected');

        openFilesFindView.refs.caseOptionButton.click();
        await searchPromise;

        expect(openFilesFindView.refs.caseOptionButton).toHaveClass('selected');
        expect(pathSearcher.searchPaths.mostRecentCall.args[0]).toEqual(/ITEMS/g);
      });
    });

    describe("whole word", () => {
      beforeEach(async () => {
        atom.commands.dispatch(editorElement, 'open-files-find:show');
        spyOn(pathSearcher, 'searchPaths').andCallFake(async () => {});
        openFilesFindView.findEditor.setText('wholeword');

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;
      });

      it("does not run whole word search by default", () => {
        expect(pathSearcher.searchPaths.argsForCall[0][0]).toEqual(/wholeword/gi)
      });

      it("toggles whole word option via an event and finds files matching the pattern", async () => {
        expect(openFilesFindView.refs.wholeWordOptionButton).not.toHaveClass('selected');
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-whole-word-option');

        await searchPromise;
        expect(openFilesFindView.refs.wholeWordOptionButton).toHaveClass('selected');
        expect(pathSearcher.searchPaths.mostRecentCall.args[0]).toEqual(/\bwholeword\b/gi);
      });

      it("toggles whole word option via a button and finds files matching the pattern", async () => {
        expect(openFilesFindView.refs.wholeWordOptionButton).not.toHaveClass('selected');

        openFilesFindView.refs.wholeWordOptionButton.click();
        await searchPromise;

        expect(openFilesFindView.refs.wholeWordOptionButton).toHaveClass('selected');
        expect(pathSearcher.searchPaths.mostRecentCall.args[0]).toEqual(/\bwholeword\b/gi);
      });
    });

    describe("when open-files-find:confirm is triggered", () => {
      it("displays the results and no errors", async () => {
        openFilesFindView.findEditor.setText('items');
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:confirm');

        await searchPromise;

        const resultsView = getResultsView();
        await resultsView.heightInvalidationPromise
        expect(resultsView.element).toBeVisible();
        expect(resultsView.refs.listView.element.querySelectorAll(".search-result")).toHaveLength(13);
      })
    });

    describe("when core:confirm is triggered", () => {
      beforeEach(() => {
        atom.commands.dispatch(workspaceElement, 'open-files-find:show')
      });

      describe("when the there search field is empty", () => {
        it("does not run the seach but clears the model", () => {
          spyOn(pathSearcher, 'searchPaths');
          spyOn(openFilesFindView.model, 'clear');
          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
          expect(pathSearcher.searchPaths).not.toHaveBeenCalled();
          expect(openFilesFindView.model.clear).toHaveBeenCalled();
        })
      });

      it("reruns the search when confirmed again after focusing the window", async () => {
        openFilesFindView.findEditor.setText('thisdoesnotmatch');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

        await searchPromise;

        spyOn(pathSearcher, 'searchPaths');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

        await searchPromise;

        expect(pathSearcher.searchPaths).not.toHaveBeenCalled();
        pathSearcher.searchPaths.reset();
        window.dispatchEvent(new FocusEvent("focus"));
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

        await searchPromise;

        expect(pathSearcher.searchPaths).toHaveBeenCalled();
        pathSearcher.searchPaths.reset();
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

        await searchPromise;

        expect(pathSearcher.searchPaths).not.toHaveBeenCalled();
      });

      describe("when results exist", () => {
        beforeEach(() => {
          openFilesFindView.findEditor.setText('items')
        });

        it("displays the results and no errors", async () => {
          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          const resultsPaneView = getExistingResultsPane();

          await resultsView.heightInvalidationPromise
          expect(resultsView.element).toBeVisible();
          expect(resultsView.refs.listView.element.querySelectorAll(".search-result")).toHaveLength(13);

          expect(resultsPaneView.refs.previewCount.textContent).toBe("13 results found in 2 files for items");
          expect(openFilesFindView.errorMessages).not.toBeVisible();
        });

        it("updates the results list when a buffer changes", async () => {
          const buffer = atom.project.bufferForPathSync('sample.js');

          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          const resultsPaneView = getExistingResultsPane();

          await resultsView.heightInvalidationPromise
          expect(resultsView.refs.listView.element.querySelectorAll(".search-result")).toHaveLength(13);
          expect(resultsPaneView.refs.previewCount.textContent).toBe("13 results found in 2 files for items");

          resultsView.selectFirstResult();
          for (let i = 0; i < 7; i++) await resultsView.moveDown()
          expect(resultsView.refs.listView.element.querySelectorAll(".path")[1]).toHaveClass('selected');

          buffer.setText('there is one "items" in this file');
          advanceClock(buffer.stoppedChangingDelay);
          await etch.getScheduler().getNextUpdatePromise()
          expect(resultsPaneView.refs.previewCount.textContent).toBe("8 results found in 2 files for items");
          expect(resultsView.refs.listView.element.querySelectorAll(".path")[1]).toHaveClass('selected');

          buffer.setText('no matches in this file');
          advanceClock(buffer.stoppedChangingDelay);
          await etch.getScheduler().getNextUpdatePromise()
          expect(resultsPaneView.refs.previewCount.textContent).toBe("7 results found in 1 file for items");
        });
      });

      describe("when no results exist", () => {
        beforeEach(() => {
          openFilesFindView.findEditor.setText('notintheprojectbro');
          spyOn(pathSearcher, 'searchPaths').andCallFake(async () => {});
        });

        it("displays no errors and no results", async () => {
          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          expect(openFilesFindView.refs.errorMessages).not.toBeVisible();
          expect(resultsView.element).toBeVisible();
          expect(resultsView.refs.listView.element.querySelectorAll(".search-result")).toHaveLength(0);
        });
      });
    });

    describe("history", () => {
      beforeEach(() => {
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        spyOn(pathSearcher, 'searchPaths').andCallFake(() => {
          let promise = Promise.resolve();
          promise.cancel = () => {};
          return promise;
        });

        openFilesFindView.findEditor.setText('sort');
        openFilesFindView.replaceEditor.setText('bort');
        atom.commands.dispatch(openFilesFindView.findEditor.getElement(), 'core:confirm');

        openFilesFindView.findEditor.setText('items');
        openFilesFindView.replaceEditor.setText('eyetims');
        atom.commands.dispatch(openFilesFindView.findEditor.getElement(), 'core:confirm');
      });

      it("can navigate the entire history stack", () => {
        expect(openFilesFindView.findEditor.getText()).toEqual('items');

        atom.commands.dispatch(openFilesFindView.findEditor.getElement(), 'core:move-up');
        expect(openFilesFindView.findEditor.getText()).toEqual('sort');

        atom.commands.dispatch(openFilesFindView.findEditor.getElement(), 'core:move-down');
        expect(openFilesFindView.findEditor.getText()).toEqual('items');

        atom.commands.dispatch(openFilesFindView.findEditor.getElement(), 'core:move-down');
        expect(openFilesFindView.findEditor.getText()).toEqual('');

        expect(openFilesFindView.replaceEditor.getText()).toEqual('eyetims');

        atom.commands.dispatch(openFilesFindView.replaceEditor.element, 'core:move-up');
        expect(openFilesFindView.replaceEditor.getText()).toEqual('bort');

        atom.commands.dispatch(openFilesFindView.replaceEditor.element, 'core:move-down');
        expect(openFilesFindView.replaceEditor.getText()).toEqual('eyetims');

        atom.commands.dispatch(openFilesFindView.replaceEditor.element, 'core:move-down');
        expect(openFilesFindView.replaceEditor.getText()).toEqual('');
      });
    });

    describe("when find-and-replace:use-selection-as-find-pattern is triggered", () => {
      it("places the selected text into the find editor", () => {
        editor.setSelectedBufferRange([[1, 6], [1, 10]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(openFilesFindView.findEditor.getText()).toBe('sort');

        editor.setSelectedBufferRange([[1, 13], [1, 21]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(openFilesFindView.findEditor.getText()).toBe('function');
      });

      it("places the word under the cursor into the find editor", () => {
        editor.setSelectedBufferRange([[1, 8], [1, 8]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(openFilesFindView.findEditor.getText()).toBe('sort');

        editor.setSelectedBufferRange([[1, 15], [1, 15]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(openFilesFindView.findEditor.getText()).toBe('function');
      });

      it("places the previously selected text into the find editor if no selection and no word under cursor", () => {
        editor.setSelectedBufferRange([[1, 13], [1, 21]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(openFilesFindView.findEditor.getText()).toBe('function');

        editor.setSelectedBufferRange([[1, 1], [1, 1]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(openFilesFindView.findEditor.getText()).toBe('function');
      });

      it("places selected text into the find editor and escapes it when Regex is enabled", () => {
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-regex-option');
        editor.setSelectedBufferRange([[6, 6], [6, 65]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(openFilesFindView.findEditor.getText()).toBe('current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);');
      });
    });

    describe("when there is an error searching", () => {
      it("displays the errors in the results pane", async () => {
        openFilesFindView.findEditor.setText('items');

        let errorList;
        spyOn(pathSearcher, 'searchPaths').andCallFake(async (regex, options, callback) => {
          const resultsPaneView = getExistingResultsPane();
          ({errorList} = resultsPaneView.refs);
          expect(errorList.querySelectorAll("li")).toHaveLength(0);

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Nope'});
          expect(errorList).toBeVisible();
          expect(errorList.querySelectorAll("li")).toHaveLength(1);

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Broken'});
          expect(errorList.querySelectorAll("li")).toHaveLength(2);
        });

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

        await searchPromise;

        expect(errorList).toBeVisible();
        expect(errorList.querySelectorAll("li")).toHaveLength(2);
        expect(errorList.querySelectorAll("li")[0].textContent).toBe('Nope');
        expect(errorList.querySelectorAll("li")[1].textContent).toBe('Broken');
      })
    });

    describe("buffer search sharing of the find options", () => {
      function getResultDecorations(clazz) {
        const result = [];
        const decorations = editor.decorationsStateForScreenRowRange(0, editor.getLineCount());
        for (let id in decorations) {
          const decoration = decorations[id];
          if (decoration.properties.class === clazz) {
            result.push(decoration);
          }
        }
        return result;
      }

      it("setting the find text does not interfere with the project replace state", async () => {
        // Not sure why I need to advance the clock before setting the text. If
        // this advanceClock doesnt happen, the text will be ''. wtf.
        advanceClock(openFilesFindView.findEditor.getBuffer().stoppedChangingDelay + 1);

        openFilesFindView.findEditor.setText('findme');
        advanceClock(openFilesFindView.findEditor.getBuffer().stoppedChangingDelay + 1);

        await openFilesFindView.search({onlyRunIfActive: false, onlyRunIfChanged: true});
        expect(pathSearcher.searchPaths).toHaveBeenCalled();
      });

      it("shares the buffers and history cyclers between both buffer and open files views", () => {
        openFilesFindView.findEditor.setText('findme');
        openFilesFindView.replaceEditor.setText('replaceme');

        atom.commands.dispatch(editorElement, 'find-and-replace:show');
        expect(findView.findEditor.getText()).toBe('findme');
        expect(findView.replaceEditor.getText()).toBe('replaceme');

        // add some things to the history
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm');
        findView.findEditor.setText('findme1');
        atom.commands.dispatch(findView.findEditor.element, 'core:confirm');
        findView.findEditor.setText('');

        atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm');
        findView.replaceEditor.setText('replaceme1');
        atom.commands.dispatch(findView.replaceEditor.element, 'core:confirm');
        findView.replaceEditor.setText('');

        // Back to the open files view to make sure we're using the same cycler
        atom.commands.dispatch(editorElement, 'open-files-find:show');

        expect(openFilesFindView.findEditor.getText()).toBe('');
        atom.commands.dispatch(openFilesFindView.findEditor.element, 'core:move-up');
        expect(openFilesFindView.findEditor.getText()).toBe('findme1');
        atom.commands.dispatch(openFilesFindView.findEditor.element, 'core:move-up');
        expect(openFilesFindView.findEditor.getText()).toBe('findme');

        expect(openFilesFindView.replaceEditor.getText()).toBe('');
        atom.commands.dispatch(openFilesFindView.replaceEditor.element, 'core:move-up');
        expect(openFilesFindView.replaceEditor.getText()).toBe('replaceme1');
        atom.commands.dispatch(openFilesFindView.replaceEditor.element, 'core:move-up');
        expect(openFilesFindView.replaceEditor.getText()).toBe('replaceme');
      });

      it('highlights the search results in the selected file', async () => {
        // Process here is to
        // * open samplejs
        // * run a search that has sample js results
        // * that should place the pattern in the buffer find
        // * focus sample.js by clicking on a sample.js result
        // * when the file has been activated, it's results for the project search should be highlighted

        editor = await atom.workspace.open('sample.js');
        expect(getResultDecorations('find-result')).toHaveLength(0);

        openFilesFindView.findEditor.setText('item');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        const resultsView = getResultsView();
        resultsView.scrollToBottom(); // To load ALL the results
        expect(resultsView.element).toBeVisible();
        expect(resultsView.refs.listView.element.querySelectorAll(".search-result")).toHaveLength(13);

        resultsView.selectFirstResult();
        for (let i = 0; i < 10; i++) await resultsView.moveDown();

        atom.commands.dispatch(resultsView.element, 'core:confirm');
        await new Promise(resolve => editor.onDidChangeSelectionRange(resolve))

        // sample.js has 6 results
        expect(getResultDecorations('find-result')).toHaveLength(5);
        expect(getResultDecorations('current-result')).toHaveLength(1);
        expect(workspaceElement).toHaveClass('find-visible');

        const initialSelectedRange = editor.getSelectedBufferRange();

        // now we can find next
        atom.commands.dispatch(atom.views.getView(editor), 'find-and-replace:find-next');
        expect(editor.getSelectedBufferRange()).not.toEqual(initialSelectedRange);

        // Now we toggle the whole-word option to make sure it is updated in the buffer find
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-whole-word-option');
        await searchPromise;

        // sample.js has 0 results for whole word `item`
        expect(getResultDecorations('find-result')).toHaveLength(0);
        expect(workspaceElement).toHaveClass('find-visible');

        // Now we toggle the whole-word option to make sure it is updated in the buffer find
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-whole-word-option');
      });
    });
  });

  describe("replacing", () => {
    let testDir, sampleJs, sampleCoffee, replacePromise;

    beforeEach(async () => {
      pathReplacer = new PathReplacer();
      testDir = path.join(os.tmpdir(), "atom-find-and-replace");
      sampleJs = path.join(testDir, 'sample.js');
      sampleCoffee = path.join(testDir, 'sample.coffee');

      fs.makeTreeSync(testDir);
      fs.writeFileSync(sampleCoffee, fs.readFileSync(require.resolve('./fixtures/sample.coffee')));
      fs.writeFileSync(sampleJs, fs.readFileSync(require.resolve('./fixtures/sample.js')));

      atom.commands.dispatch(workspaceElement, 'open-files-find:show');
      await activationPromise;

      atom.project.setPaths([testDir]);
      const spy = spyOn(openFilesFindView, 'replaceAll').andCallFake(() => {
        replacePromise = spy.originalValue.call(openFilesFindView);
      });
    });

    afterEach(async () => {
      // On Windows, you can not remove a watched directory/file, therefore we
      // have to close the project before attempting to delete. Unfortunately,
      // Pathwatcher's close function is also not synchronous. Once
      // atom/node-pathwatcher#4 is implemented this should be alot cleaner.
      let activePane = atom.workspace.getActivePane();
      if (activePane) {
        for (const item of activePane.getItems()) {
          if (item.shouldPromptToSave != null) {
            spyOn(item, 'shouldPromptToSave').andReturn(false);
          }
          activePane.destroyItem(item);
        }
      }

      for (;;) {
        try {
          fs.removeSync(testDir);
          break
        } catch (e) {
          await new Promise(resolve => setTimeout(resolve, 50))
        }
      }
    });

    describe("when the replace string contains an escaped char", () => {
      let filePath = null;

      beforeEach(() => {
        let projectPath = temp.mkdirSync("atom");
        filePath = path.join(projectPath, "tabs.txt");
        fs.writeFileSync(filePath, "a\nb\na");
        atom.project.setPaths([projectPath]);
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');

        spyOn(atom, 'confirm').andReturn(0);
      });

      describe("when the regex option is chosen", () => {
        beforeEach(async () => {
          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-regex-option');
          openFilesFindView.findEditor.setText('a');
          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:confirm');
          await searchPromise;
        });

        it("finds the escape char", async () => {
          openFilesFindView.replaceEditor.setText('\\t');

          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:replace-all');
          await replacePromise;

          expect(fs.readFileSync(filePath, 'utf8')).toBe("\t\nb\n\t");
        });

        it("doesn't insert an escaped char if there are multiple backslashs in front of the char", async () => {
          openFilesFindView.replaceEditor.setText('\\\\t');

          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:replace-all');
          await replacePromise;

          expect(fs.readFileSync(filePath, 'utf8')).toBe("\\t\nb\n\\t");
        });
      });

      describe("when regex option is not set", () => {
        beforeEach(async () => {
          openFilesFindView.findEditor.setText('a');
          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:confirm');
          await searchPromise;
        });

        it("finds the escape char", async () => {
          openFilesFindView.replaceEditor.setText('\\t');

          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:replace-all');
          await replacePromise;

          expect(fs.readFileSync(filePath, 'utf8')).toBe("\\t\nb\n\\t");
        });
      });
    });

    describe("replace all button enablement", () => {
      let disposable = null;

      it("is disabled initially", () => {
        expect(openFilesFindView.refs.replaceAllButton).toHaveClass('disabled')
      });

      it("is disabled when a search returns no results", async () => {
        openFilesFindView.findEditor.setText('items');
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:confirm');
        await searchPromise;

        expect(openFilesFindView.refs.replaceAllButton).not.toHaveClass('disabled');

        openFilesFindView.findEditor.setText('nopenotinthefile');
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:confirm');
        await searchPromise;

        expect(openFilesFindView.refs.replaceAllButton).toHaveClass('disabled');
      });

      it("is enabled when a search has results and disabled when there are no results", async () => {
        openFilesFindView.findEditor.setText('items');
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:confirm');

        await searchPromise;

        disposable = openFilesFindView.replaceTooltipSubscriptions;
        spyOn(disposable, 'dispose');

        expect(openFilesFindView.refs.replaceAllButton).not.toHaveClass('disabled');

        // The replace all button should still be disabled as the text has been changed and a new search has not been run
        openFilesFindView.findEditor.setText('itemss');
        advanceClock(stoppedChangingDelay);
        expect(openFilesFindView.refs.replaceAllButton).toHaveClass('disabled');
        expect(disposable.dispose).toHaveBeenCalled();

        // The button should still be disabled because the search and search pattern are out of sync
        openFilesFindView.replaceEditor.setText('omgomg');
        advanceClock(stoppedChangingDelay);
        expect(openFilesFindView.refs.replaceAllButton).toHaveClass('disabled');

        disposable = openFilesFindView.replaceTooltipSubscriptions;
        spyOn(disposable, 'dispose');
        openFilesFindView.findEditor.setText('items');
        advanceClock(stoppedChangingDelay);
        expect(openFilesFindView.refs.replaceAllButton).not.toHaveClass('disabled');

        openFilesFindView.findEditor.setText('');
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:confirm');

        expect(openFilesFindView.refs.replaceAllButton).toHaveClass('disabled');
      });
    });

    describe("when the replace button is pressed", () => {
      beforeEach(() => {
        spyOn(atom, 'confirm').andReturn(0);
      });

      it("runs the search, and replaces all the matches", async () => {
        openFilesFindView.findEditor.setText('items');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        openFilesFindView.replaceEditor.setText('sunshine');
        openFilesFindView.refs.replaceAllButton.click();
        await replacePromise;

        expect(openFilesFindView.errorMessages).not.toBeVisible();
        expect(openFilesFindView.refs.descriptionLabel.textContent).toContain('Replaced');

        const sampleJsContent = fs.readFileSync(sampleJs, 'utf8');
        expect(sampleJsContent.match(/items/g)).toBeFalsy();
        expect(sampleJsContent.match(/sunshine/g)).toHaveLength(6);

        const sampleCoffeeContent = fs.readFileSync(sampleCoffee, 'utf8');
        expect(sampleCoffeeContent.match(/items/g)).toBeFalsy();
        expect(sampleCoffeeContent.match(/sunshine/g)).toHaveLength(7);
      });

      describe("when there are search results after a replace", () => {
        it("runs the search after the replace", async () => {
          openFilesFindView.findEditor.setText('items');
          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
          await searchPromise;

          openFilesFindView.replaceEditor.setText('items-123');
          openFilesFindView.refs.replaceAllButton.click();
          await replacePromise;

          expect(openFilesFindView.errorMessages).not.toBeVisible();
          expect(getExistingResultsPane().refs.previewCount.textContent).toContain('13 results found in 2 open files for items');
          expect(openFilesFindView.refs.descriptionLabel.textContent).toContain('Replaced items with items-123 13 times in 2 open files');

          openFilesFindView.replaceEditor.setText('cats');
          advanceClock(openFilesFindView.replaceEditor.getBuffer().stoppedChangingDelay);
          expect(openFilesFindView.refs.descriptionLabel.textContent).not.toContain('Replaced items');
          expect(openFilesFindView.refs.descriptionLabel.textContent).toContain("13 results found in 2 open files for items");
        })
      });
    });

    describe("when the open-files-find:replace-all is triggered", () => {
      describe("when no search has been run", () => {
        beforeEach(() => {
          spyOn(atom, 'confirm').andReturn(0)
        });

        it("does nothing", () => {
          openFilesFindView.findEditor.setText('items');
          openFilesFindView.replaceEditor.setText('sunshine');

          spyOn(atom, 'beep');
          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:replace-all');

          expect(replacePromise).toBeUndefined();

          expect(atom.beep).toHaveBeenCalled();
          expect(openFilesFindView.refs.descriptionLabel.textContent).toContain("Find in Open Files");
        });
      });

      describe("when a search with no results has been run", () => {
        beforeEach(async () => {
          spyOn(atom, 'confirm').andReturn(0);
          openFilesFindView.findEditor.setText('nopenotinthefile');
          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

          await searchPromise;
        });

        it("doesnt replace anything", () => {
          openFilesFindView.replaceEditor.setText('sunshine');

          spyOn(pathSearcher, 'searchPaths').andCallThrough();
          spyOn(atom, 'beep');
          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:replace-all');

          // The replacement isnt even run
          expect(replacePromise).toBeUndefined();

          expect(pathSearcher.searchPaths).not.toHaveBeenCalled();
          expect(atom.beep).toHaveBeenCalled();
          expect(openFilesFindView.refs.descriptionLabel.textContent.replace(/(  )/g, ' ')).toContain("No results");
        });
      });

      describe("when a search with results has been run", () => {
        beforeEach(async () => {
          openFilesFindView.findEditor.setText('items');
          atom.commands.dispatch(openFilesFindView.element, 'core:confirm');

          await searchPromise;
        });

        it("messages the user when the search text has changed since that last search", () => {
          spyOn(atom, 'confirm').andReturn(0);
          spyOn(pathSearcher, 'searchPaths').andCallThrough();

          openFilesFindView.findEditor.setText('sort');
          openFilesFindView.replaceEditor.setText('ok');

          advanceClock(stoppedChangingDelay);
          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:replace-all');

          expect(replacePromise).toBeUndefined();
          expect(pathSearcher.searchPaths).not.toHaveBeenCalled();
          expect(atom.confirm).toHaveBeenCalled();
          expect(atom.confirm.mostRecentCall.args[0].message).toContain('was changed to');
        });

        it("replaces all the matches and updates the results view", async () => {
          spyOn(atom, 'confirm').andReturn(0);
          openFilesFindView.replaceEditor.setText('sunshine');

          expect(openFilesFindView.errorMessages).not.toBeVisible();
          atom.commands.dispatch(openFilesFindView.element, 'open-files-find:replace-all');
          await replacePromise;

          const resultsView = getResultsView();
          expect(resultsView.element).toBeVisible();
          expect(resultsView.refs.listView.element.querySelectorAll(".search-result")).toHaveLength(0);

          expect(openFilesFindView.refs.descriptionLabel.textContent).toContain("Replaced items with sunshine 13 times in 2 open files");

          let sampleJsContent = fs.readFileSync(sampleJs, 'utf8');
          expect(sampleJsContent.match(/items/g)).toBeFalsy();
          expect(sampleJsContent.match(/sunshine/g)).toHaveLength(6);

          let sampleCoffeeContent = fs.readFileSync(sampleCoffee, 'utf8');
          expect(sampleCoffeeContent.match(/items/g)).toBeFalsy();
          expect(sampleCoffeeContent.match(/sunshine/g)).toHaveLength(7);
        });

        describe("when the confirm box is cancelled", () => {
          beforeEach(() => {
            spyOn(atom, 'confirm').andReturn(1)
          });

          it("does not replace", async () => {
            openFilesFindView.replaceEditor.setText('sunshine');

            atom.commands.dispatch(openFilesFindView.element, 'open-files-find:replace-all');
            await replacePromise;

            expect(openFilesFindView.refs.descriptionLabel.textContent).toContain("13 results found");
          });
        });
      });
    });

    describe("when there is an error replacing", () => {
      beforeEach(async () => {
        spyOn(atom, 'confirm').andReturn(0);
        openFilesFindView.findEditor.setText('items');
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:confirm');
        await searchPromise;
      });

      it("displays the errors in the results pane", async () => {
        let errorList
        spyOn(pathReplacer, 'replacePaths').andCallFake(async (regex, replacement, paths, callback) => {
          ({ errorList } = getExistingResultsPane().refs);
          expect(errorList.querySelectorAll("li")).toHaveLength(0);

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Nope'});
          expect(errorList).toBeVisible();
          expect(errorList.querySelectorAll("li")).toHaveLength(1);

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Broken'});
          expect(errorList.querySelectorAll("li")).toHaveLength(2);
        });

        openFilesFindView.replaceEditor.setText('sunshine');
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:replace-all');
        await replacePromise;

        expect(errorList).toBeVisible();
        expect(errorList.querySelectorAll("li")).toHaveLength(2);
        expect(errorList.querySelectorAll("li")[0].textContent).toBe('Nope');
        expect(errorList.querySelectorAll("li")[1].textContent).toBe('Broken');
      });
    });
  });

  describe("panel focus", () => {
    beforeEach(async () => {
      atom.commands.dispatch(workspaceElement, 'open-files-find:show');
      await activationPromise;
    });

    it("focuses the find editor when the panel gets focus", () => {
      openFilesFindView.replaceEditor.element.focus();
      expect(openFilesFindView.replaceEditor.element).toHaveFocus();

      openFilesFindView.element.focus();
      expect(openFilesFindView.findEditor.getElement()).toHaveFocus();
    });

    it("moves focus between editors with find-and-replace:focus-next", () => {
      openFilesFindView.findEditor.element.focus();
      expect(openFilesFindView.findEditor.element).toHaveFocus()

      atom.commands.dispatch(openFilesFindView.findEditor.element, 'find-and-replace:focus-next');
      expect(openFilesFindView.replaceEditor.element).toHaveFocus()

      atom.commands.dispatch(openFilesFindView.replaceEditor.element, 'find-and-replace:focus-next');
      expect(openFilesFindView.findEditor.element).toHaveFocus()

      atom.commands.dispatch(openFilesFindView.replaceEditor.element, 'find-and-replace:focus-previous');
      expect(openFilesFindView.replaceEditor.element).toHaveFocus()
    });
  });

  describe("panel opening", () => {
    describe("when a panel is already open on the right", () => {
      beforeEach(async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'right');

        editor = await atom.workspace.open('sample.js');
        editorElement = atom.views.getView(editor);

        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        await activationPromise;

        openFilesFindView.findEditor.setText('items');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;
      });

      it("doesn't open another panel even if the active pane is vertically split", async () => {
        atom.commands.dispatch(editorElement, 'pane:split-down');
        openFilesFindView.findEditor.setText('items');

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        expect(workspaceElement.querySelectorAll('.preview-pane').length).toBe(1);
      });
    });

    describe("when a panel is already open at the bottom", () => {
      beforeEach(async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'down');

        editor = await atom.workspace.open('sample.js');
        editorElement = atom.views.getView(editor);

        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        await activationPromise;

        openFilesFindView.findEditor.setText('items');
        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;
      });

      it("doesn't open another panel even if the active pane is horizontally split", async () => {
        atom.commands.dispatch(editorElement, 'pane:split-right');
        openFilesFindView.findEditor.setText('items');

        atom.commands.dispatch(openFilesFindView.element, 'core:confirm');
        await searchPromise;

        expect(workspaceElement.querySelectorAll('.preview-pane').length).toBe(1);
      });
    });
  });

  describe("when language-javascript is active", () => {
    beforeEach(async () => {
      await atom.packages.activatePackage("language-javascript");
    });

    it("uses the regexp grammar when regex-mode is loaded from configuration", async () => {
      atom.config.set('find-and-replace.useRegex', true);

      atom.commands.dispatch(workspaceElement, 'open-files-find:show');
      await activationPromise;

      expect(openFilesFindView.model.getFindOptions().useRegex).toBe(true);
      expect(openFilesFindView.findEditor.getGrammar().scopeName).toBe('source.js.regexp');
      expect(openFilesFindView.replaceEditor.getGrammar().scopeName).toBe('source.js.regexp.replacement');
    });

    describe("when panel is active", () => {
      beforeEach(async () => {
        atom.commands.dispatch(workspaceElement, 'open-files-find:show');
        await activationPromise;
      });

      it("does not use regexp grammar when in non-regex mode", () => {
        expect(openFilesFindView.model.getFindOptions().useRegex).not.toBe(true);
        expect(openFilesFindView.findEditor.getGrammar().scopeName).toBe('text.plain.null-grammar');
        expect(openFilesFindView.replaceEditor.getGrammar().scopeName).toBe('text.plain.null-grammar');
      });

      it("uses regexp grammar when in regex mode and clears the regexp grammar when regex is disabled", () => {
        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-regex-option');

        expect(openFilesFindView.model.getFindOptions().useRegex).toBe(true);
        expect(openFilesFindView.findEditor.getGrammar().scopeName).toBe('source.js.regexp');
        expect(openFilesFindView.replaceEditor.getGrammar().scopeName).toBe('source.js.regexp.replacement');

        atom.commands.dispatch(openFilesFindView.element, 'open-files-find:toggle-regex-option');

        expect(openFilesFindView.model.getFindOptions().useRegex).not.toBe(true);
        expect(openFilesFindView.findEditor.getGrammar().scopeName).toBe('text.plain.null-grammar');
        expect(openFilesFindView.replaceEditor.getGrammar().scopeName).toBe('text.plain.null-grammar');
      });
    });
  });
});

function simulateResizeEvent(element) {
  Array.from(element.children).forEach((child) => {
    child.dispatchEvent(new AnimationEvent('animationstart'));
  });
  advanceClock(1);
}
