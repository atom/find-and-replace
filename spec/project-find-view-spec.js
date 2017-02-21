/** @babel */

const os = require('os');
const path = require('path');
const temp = require('temp');
const fs = require('fs-plus');
const dedent = require('dedent');
const {TextBuffer} = require('atom');
const ResultsPaneView = require('../lib/project/results-pane');
const {beforeEach, it, fit, ffit, fffit} = require('./async-spec-helpers')

describe('ProjectFindView', () => {
  const {stoppedChangingDelay} = TextBuffer.prototype;
  let activationPromise, searchPromise, editor, editorElement, findView,
      projectFindView, workspaceElement;

  function getAtomPanel() {
    return workspaceElement.querySelector('.project-find').parentNode;
  }

  function getExistingResultsPane() {
    const pane = atom.workspace.paneForURI(ResultsPaneView.URI);
    if (pane) {
      return pane.itemForURI(ResultsPaneView.URI);
    }
  }

  function getResultsView() {
    return getExistingResultsPane().refs.resultsView;
  }

  beforeEach(() => {
    workspaceElement = atom.views.getView(atom.workspace);
    atom.config.set('core.excludeVcsIgnoredPaths', false);
    atom.project.setPaths([path.join(__dirname,   'fixtures')]);
    jasmine.attachToDOM(workspaceElement);

    activationPromise = atom.packages.activatePackage("find-and-replace").then(function({mainModule}) {
      mainModule.createViews();
      ({findView, projectFindView} = mainModule);
      const spy = spyOn(projectFindView, 'search').andCallFake((options) => {
        return searchPromise = spy.originalValue.call(projectFindView, options);
      });
    });
  });

  describe("when project-find:show is triggered", () => {
    it("attaches ProjectFindView to the root view", async () => {
      atom.commands.dispatch(workspaceElement, 'project-find:show');
      await activationPromise;

      projectFindView.findEditor.setText('items');
      expect(getAtomPanel()).toBeVisible();
      expect(projectFindView.findEditor.getSelectedBufferRange()).toEqual([[0, 0], [0, 5]]);
    });

    describe("with an open buffer", () => {
      beforeEach(async () => {
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        await activationPromise;
        projectFindView.findEditor.setText('');
        editor = await atom.workspace.open('sample.js');
      });

      it("populates the findEditor with selection when there is a selection", () => {
        editor.setSelectedBufferRange([[2, 8], [2, 13]]);
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        expect(getAtomPanel()).toBeVisible();
        expect(projectFindView.findEditor.getText()).toBe('items');

        editor.setSelectedBufferRange([[2, 14], [2, 20]]);
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        expect(getAtomPanel()).toBeVisible();
        expect(projectFindView.findEditor.getText()).toBe('length');
      });

      it("populates the findEditor with the previous selection when there is no selection", () => {
        editor.setSelectedBufferRange([[2, 14], [2, 20]]);
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        expect(getAtomPanel()).toBeVisible();
        expect(projectFindView.findEditor.getText()).toBe('length');

        editor.setSelectedBufferRange([[2, 30], [2, 30]]);
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        expect(getAtomPanel()).toBeVisible();
        expect(projectFindView.findEditor.getText()).toBe('length');
      });

      it("places selected text into the find editor and escapes it when Regex is enabled", () => {
        atom.commands.dispatch(projectFindView.element, 'project-find:toggle-regex-option');
        editor.setSelectedBufferRange([[6, 6], [6, 65]]);
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        expect(projectFindView.findEditor.getText()).toBe('current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);');
      });
    });

    describe("when the ProjectFindView is already attached", () => {
      beforeEach(async () => {
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        await activationPromise;

        projectFindView.findEditor.setText('items');
        projectFindView.findEditor.setSelectedBufferRange([[0, 0], [0, 0]]);
      });

      it("focuses the find editor and selects all the text", () => {
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        expect(projectFindView.findEditor.getElement()).toHaveFocus();
        expect(projectFindView.findEditor.getSelectedText()).toBe("items");
      });
    });

    it("honors config settings for find options", async () => {
      atom.config.set('find-and-replace.useRegex', true);
      atom.config.set('find-and-replace.caseSensitive', true);
      atom.config.set('find-and-replace.wholeWord', true);

      atom.commands.dispatch(workspaceElement, 'project-find:show');
      await activationPromise;

      expect(projectFindView.refs.caseOptionButton).toHaveClass('selected');
      expect(projectFindView.refs.regexOptionButton).toHaveClass('selected');
      expect(projectFindView.refs.wholeWordOptionButton).toHaveClass('selected');
    });
  });

  describe("when project-find:show-in-current-directory is triggered with an open buffer", () => {
    beforeEach(async () => {
      atom.project.setPaths([__dirname]);

      atom.commands.dispatch(workspaceElement, 'project-find:show');
      await activationPromise;

      projectFindView.findEditor.setText('');
      projectFindView.pathsEditor.setText('');
      editor = await atom.workspace.open('fixtures/sample.js');
    });

    it("calls project-find:show, and populates both findEditor and pathsEditor when there is a selection", () => {
      editor.setSelectedBufferRange([[3, 8], [3, 13]]);
      atom.commands.dispatch(workspaceElement, 'project-find:show-in-current-directory');
      expect(getAtomPanel()).toBeVisible();
      expect(projectFindView.findEditor.getText()).toBe('pivot');
      expect(projectFindView.pathsEditor.getText()).toBe('fixtures');

      editor.setSelectedBufferRange([[2, 14], [2, 20]]);
      atom.commands.dispatch(workspaceElement, 'project-find:show-in-current-directory');
      expect(getAtomPanel()).toBeVisible();
      expect(projectFindView.findEditor.getText()).toBe('length');
      expect(projectFindView.pathsEditor.getText()).toBe('fixtures');
    });

    it("calls project-find:show, and populates only pathsEditor when there is no selection", () => {
      atom.commands.dispatch(workspaceElement, 'project-find:show-in-current-directory');
      expect(getAtomPanel()).toBeVisible();
      expect(projectFindView.findEditor.getText()).toBe('');
      expect(projectFindView.pathsEditor.getText()).toBe('fixtures');
    });
  });

  describe("when project-find:toggle is triggered", () => {
    it("toggles the visibility of the ProjectFindView", async () => {
      atom.commands.dispatch(workspaceElement, 'project-find:toggle');
      await activationPromise;

      expect(getAtomPanel()).toBeVisible();
      atom.commands.dispatch(workspaceElement, 'project-find:toggle');
      expect(getAtomPanel()).not.toBeVisible();
    });
  });

  describe("when project-find:show-in-current-directory is triggered", () => {
    let nested, tree, projectPath;

    beforeEach(() => {
      projectPath = temp.mkdirSync("atom");
      atom.project.setPaths([projectPath]);

      tree = document.createElement('div');
      tree.className = 'directory';
      tree.innerHTML = dedent`
        <div>
          <span class='name' data-path='${escapePath(projectPath)}'>${projectPath}</span>
          <ul class='files'>
            <li class='file' data-path='${escapePath(path.join(projectPath, 'one.js'))}'>
              <span class='name'>one.js</span>
            </li>
            <li class='file' data-path='${escapePath(path.join(projectPath, 'two.js'))}'>
              <span class='name'>two.js</span>
            </li>
            <div class='directory'>
              <div>
                <span class='name' data-path='${escapePath(path.join(projectPath, 'nested'))}'>nested</span>
                <ul class='file'>
                  <li class='file' data-path='${escapePath(path.join(projectPath, 'three.js'))}'>
                    <span class='name'>three.js</span>
                  </li>
                </ul>
              </div>
            </div>
          </ul>
        </div>
      `;

      nested = tree.querySelector('.directory');

      workspaceElement.appendChild(tree);
    });

    function escapePath(filePath) {
      return filePath.replace(/\\/g, '&#92;');
    }

    it("populates the pathsEditor when triggered with a directory", async () => {
      atom.commands.dispatch(nested.querySelector('.name'), 'project-find:show-in-current-directory');
      await activationPromise;

      expect(getAtomPanel()).toBeVisible();
      expect(projectFindView.pathsEditor.getText()).toBe('nested');
      expect(projectFindView.findEditor.getElement()).toHaveFocus();

      atom.commands.dispatch(tree.querySelector('.name'), 'project-find:show-in-current-directory');
      expect(projectFindView.pathsEditor.getText()).toBe('');
    });

    it("populates the pathsEditor when triggered on a directory's name", async () => {
      atom.commands.dispatch(nested, 'project-find:show-in-current-directory');
      await activationPromise;

      expect(getAtomPanel()).toBeVisible();
      expect(projectFindView.pathsEditor.getText()).toBe('nested');
      expect(projectFindView.findEditor.getElement()).toHaveFocus();

      atom.commands.dispatch(tree.querySelector('.name'), 'project-find:show-in-current-directory');
      expect(projectFindView.pathsEditor.getText()).toBe('');
    });

    it("populates the pathsEditor when triggered on a file", async () => {
      atom.commands.dispatch(nested.querySelector('.file .name'), 'project-find:show-in-current-directory');
      await activationPromise;

      expect(getAtomPanel()).toBeVisible();
      expect(projectFindView.pathsEditor.getText()).toBe('nested');
      expect(projectFindView.findEditor.getElement()).toHaveFocus();

      atom.commands.dispatch(tree.querySelector('.file .name'), 'project-find:show-in-current-directory');
      expect(projectFindView.pathsEditor.getText()).toBe('');
    });

    describe("when there are multiple root directories", async () => {
      beforeEach(() => {
        atom.project.addPath(temp.mkdirSync("another-path-"))
      });

      it("includes the basename of the containing root directory in the paths-editor", async () => {
        atom.commands.dispatch(nested.querySelector('.file .name'), 'project-find:show-in-current-directory');
        await activationPromise;

        expect(getAtomPanel()).toBeVisible();
        expect(projectFindView.pathsEditor.getText()).toBe(path.join(path.basename(projectPath), 'nested'));
      });
    });
  });

  describe("finding", () => {
    beforeEach(async () => {
      editor = await atom.workspace.open('sample.js');
      editorElement = atom.views.getView(editor);
      atom.commands.dispatch(workspaceElement, 'project-find:show');
      await activationPromise;
    });

    describe("when the find string contains an escaped char", () => {
      beforeEach(() => {
        let projectPath = temp.mkdirSync("atom");
        fs.writeFileSync(path.join(projectPath, "tabs.txt"), "\t\n\\\t\n\\\\t");
        atom.project.setPaths([projectPath]);
        atom.commands.dispatch(workspaceElement, 'project-find:show');
      });

      describe("when regex seach is enabled", () => {
        it("finds a literal tab character", async () => {
          atom.commands.dispatch(projectFindView.element, 'project-find:toggle-regex-option');
          projectFindView.findEditor.setText('\\t');

          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          expect(resultsView.element).toBeVisible();
          expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(2);
        })
      });

      describe("when regex seach is disabled", () => {
        it("finds the escape char", async () => {
          projectFindView.findEditor.setText('\\t');

          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          expect(resultsView.element).toBeVisible();
          expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(1);
        });

        it("finds a backslash", async () => {
          projectFindView.findEditor.setText('\\');

          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          expect(resultsView.element).toBeVisible();
          expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(3);
        });

        it("doesn't insert a escaped char if there are multiple backslashs in front of the char", async () => {
          projectFindView.findEditor.setText('\\\\t');

          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          expect(resultsView.element).toBeVisible();
          expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(1);
        });
      });
    });

    describe("when core:cancel is triggered", () => {
      it("detaches from the root view", () => {
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        projectFindView.element.focus();
        atom.commands.dispatch(document.activeElement, 'core:cancel');
        expect(getAtomPanel()).not.toBeVisible();
      });
    });

    describe("when close option is true", () => {
      it("closes the panel after search", async () => {
        atom.config.set('find-and-replace.closeFindPanelAfterSearch', true);

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        expect(getAtomPanel()).not.toBeVisible();
      });
    });

    describe("splitting into a second pane", () => {
      beforeEach(() => {
        workspaceElement.style.height = '1000px';
        atom.commands.dispatch(editorElement, 'project-find:show');
      });

      it("splits when option is right", async () => {
        const initialPane = atom.workspace.getActivePane();
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'right');
        projectFindView.findEditor.setText('items');

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        expect(atom.workspace.getActivePane()).not.toBe(initialPane);
      });

      it("splits when option is bottom", async () => {
        const initialPane = atom.workspace.getActivePane();
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'down');
        projectFindView.findEditor.setText('items');

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        expect(atom.workspace.getActivePane()).not.toBe(initialPane);
      });

      it("does not split when option is false", async () => {
        const initialPane = atom.workspace.getActivePane();
        projectFindView.findEditor.setText('items');

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        expect(atom.workspace.getActivePane()).toBe(initialPane);
      });

      it("can be duplicated on the right", async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'right');
        projectFindView.findEditor.setText('items');

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        const resultsPaneView1 = atom.views.getView(getExistingResultsPane());
        const pane1 = atom.workspace.getActivePane();
        pane1.splitRight({copyActiveItem: true});

        const pane2 = atom.workspace.getActivePane();
        const resultsPaneView2 = atom.views.getView(pane2.itemForURI(ResultsPaneView.URI));
        expect(pane1).not.toBe(pane2);
        expect(resultsPaneView1).not.toBe(resultsPaneView2);

        const {length: resultCount} = resultsPaneView1.querySelectorAll('li > ul > li');
        expect(resultCount).toBeGreaterThan(0);
        expect(resultsPaneView2.querySelectorAll('li > ul > li')).toHaveLength(resultCount);
        expect(resultsPaneView2.querySelector('.preview-count').innerHTML).toEqual(resultsPaneView1.querySelector('.preview-count').innerHTML);
      });

      it("can be duplicated at the bottom", async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'down');
        projectFindView.findEditor.setText('items');

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        const resultsPaneView1 = atom.views.getView(getExistingResultsPane());
        const pane1 = atom.workspace.getActivePane();
        pane1.splitDown({copyActiveItem: true});

        const pane2 = atom.workspace.getActivePane();
        const resultsPaneView2 = atom.views.getView(pane2.itemForURI(ResultsPaneView.URI));

        expect(pane1).not.toBe(pane2);
        expect(resultsPaneView1).not.toBe(resultsPaneView2);

        const {length: resultCount} = resultsPaneView1.querySelectorAll('li > ul > li');
        expect(resultCount).toBeGreaterThan(0);
        expect(resultsPaneView2.querySelectorAll('li > ul > li')).toHaveLength(resultCount);
        expect(resultsPaneView2.querySelector('.preview-count').innerHTML).toEqual(resultsPaneView1.querySelector('.preview-count').innerHTML);
      });
    });

    describe("serialization", () => {
      it("serializes if the case, regex and whole word options", async () => {
        atom.commands.dispatch(editorElement, 'project-find:show');
        expect(projectFindView.refs.caseOptionButton).not.toHaveClass('selected');
        projectFindView.refs.caseOptionButton.click();
        expect(projectFindView.refs.caseOptionButton).toHaveClass('selected');

        expect(projectFindView.refs.regexOptionButton).not.toHaveClass('selected');
        projectFindView.refs.regexOptionButton.click();
        expect(projectFindView.refs.regexOptionButton).toHaveClass('selected');

        expect(projectFindView.refs.wholeWordOptionButton).not.toHaveClass('selected');
        projectFindView.refs.wholeWordOptionButton.click();
        expect(projectFindView.refs.wholeWordOptionButton).toHaveClass('selected');

        atom.packages.deactivatePackage("find-and-replace");

        activationPromise = atom.packages.activatePackage("find-and-replace").then(function({mainModule}) {
          mainModule.createViews();
          return {projectFindView} = mainModule;
        });

        atom.commands.dispatch(editorElement, 'project-find:show');
        await activationPromise;

        expect(projectFindView.refs.caseOptionButton).toHaveClass('selected');
        expect(projectFindView.refs.regexOptionButton).toHaveClass('selected');
        expect(projectFindView.refs.wholeWordOptionButton).toHaveClass('selected');
      })
    });

    describe("description label", () => {
      beforeEach(() => {
        atom.commands.dispatch(editorElement, 'project-find:show');
      });

      it("indicates that it's searching, then shows the results", async () => {
        projectFindView.findEditor.setText('item');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');

        await projectFindView.showResultPane();

        expect(projectFindView.refs.descriptionLabel.textContent).toContain('Searching...');

        await searchPromise;

        expect(projectFindView.refs.descriptionLabel.textContent).toContain('13 results found in 2 files');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        expect(projectFindView.refs.descriptionLabel.textContent).toContain('13 results found in 2 files');
      });

      it("shows an error when the pattern is invalid and clears when no error", async () => {
        spyOn(atom.workspace, 'scan').andReturn(Promise.resolve());
        atom.commands.dispatch(projectFindView.element, 'project-find:toggle-regex-option');
        projectFindView.findEditor.setText('[');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');

        await searchPromise;

        expect(projectFindView.refs.descriptionLabel).toHaveClass('text-error');
        expect(projectFindView.refs.descriptionLabel.textContent).toContain('Invalid regular expression');

        projectFindView.findEditor.setText('');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');

        expect(projectFindView.refs.descriptionLabel).not.toHaveClass('text-error');
        expect(projectFindView.refs.descriptionLabel.textContent).toContain('Find in Project');

        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');

        await searchPromise;

        expect(projectFindView.refs.descriptionLabel).not.toHaveClass('text-error');
        expect(projectFindView.refs.descriptionLabel.textContent).toContain('items');
      });
    });

    describe("regex", () => {
      beforeEach(() => {
        atom.commands.dispatch(editorElement, 'project-find:show');
        projectFindView.findEditor.setText('i(\\w)ems+');
        spyOn(atom.workspace, 'scan').andCallFake(async () => {});
      });

      it("escapes regex patterns by default", async () => {
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        expect(atom.workspace.scan.argsForCall[0][0]).toEqual(/i\(\\w\)ems\+/gi);
      });

      it("shows an error when the regex pattern is invalid", async () => {
        atom.commands.dispatch(projectFindView.element, 'project-find:toggle-regex-option');
        projectFindView.findEditor.setText('[');

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        expect(projectFindView.refs.descriptionLabel).toHaveClass('text-error');
      });

      describe("when search has not been run yet", () => {
        it("toggles regex option via an event but does not run the search", () => {
          expect(projectFindView.refs.regexOptionButton).not.toHaveClass('selected');
          atom.commands.dispatch(projectFindView.element, 'project-find:toggle-regex-option');
          expect(projectFindView.refs.regexOptionButton).toHaveClass('selected');
          expect(atom.workspace.scan).not.toHaveBeenCalled();
        })
      });

      describe("when search has been run", () => {
        beforeEach(async () => {
          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          await searchPromise;
        });

        it("toggles regex option via an event and finds files matching the pattern", async () => {
          expect(projectFindView.refs.regexOptionButton).not.toHaveClass('selected');
          atom.commands.dispatch(projectFindView.element, 'project-find:toggle-regex-option');

          await searchPromise;

          expect(projectFindView.refs.regexOptionButton).toHaveClass('selected');
          expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual(/i(\w)ems+/gi);
        });

        it("toggles regex option via a button and finds files matching the pattern", async () => {
          expect(projectFindView.refs.regexOptionButton).not.toHaveClass('selected');
          projectFindView.refs.regexOptionButton.click();

          await searchPromise;

          expect(projectFindView.refs.regexOptionButton).toHaveClass('selected');
          expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual(/i(\w)ems+/gi);
        });
      });
    });

    describe("case sensitivity", () => {
      beforeEach(async () => {
        atom.commands.dispatch(editorElement, 'project-find:show');
        spyOn(atom.workspace, 'scan').andCallFake(() => Promise.resolve());
        projectFindView.findEditor.setText('ITEMS');

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;
      });

      it("runs a case insensitive search by default", () => expect(atom.workspace.scan.argsForCall[0][0]).toEqual(/ITEMS/gi));

      it("toggles case sensitive option via an event and finds files matching the pattern", async () => {
        expect(projectFindView.refs.caseOptionButton).not.toHaveClass('selected');

        atom.commands.dispatch(projectFindView.element, 'project-find:toggle-case-option');
        await searchPromise;

        expect(projectFindView.refs.caseOptionButton).toHaveClass('selected');
        expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual(/ITEMS/g);
      });

      it("toggles case sensitive option via a button and finds files matching the pattern", async () => {
        expect(projectFindView.refs.caseOptionButton).not.toHaveClass('selected');

        projectFindView.refs.caseOptionButton.click();
        await searchPromise;

        expect(projectFindView.refs.caseOptionButton).toHaveClass('selected');
        expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual(/ITEMS/g);
      });
    });

    describe("whole word", () => {
      beforeEach(async () => {
        atom.commands.dispatch(editorElement, 'project-find:show');
        spyOn(atom.workspace, 'scan').andCallFake(async () => {});
        projectFindView.findEditor.setText('wholeword');

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;
      });

      it("does not run whole word search by default", () => {
        expect(atom.workspace.scan.argsForCall[0][0]).toEqual(/wholeword/gi)
      });

      it("toggles whole word option via an event and finds files matching the pattern", async () => {
        expect(projectFindView.refs.wholeWordOptionButton).not.toHaveClass('selected');
        atom.commands.dispatch(projectFindView.element, 'project-find:toggle-whole-word-option');

        await searchPromise;
        expect(projectFindView.refs.wholeWordOptionButton).toHaveClass('selected');
        expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual(/\bwholeword\b/gi);
      });

      it("toggles whole word option via a button and finds files matching the pattern", async () => {
        expect(projectFindView.refs.wholeWordOptionButton).not.toHaveClass('selected');

        projectFindView.refs.wholeWordOptionButton.click();
        await searchPromise;

        expect(projectFindView.refs.wholeWordOptionButton).toHaveClass('selected');
        expect(atom.workspace.scan.mostRecentCall.args[0]).toEqual(/\bwholeword\b/gi);
      });
    });

    describe("when project-find:confirm is triggered", () => {
      it("displays the results and no errors", async () => {
        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'project-find:confirm');

        await searchPromise;

        const resultsView = getResultsView();
        expect(resultsView.element).toBeVisible();
        resultsView.scrollToBottom(); // To load ALL the results
        expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(13);
      })
    });

    describe("when core:confirm is triggered", () => {
      beforeEach(() => {
        atom.commands.dispatch(workspaceElement, 'project-find:show')
      });

      describe("when the there search field is empty", () => {
        it("does not run the seach but clears the model", () => {
          spyOn(atom.workspace, 'scan');
          spyOn(projectFindView.model, 'clear');
          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          expect(atom.workspace.scan).not.toHaveBeenCalled();
          expect(projectFindView.model.clear).toHaveBeenCalled();
        })
      });

      it("reruns the search when confirmed again after focusing the window", async () => {
        projectFindView.findEditor.setText('thisdoesnotmatch');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');

        await searchPromise;

        spyOn(atom.workspace, 'scan');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');

        await searchPromise;

        expect(atom.workspace.scan).not.toHaveBeenCalled();
        atom.workspace.scan.reset();
        window.dispatchEvent(new FocusEvent("focus"));
        atom.commands.dispatch(projectFindView.element, 'core:confirm');

        await searchPromise;

        expect(atom.workspace.scan).toHaveBeenCalled();
        atom.workspace.scan.reset();
        atom.commands.dispatch(projectFindView.element, 'core:confirm');

        await searchPromise;

        expect(atom.workspace.scan).not.toHaveBeenCalled();
      });

      describe("when results exist", () => {
        beforeEach(() => {
          projectFindView.findEditor.setText('items')
        });

        it("displays the results and no errors", async () => {
          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          const resultsPaneView = getExistingResultsPane();

          expect(resultsView.element).toBeVisible();
          resultsView.scrollToBottom(); // To load ALL the results
          expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(13);

          expect(resultsPaneView.refs.previewCount.textContent).toBe("13 results found in 2 files for items");
          expect(projectFindView.errorMessages).not.toBeVisible();
        });

        it("only searches paths matching text in the path filter", async () => {
          spyOn(atom.workspace, 'scan').andCallFake(async () => {});
          projectFindView.pathsEditor.setText('*.js');

          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          await searchPromise;

          expect(atom.workspace.scan.argsForCall[0][1].paths).toEqual(['*.js']);
        });

        it("updates the results list when a buffer changes", async () => {
          const buffer = atom.project.bufferForPathSync('sample.js');

          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          const resultsPaneView = getExistingResultsPane();

          resultsView.scrollToBottom(); // To load ALL the results
          expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(13);
          expect(resultsPaneView.refs.previewCount.textContent).toBe("13 results found in 2 files for items");

          resultsView.selectFirstResult();
          for (let i = 0; i < 7; i++) await resultsView.moveDown()
          expect(resultsView.element.querySelectorAll(".path")[1]).toHaveClass('selected');

          buffer.setText('there is one "items" in this file');
          advanceClock(buffer.stoppedChangingDelay);
          expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(8);
          expect(resultsPaneView.refs.previewCount.textContent).toBe("8 results found in 2 files for items");
          expect(resultsView.element.querySelectorAll(".path")[1]).toHaveClass('selected');

          buffer.setText('no matches in this file');
          advanceClock(buffer.stoppedChangingDelay);
          expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(7);
          expect(resultsPaneView.refs.previewCount.textContent).toBe("7 results found in 1 file for items");
        });
      });

      describe("when no results exist", () => {
        beforeEach(() => {
          projectFindView.findEditor.setText('notintheprojectbro');
          spyOn(atom.workspace, 'scan').andCallFake(async () => {});
        });

        it("displays no errors and no results", async () => {
          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          await searchPromise;

          const resultsView = getResultsView();
          expect(projectFindView.refs.errorMessages).not.toBeVisible();
          expect(resultsView.element).toBeVisible();
          expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(0);
        });
      });
    });

    describe("history", () => {
      beforeEach(() => {
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        spyOn(atom.workspace, 'scan').andCallFake(() => {
          let promise = Promise.resolve();
          promise.cancel = () => {};
          return promise;
        });

        projectFindView.findEditor.setText('sort');
        projectFindView.replaceEditor.setText('bort');
        projectFindView.pathsEditor.setText('abc');
        atom.commands.dispatch(projectFindView.findEditor.getElement(), 'core:confirm');

        projectFindView.findEditor.setText('items');
        projectFindView.replaceEditor.setText('eyetims');
        projectFindView.pathsEditor.setText('def');
        atom.commands.dispatch(projectFindView.findEditor.getElement(), 'core:confirm');
      });

      it("can navigate the entire history stack", () => {
        expect(projectFindView.findEditor.getText()).toEqual('items');

        atom.commands.dispatch(projectFindView.findEditor.getElement(), 'core:move-up');
        expect(projectFindView.findEditor.getText()).toEqual('sort');

        atom.commands.dispatch(projectFindView.findEditor.getElement(), 'core:move-down');
        expect(projectFindView.findEditor.getText()).toEqual('items');

        atom.commands.dispatch(projectFindView.findEditor.getElement(), 'core:move-down');
        expect(projectFindView.findEditor.getText()).toEqual('');

        expect(projectFindView.pathsEditor.getText()).toEqual('def');

        atom.commands.dispatch(projectFindView.pathsEditor.element, 'core:move-up');
        expect(projectFindView.pathsEditor.getText()).toEqual('abc');

        atom.commands.dispatch(projectFindView.pathsEditor.element, 'core:move-down');
        expect(projectFindView.pathsEditor.getText()).toEqual('def');

        atom.commands.dispatch(projectFindView.pathsEditor.element, 'core:move-down');
        expect(projectFindView.pathsEditor.getText()).toEqual('');

        expect(projectFindView.replaceEditor.getText()).toEqual('eyetims');

        atom.commands.dispatch(projectFindView.replaceEditor.element, 'core:move-up');
        expect(projectFindView.replaceEditor.getText()).toEqual('bort');

        atom.commands.dispatch(projectFindView.replaceEditor.element, 'core:move-down');
        expect(projectFindView.replaceEditor.getText()).toEqual('eyetims');

        atom.commands.dispatch(projectFindView.replaceEditor.element, 'core:move-down');
        expect(projectFindView.replaceEditor.getText()).toEqual('');
      });
    });

    describe("when find-and-replace:use-selection-as-find-pattern is triggered", () => {
      it("places the selected text into the find editor", () => {
        editor.setSelectedBufferRange([[1, 6], [1, 10]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(projectFindView.findEditor.getText()).toBe('sort');

        editor.setSelectedBufferRange([[1, 13], [1, 21]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(projectFindView.findEditor.getText()).toBe('function');
      });

      it("places the word under the cursor into the find editor", () => {
        editor.setSelectedBufferRange([[1, 8], [1, 8]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(projectFindView.findEditor.getText()).toBe('sort');

        editor.setSelectedBufferRange([[1, 15], [1, 15]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(projectFindView.findEditor.getText()).toBe('function');
      });

      it("places the previously selected text into the find editor if no selection and no word under cursor", () => {
        editor.setSelectedBufferRange([[1, 13], [1, 21]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(projectFindView.findEditor.getText()).toBe('function');

        editor.setSelectedBufferRange([[1, 1], [1, 1]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(projectFindView.findEditor.getText()).toBe('function');
      });

      it("places selected text into the find editor and escapes it when Regex is enabled", () => {
        atom.commands.dispatch(projectFindView.element, 'project-find:toggle-regex-option');
        editor.setSelectedBufferRange([[6, 6], [6, 65]]);
        atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-find-pattern');
        expect(projectFindView.findEditor.getText()).toBe('current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);');
      });
    });

    describe("when there is an error searching", () => {
      it("displays the errors in the results pane", async () => {
        projectFindView.findEditor.setText('items');

        let errorList;
        spyOn(atom.workspace, 'scan').andCallFake(async (regex, options, callback) => {
          const resultsPaneView = getExistingResultsPane();
          ({errorList} = resultsPaneView.refs);
          expect(errorList.querySelectorAll("li")).toHaveLength(0);

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Nope'});
          expect(errorList).toBeVisible();
          expect(errorList.querySelectorAll("li")).toHaveLength(1);

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Broken'});
          expect(errorList.querySelectorAll("li")).toHaveLength(2);
        });

        atom.commands.dispatch(projectFindView.element, 'core:confirm');

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
        advanceClock(projectFindView.findEditor.getBuffer().stoppedChangingDelay + 1);
        spyOn(atom.workspace, 'scan');

        projectFindView.findEditor.setText('findme');
        advanceClock(projectFindView.findEditor.getBuffer().stoppedChangingDelay + 1);

        await projectFindView.search({onlyRunIfActive: false, onlyRunIfChanged: true});
        expect(atom.workspace.scan).toHaveBeenCalled();
      });

      it("shares the buffers and history cyclers between both buffer and project views", () => {
        projectFindView.findEditor.setText('findme');
        projectFindView.replaceEditor.setText('replaceme');

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

        // Back to the project view to make sure we're using the same cycler
        atom.commands.dispatch(editorElement, 'project-find:show');

        expect(projectFindView.findEditor.getText()).toBe('');
        atom.commands.dispatch(projectFindView.findEditor.element, 'core:move-up');
        expect(projectFindView.findEditor.getText()).toBe('findme1');
        atom.commands.dispatch(projectFindView.findEditor.element, 'core:move-up');
        expect(projectFindView.findEditor.getText()).toBe('findme');

        expect(projectFindView.replaceEditor.getText()).toBe('');
        atom.commands.dispatch(projectFindView.replaceEditor.element, 'core:move-up');
        expect(projectFindView.replaceEditor.getText()).toBe('replaceme1');
        atom.commands.dispatch(projectFindView.replaceEditor.element, 'core:move-up');
        expect(projectFindView.replaceEditor.getText()).toBe('replaceme');
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

        projectFindView.findEditor.setText('item');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        const resultsView = getResultsView();
        resultsView.scrollToBottom(); // To load ALL the results
        expect(resultsView.element).toBeVisible();
        expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(13);

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
        atom.commands.dispatch(projectFindView.element, 'project-find:toggle-whole-word-option');
        await searchPromise;

        // sample.js has 0 results for whole word `item`
        expect(getResultDecorations('find-result')).toHaveLength(0);
        expect(workspaceElement).toHaveClass('find-visible');

        // Now we toggle the whole-word option to make sure it is updated in the buffer find
        atom.commands.dispatch(projectFindView.element, 'project-find:toggle-whole-word-option');
      });
    });
  });

  describe("replacing", () => {
    let testDir, sampleJs, sampleCoffee, replacePromise;

    beforeEach(async () => {
      testDir = path.join(os.tmpdir(), "atom-find-and-replace");
      sampleJs = path.join(testDir, 'sample.js');
      sampleCoffee = path.join(testDir, 'sample.coffee');

      fs.makeTreeSync(testDir);
      fs.writeFileSync(sampleCoffee, fs.readFileSync(require.resolve('./fixtures/sample.coffee')));
      fs.writeFileSync(sampleJs, fs.readFileSync(require.resolve('./fixtures/sample.js')));

      atom.commands.dispatch(workspaceElement, 'project-find:show');
      await activationPromise;

      atom.project.setPaths([testDir]);
      const spy = spyOn(projectFindView, 'replaceAll').andCallFake(() => {
        replacePromise = spy.originalValue.call(projectFindView);
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
        atom.commands.dispatch(workspaceElement, 'project-find:show');

        spyOn(atom, 'confirm').andReturn(0);
      });

      describe("when the regex option is chosen", () => {
        beforeEach(async () => {
          atom.commands.dispatch(projectFindView.element, 'project-find:toggle-regex-option');
          projectFindView.findEditor.setText('a');
          atom.commands.dispatch(projectFindView.element, 'project-find:confirm');
          await searchPromise;
        });

        it("finds the escape char", async () => {
          projectFindView.replaceEditor.setText('\\t');

          atom.commands.dispatch(projectFindView.element, 'project-find:replace-all');
          await replacePromise;

          expect(fs.readFileSync(filePath, 'utf8')).toBe("\t\nb\n\t");
        });

        it("doesn't insert a escaped char if there are multiple backslashs in front of the char", async () => {
          projectFindView.replaceEditor.setText('\\\\t');

          atom.commands.dispatch(projectFindView.element, 'project-find:replace-all');
          await replacePromise;

          expect(fs.readFileSync(filePath, 'utf8')).toBe("\\t\nb\n\\t");
        });
      });

      describe("when regex option is not set", () => {
        beforeEach(async () => {
          projectFindView.findEditor.setText('a');
          atom.commands.dispatch(projectFindView.element, 'project-find:confirm');
          await searchPromise;
        });

        it("finds the escape char", async () => {
          projectFindView.replaceEditor.setText('\\t');

          atom.commands.dispatch(projectFindView.element, 'project-find:replace-all');
          await replacePromise;

          expect(fs.readFileSync(filePath, 'utf8')).toBe("\\t\nb\n\\t");
        });
      });
    });

    describe("replace all button enablement", () => {
      let disposable = null;

      it("is disabled initially", () => {
        expect(projectFindView.refs.replaceAllButton).toHaveClass('disabled')
      });

      it("is disabled when a search returns no results", async () => {
        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'project-find:confirm');
        await searchPromise;

        expect(projectFindView.refs.replaceAllButton).not.toHaveClass('disabled');

        projectFindView.findEditor.setText('nopenotinthefile');
        atom.commands.dispatch(projectFindView.element, 'project-find:confirm');
        await searchPromise;

        expect(projectFindView.refs.replaceAllButton).toHaveClass('disabled');
      });

      it("is enabled when a search has results and disabled when there are no results", async () => {
        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'project-find:confirm');

        await searchPromise;

        disposable = projectFindView.replaceTooltipSubscriptions;
        spyOn(disposable, 'dispose');

        expect(projectFindView.refs.replaceAllButton).not.toHaveClass('disabled');

        // The replace all button should still be disabled as the text has been changed and a new search has not been run
        projectFindView.findEditor.setText('itemss');
        advanceClock(stoppedChangingDelay);
        expect(projectFindView.refs.replaceAllButton).toHaveClass('disabled');
        expect(disposable.dispose).toHaveBeenCalled();

        // The button should still be disabled because the search and search pattern are out of sync
        projectFindView.replaceEditor.setText('omgomg');
        advanceClock(stoppedChangingDelay);
        expect(projectFindView.refs.replaceAllButton).toHaveClass('disabled');

        disposable = projectFindView.replaceTooltipSubscriptions;
        spyOn(disposable, 'dispose');
        projectFindView.findEditor.setText('items');
        advanceClock(stoppedChangingDelay);
        expect(projectFindView.refs.replaceAllButton).not.toHaveClass('disabled');

        projectFindView.findEditor.setText('');
        atom.commands.dispatch(projectFindView.element, 'project-find:confirm');

        expect(projectFindView.refs.replaceAllButton).toHaveClass('disabled');
      });
    });

    describe("when the replace button is pressed", () => {
      beforeEach(() => {
        spyOn(atom, 'confirm').andReturn(0);
      });

      it("runs the search, and replaces all the matches", async () => {
        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        projectFindView.replaceEditor.setText('sunshine');
        projectFindView.refs.replaceAllButton.click();
        await replacePromise;

        expect(projectFindView.errorMessages).not.toBeVisible();
        expect(projectFindView.refs.descriptionLabel.textContent).toContain('Replaced');

        const sampleJsContent = fs.readFileSync(sampleJs, 'utf8');
        expect(sampleJsContent.match(/items/g)).toBeFalsy();
        expect(sampleJsContent.match(/sunshine/g)).toHaveLength(6);

        const sampleCoffeeContent = fs.readFileSync(sampleCoffee, 'utf8');
        expect(sampleCoffeeContent.match(/items/g)).toBeFalsy();
        expect(sampleCoffeeContent.match(/sunshine/g)).toHaveLength(7);
      });

      describe("when there are search results after a replace", () => {
        it("runs the search after the replace", async () => {
          projectFindView.findEditor.setText('items');
          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          await searchPromise;

          projectFindView.replaceEditor.setText('items-123');
          projectFindView.refs.replaceAllButton.click();
          await replacePromise;

          expect(projectFindView.errorMessages).not.toBeVisible();
          expect(getExistingResultsPane().refs.previewCount.textContent).toContain('13 results found in 2 files for items');
          expect(projectFindView.refs.descriptionLabel.textContent).toContain('Replaced items with items-123 13 times in 2 files');

          projectFindView.replaceEditor.setText('cats');
          advanceClock(projectFindView.replaceEditor.getBuffer().stoppedChangingDelay);
          expect(projectFindView.refs.descriptionLabel.textContent).not.toContain('Replaced items');
          expect(projectFindView.refs.descriptionLabel.textContent).toContain("13 results found in 2 files for items");
        })
      });
    });

    describe("when the project-find:replace-all is triggered", () => {
      describe("when no search has been run", () => {
        beforeEach(() => {
          spyOn(atom, 'confirm').andReturn(0)
        });

        it("does nothing", () => {
          projectFindView.findEditor.setText('items');
          projectFindView.replaceEditor.setText('sunshine');

          spyOn(atom, 'beep');
          atom.commands.dispatch(projectFindView.element, 'project-find:replace-all');

          expect(replacePromise).toBeUndefined();

          expect(atom.beep).toHaveBeenCalled();
          expect(projectFindView.refs.descriptionLabel.textContent).toContain("Find in Project");
        });
      });

      describe("when a search with no results has been run", () => {
        beforeEach(async () => {
          spyOn(atom, 'confirm').andReturn(0);
          projectFindView.findEditor.setText('nopenotinthefile');
          atom.commands.dispatch(projectFindView.element, 'core:confirm');

          await searchPromise;
        });

        it("doesnt replace anything", () => {
          projectFindView.replaceEditor.setText('sunshine');

          spyOn(atom.workspace, 'scan').andCallThrough();
          spyOn(atom, 'beep');
          atom.commands.dispatch(projectFindView.element, 'project-find:replace-all');

          // The replacement isnt even run
          expect(replacePromise).toBeUndefined();

          expect(atom.workspace.scan).not.toHaveBeenCalled();
          expect(atom.beep).toHaveBeenCalled();
          expect(projectFindView.refs.descriptionLabel.textContent.replace(/(  )/g, ' ')).toContain("No results");
        });
      });

      describe("when a search with results has been run", () => {
        beforeEach(async () => {
          projectFindView.findEditor.setText('items');
          atom.commands.dispatch(projectFindView.element, 'core:confirm');

          await searchPromise;
        });

        it("messages the user when the search text has changed since that last search", () => {
          spyOn(atom, 'confirm').andReturn(0);
          spyOn(atom.workspace, 'scan').andCallThrough();

          projectFindView.findEditor.setText('sort');
          projectFindView.replaceEditor.setText('ok');

          advanceClock(stoppedChangingDelay);
          atom.commands.dispatch(projectFindView.element, 'project-find:replace-all');

          expect(replacePromise).toBeUndefined();
          expect(atom.workspace.scan).not.toHaveBeenCalled();
          expect(atom.confirm).toHaveBeenCalled();
          expect(atom.confirm.mostRecentCall.args[0].message).toContain('was changed to');
        });

        it("replaces all the matches and updates the results view", async () => {
          spyOn(atom, 'confirm').andReturn(0);
          projectFindView.replaceEditor.setText('sunshine');

          expect(projectFindView.errorMessages).not.toBeVisible();
          atom.commands.dispatch(projectFindView.element, 'project-find:replace-all');
          await replacePromise;

          const resultsView = getResultsView();
          expect(resultsView.element).toBeVisible();
          expect(resultsView.element.querySelectorAll("li > ul > li")).toHaveLength(0);

          expect(projectFindView.refs.descriptionLabel.textContent).toContain("Replaced items with sunshine 13 times in 2 files");

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
            projectFindView.replaceEditor.setText('sunshine');

            atom.commands.dispatch(projectFindView.element, 'project-find:replace-all');
            await replacePromise;

            expect(projectFindView.refs.descriptionLabel.textContent).toContain("13 results found");
          });
        });
      });
    });

    describe("when there is an error replacing", () => {
      beforeEach(async () => {
        spyOn(atom, 'confirm').andReturn(0);
        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'project-find:confirm');
        await searchPromise;
      });

      it("displays the errors in the results pane", async () => {
        let errorList
        spyOn(atom.workspace, 'replace').andCallFake(async (regex, replacement, paths, callback) => {
          ({ errorList } = getExistingResultsPane().refs);
          expect(errorList.querySelectorAll("li")).toHaveLength(0);

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Nope'});
          expect(errorList).toBeVisible();
          expect(errorList.querySelectorAll("li")).toHaveLength(1);

          callback(null, {path: '/some/path.js', code: 'ENOENT', message: 'Broken'});
          expect(errorList.querySelectorAll("li")).toHaveLength(2);
        });

        projectFindView.replaceEditor.setText('sunshine');
        atom.commands.dispatch(projectFindView.element, 'project-find:replace-all');
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
      atom.commands.dispatch(workspaceElement, 'project-find:show');
      await activationPromise;
    });

    it("focuses the find editor when the panel gets focus", () => {
      projectFindView.replaceEditor.element.focus();
      expect(projectFindView.replaceEditor.element).toHaveFocus();

      projectFindView.element.focus();
      expect(projectFindView.findEditor.getElement()).toHaveFocus();
    });

    it("moves focus between editors with find-and-replace:focus-next", () => {
      projectFindView.findEditor.element.focus();
      expect(projectFindView.findEditor.element).toHaveFocus()

      atom.commands.dispatch(projectFindView.findEditor.element, 'find-and-replace:focus-next');
      expect(projectFindView.replaceEditor.element).toHaveFocus()

      atom.commands.dispatch(projectFindView.replaceEditor.element, 'find-and-replace:focus-next');
      expect(projectFindView.pathsEditor.element).toHaveFocus()

      atom.commands.dispatch(projectFindView.replaceEditor.element, 'find-and-replace:focus-next');
      expect(projectFindView.findEditor.element).toHaveFocus()

      atom.commands.dispatch(projectFindView.replaceEditor.element, 'find-and-replace:focus-previous');
      expect(projectFindView.pathsEditor.element).toHaveFocus()

      atom.commands.dispatch(projectFindView.replaceEditor.element, 'find-and-replace:focus-previous');
      expect(projectFindView.replaceEditor.element).toHaveFocus()
    });
  });

  describe("panel opening", () => {
    describe("when a panel is already open on the right", () => {
      beforeEach(async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'right');

        editor = await atom.workspace.open('sample.js');
        editorElement = atom.views.getView(editor);

        atom.commands.dispatch(workspaceElement, 'project-find:show');
        await activationPromise;

        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;
      });

      it("doesn't open another panel even if the active pane is vertically split", async () => {
        atom.commands.dispatch(editorElement, 'pane:split-down');
        projectFindView.findEditor.setText('items');

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        expect(workspaceElement.querySelectorAll('.preview-pane').length).toBe(1);
      });
    });

    describe("when a panel is already open at the bottom", () => {
      beforeEach(async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'down');

        editor = await atom.workspace.open('sample.js');
        editorElement = atom.views.getView(editor);

        atom.commands.dispatch(workspaceElement, 'project-find:show');
        await activationPromise;

        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;
      });

      it("doesn't open another panel even if the active pane is horizontally split", async () => {
        atom.commands.dispatch(editorElement, 'pane:split-right');
        projectFindView.findEditor.setText('items');

        atom.commands.dispatch(projectFindView.element, 'core:confirm');
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

      atom.commands.dispatch(workspaceElement, 'project-find:show');
      await activationPromise;

      expect(projectFindView.model.getFindOptions().useRegex).toBe(true);
      expect(projectFindView.findEditor.getGrammar().scopeName).toBe('source.js.regexp');
      expect(projectFindView.replaceEditor.getGrammar().scopeName).toBe('source.js.regexp.replacement');
    });

    describe("when panel is active", () => {
      beforeEach(async () => {
        atom.commands.dispatch(workspaceElement, 'project-find:show');
        await activationPromise;
      });

      it("does not use regexp grammar when in non-regex mode", () => {
        expect(projectFindView.model.getFindOptions().useRegex).not.toBe(true);
        expect(projectFindView.findEditor.getGrammar().scopeName).toBe('text.plain.null-grammar');
        expect(projectFindView.replaceEditor.getGrammar().scopeName).toBe('text.plain.null-grammar');
      });

      it("uses regexp grammar when in regex mode and clears the regexp grammar when regex is disabled", () => {
        atom.commands.dispatch(projectFindView.element, 'project-find:toggle-regex-option');

        expect(projectFindView.model.getFindOptions().useRegex).toBe(true);
        expect(projectFindView.findEditor.getGrammar().scopeName).toBe('source.js.regexp');
        expect(projectFindView.replaceEditor.getGrammar().scopeName).toBe('source.js.regexp.replacement');

        atom.commands.dispatch(projectFindView.element, 'project-find:toggle-regex-option');

        expect(projectFindView.model.getFindOptions().useRegex).not.toBe(true);
        expect(projectFindView.findEditor.getGrammar().scopeName).toBe('text.plain.null-grammar');
        expect(projectFindView.replaceEditor.getGrammar().scopeName).toBe('text.plain.null-grammar');
      });
    });
  });
});