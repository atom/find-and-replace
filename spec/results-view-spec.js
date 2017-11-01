/** @babel */

const _ = require('underscore-plus');
const path = require('path');
const temp = require('temp');
const fs = require('fs');
const etch = require('etch');
const ResultsPaneView = require('../lib/project/results-pane');
const getIconServices = require('../lib/get-icon-services');
const DefaultFileIcons = require('../lib/default-file-icons');
const {Disposable} = require('atom')
const {beforeEach, it, fit, ffit, fffit} = require('./async-spec-helpers')

global.beforeEach(function() {
  this.addMatchers({
    toBeWithin(value, delta) {
      this.message = `Expected ${this.actual} to be within ${delta} of ${value}`
      return Math.abs(this.actual - value) < delta;
    }
  });
});

describe('ResultsView', () => {
  let projectFindView, resultsView, searchPromise, workspaceElement;

  function getResultsPane() {
    let pane = atom.workspace.paneForURI(ResultsPaneView.URI);

    // Allow element-resize-detector to perform batched measurements
    advanceClock(1);

    if (pane) return pane.itemForURI(ResultsPaneView.URI);
  }

  function getResultsView() {
    return getResultsPane().refs.resultsView;
  }

  beforeEach(async () => {
    workspaceElement = atom.views.getView(atom.workspace);
    workspaceElement.style.height = '1000px';
    jasmine.attachToDOM(workspaceElement);

    atom.config.set('core.excludeVcsIgnoredPaths', false);
    atom.project.setPaths([path.join(__dirname, 'fixtures')]);

    let activationPromise = atom.packages.activatePackage("find-and-replace").then(function({mainModule}) {
      mainModule.createViews();
      ({projectFindView} = mainModule);
      const spy = spyOn(projectFindView, 'confirm').andCallFake(() => {
        return searchPromise = spy.originalValue.call(projectFindView)
      });
    });

    atom.commands.dispatch(workspaceElement, 'project-find:show');

    await activationPromise;
  });

  describe("when the result is for a long line", () => {
    it("renders the context around the match", async () => {
      projectFindView.findEditor.setText('ghijkl');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.refs.listView.element.querySelector('.path-name').textContent).toBe("one-long-line.coffee");
      expect(resultsView.refs.listView.element.querySelectorAll('.preview').length).toBe(1);
      expect(resultsView.refs.listView.element.querySelector('.preview').textContent).toBe('test test test test test test test test test test test a b c d e f g h i j k l abcdefghijklmnopqrstuvwxyz');
      expect(resultsView.refs.listView.element.querySelector('.match').textContent).toBe('ghijkl');
    })
  });

  describe("when there are multiple project paths", () => {
    beforeEach(() => {
      atom.project.addPath(temp.mkdirSync("another-project-path"))
    });

    it("includes the basename of the project path that contains the match", async () => {
      projectFindView.findEditor.setText('ghijkl');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.refs.listView.element.querySelector('.path-name').textContent).toBe(path.join("fixtures", "one-long-line.coffee"));
    });
  });

  describe("rendering replacement text", () => {
    let modifiedDelay = null;

    beforeEach(() => {
      projectFindView.findEditor.setText('ghijkl');
      modifiedDelay = projectFindView.replaceEditor.getBuffer().stoppedChangingDelay;
    });

    it("renders the replacement when doing a search and there is a replacement pattern", async () => {
      projectFindView.replaceEditor.setText('cats');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.refs.listView.element.querySelector('.path-name').textContent).toBe("one-long-line.coffee");
      expect(resultsView.refs.listView.element.querySelectorAll('.preview').length).toBe(1);
      expect(resultsView.refs.listView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.refs.listView.element.querySelector('.replacement').textContent).toBe('cats');
    });

    it("renders the replacement when changing the text in the replacement field", async () => {
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.refs.listView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.refs.listView.element.querySelector('.match')).toHaveClass('highlight-info');
      expect(resultsView.refs.listView.element.querySelector('.replacement').textContent).toBe('');
      expect(resultsView.refs.listView.element.querySelector('.replacement')).toBeHidden();

      projectFindView.replaceEditor.setText('cats');
      advanceClock(modifiedDelay);

      expect(resultsView.refs.listView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.refs.listView.element.querySelector('.match')).toHaveClass('highlight-error');
      expect(resultsView.refs.listView.element.querySelector('.replacement').textContent).toBe('cats');
      expect(resultsView.refs.listView.element.querySelector('.replacement')).toBeVisible();

      projectFindView.replaceEditor.setText('');
      advanceClock(modifiedDelay);

      expect(resultsView.refs.listView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.refs.listView.element.querySelector('.match')).toHaveClass('highlight-info');
      expect(resultsView.refs.listView.element.querySelector('.replacement')).toBeHidden();
    });

    it('renders the captured text when the replace pattern uses captures', async () => {
      projectFindView.refs.regexOptionButton.click();
      projectFindView.findEditor.setText('function ?(\\([^)]*\\))');
      projectFindView.replaceEditor.setText('$1 =>')
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      const listElement = resultsView.refs.listView.element;
      expect(listElement.querySelectorAll('.match')[0].textContent).toBe('function ()');
      expect(listElement.querySelectorAll('.replacement')[0].textContent).toBe('() =>');
      expect(listElement.querySelectorAll('.match')[1].textContent).toBe('function(items)');
      expect(listElement.querySelectorAll('.replacement')[1].textContent).toBe('(items) =>');
    })
  });

  describe("core:page-up and core:page-down", () => {
    beforeEach(async () => {
      workspaceElement.style.height = '300px';
      workspaceElement.style.width = '1024px';
      projectFindView.findEditor.setText(' ');
      projectFindView.confirm();

      await searchPromise;

      resultsView = getResultsView();
      const {listView} = resultsView.refs;
      expect(listView.element.scrollTop).toBe(0);
      expect(listView.element.scrollHeight).toBeGreaterThan(listView.element.offsetHeight);
    });

    function getSelectedItem() {
      return resultsView.refs.listView.element.querySelector('.selected');
    }

    function getRecursivePosition(element, substract_scroll) {
      let x = 0;
      let y = 0;
      while (element && !isNaN(element.offsetLeft) && !isNaN(element.offsetTop)) {
        x += element.offsetLeft;
        y += element.offsetTop;
        if (substract_scroll) {
          x -= element.scrollLeft;
          y -= element.scrollTop;
        }
        element = element.offsetParent;
      }
      return { top: y, left: x };
    }

    function getSelectedOffset() {
      return getRecursivePosition(getSelectedItem(), true).top;
    }

    function getSelectedPosition() {
      return getRecursivePosition(getSelectedItem(), false).top;
    }

    it("selects the first result on the next page when core:page-down is triggered", async () => {
      const {listView} = resultsView.refs;
      expect(listView.element.querySelectorAll('.path').length).not.toBeGreaterThan(resultsView.model.getPathCount());
      expect(listView.element.querySelectorAll('.match-line').length).not.toBeGreaterThan(resultsView.model.getMatchCount());
      expect(listView.element.querySelector('.match-line')).toHaveClass('selected');

      let initiallySelectedItem = getSelectedItem();
      let initiallySelectedOffset = getSelectedOffset();
      let initiallySelectedPosition = getSelectedPosition();

      await resultsView.pageDown();
      await etch.getScheduler().getNextUpdatePromise();

      expect(getSelectedItem()).not.toBe(initiallySelectedItem);
      expect(Math.abs(getSelectedOffset() - initiallySelectedOffset)).toBeLessThan(getSelectedItem().offsetHeight);
      expect(getSelectedPosition()).toBeGreaterThan(initiallySelectedPosition);

      initiallySelectedItem = getSelectedItem();
      initiallySelectedOffset = getSelectedOffset();
      initiallySelectedPosition = getSelectedPosition();

      await resultsView.pageDown();
      await etch.getScheduler().getNextUpdatePromise();

      expect(getSelectedItem()).not.toBe(initiallySelectedItem);
      expect(Math.abs(getSelectedOffset() - initiallySelectedOffset)).toBeLessThan(getSelectedItem().offsetHeight);
      expect(getSelectedPosition()).toBeGreaterThan(initiallySelectedPosition);

      initiallySelectedPosition = getSelectedPosition();

      for (let i = 0; i < 100; i++) await resultsView.pageDown();
      expect(_.last(resultsView.element.querySelectorAll('.match-line'))).toHaveClass('selected');
      expect(getSelectedPosition()).toBeGreaterThan(initiallySelectedPosition);
    });

    it("selects the first result on the previous page when core:page-up is triggered", async () => {
      await resultsView.moveToBottom();
      expect(_.last(resultsView.element.querySelectorAll('.match-line'))).toHaveClass('selected');

      const {listView} = resultsView.refs;

      let initiallySelectedItem = getSelectedItem();
      let initiallySelectedOffset = getSelectedOffset();
      let initiallySelectedPosition = getSelectedPosition();

      await resultsView.pageUp();

      expect(getSelectedItem()).not.toBe(initiallySelectedItem);
      expect(Math.abs(getSelectedOffset() - initiallySelectedOffset)).toBeLessThan(getSelectedItem().offsetHeight);
      expect(getSelectedPosition()).toBeLessThan(initiallySelectedPosition);

      initiallySelectedItem = getSelectedItem();
      initiallySelectedOffset = getSelectedOffset();
      initiallySelectedPosition = getSelectedPosition();

      await resultsView.pageUp();

      expect(getSelectedItem()).not.toBe(initiallySelectedItem);
      expect(Math.abs(getSelectedOffset() - initiallySelectedOffset)).toBeLessThan(getSelectedItem().offsetHeight);
      expect(getSelectedPosition()).toBeLessThan(initiallySelectedPosition);

      initiallySelectedPosition = getSelectedPosition();

      for (let i = 0; i < 100; i++) await resultsView.pageUp();
      expect(listView.element.querySelector('.path')).toHaveClass('selected');
      expect(getSelectedPosition()).toBeLessThan(initiallySelectedPosition);
    });
  });

  describe("core:move-to-top and core:move-to-bottom", () => {
    beforeEach(async () => {
      workspaceElement.style.height = '300px';
      projectFindView.findEditor.setText('so');
      projectFindView.confirm();
      await searchPromise;
      resultsView = getResultsView();
    });

    it("selects the first/last item when core:move-to-top/move-to-bottom is triggered", async () => {
      const {listView} = resultsView.refs;
      expect(listView.element.querySelectorAll('li').length).toBeLessThan(resultsView.model.getPathCount() + resultsView.model.getMatchCount());

      await resultsView.moveToBottom();
      expect(listView.element.querySelectorAll('li')[1]).not.toHaveClass('selected');
      expect(_.last(listView.element.querySelectorAll('li'))).toHaveClass('selected');
      expect(listView.element.scrollTop).not.toBe(0);

      await resultsView.moveToTop();
      expect(listView.element.querySelector('.match-line')).toHaveClass('selected');
      expect(listView.element.scrollTop).toBe(0);
    });

    it("selects the path when when core:move-to-bottom is triggered and last item is collapsed", async () => {
      await resultsView.moveToBottom();
      resultsView.collapseResult();
      await resultsView.moveToBottom();

      expect(_.last(resultsView.element.querySelectorAll('li')).closest('.path')).toHaveClass('selected');
    });

    it("selects the path when when core:move-to-top is triggered and first item is collapsed", async () => {
      await resultsView.moveToTop();
      atom.commands.dispatch(resultsView.element, 'core:move-left');
      await resultsView.moveToTop();

      expect(resultsView.refs.listView.element.querySelector('li').closest('.path')).toHaveClass('selected');
    });
  });

  describe("expanding and collapsing results", () => {
    it('preserves the selected file when collapsing all results', async () => {
      projectFindView.findEditor.setText('items');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();

      resultsView.moveDown();
      resultsView.moveDown();
      resultsView.moveDown();

      const selectedMatch = resultsView.element.querySelector('.selected');
      expect(selectedMatch).toHaveClass('match-line');

      resultsView.collapseAllResults();
      const selectedPath = resultsView.element.querySelector('.selected');
      expect(selectedPath).toHaveClass('path');
      expect(selectedPath.dataset.path).toContain('sample.coffee');

      // If the result is re-expanded without moving up or down, the original
      // selected match remains selected.
      resultsView.expandAllResults();
      const newSelectedMatch = resultsView.element.querySelector('.selected');
      expect(newSelectedMatch.innerHTML).toBe(selectedMatch.innerHTML);
      expect(selectedPath.contains(newSelectedMatch)).toBe(true);

      resultsView.collapseAllResults();
      resultsView.moveDown();
      resultsView.expandAllResults();

      // Moving down while the path is collapsed moves to the next path,
      // as opposed to selecting the next match within the collapsed path.
      const newSelectedPath = resultsView.element.querySelector('.selected');
      expect(newSelectedPath.dataset.path).toContain('sample.js');

      resultsView.moveDown();
      resultsView.moveDown();
      resultsView.moveDown();
      expect(resultsView.element.querySelector('.selected')).toHaveClass('match-line');

      // Moving up while the path is collapsed moves to the previous path,
      // as opposed to moving up to the next match within the collapsed path.
      resultsView.collapseAllResults();
      resultsView.moveUp();
      resultsView.expandAllResults();
      expect(resultsView.element.querySelector('.selected')).toBe(selectedPath);
    });

    it('re-expands all results when running a new search', async () => {
      projectFindView.findEditor.setText('items');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      resultsView.collapseResult();
      expect(resultsView.element.querySelector('.collapsed')).not.toBe(null);

      projectFindView.findEditor.setText('sort');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      expect(resultsView.element.querySelector('.collapsed')).toBe(null);
    })
  });

  describe("opening results", () => {
    beforeEach(async () => {
      await atom.workspace.open('sample.js');

      projectFindView.findEditor.setText('items');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      resultsView.selectFirstResult();
    });

    function paneItemOpening() {
      return new Promise(resolve => {
        const subscription = atom.workspace.onDidOpen(() => {
          resolve()
          subscription.dispose()
        })
      })
    }

    it("opens the file containing the result when 'core:confirm' is called", async () => {
      // open something in sample.coffee
      resultsView.element.focus();
      _.times(3, () => atom.commands.dispatch(resultsView.element, 'core:move-down'));
      atom.commands.dispatch(resultsView.element, 'core:confirm');
      await paneItemOpening()
      expect(atom.workspace.getCenter().getActivePaneItem().getPath()).toContain('sample.');

      // open something in sample.js
      resultsView.element.focus();
      _.times(6, () => atom.commands.dispatch(resultsView.element, 'core:move-down'));
      atom.commands.dispatch(resultsView.element, 'core:confirm');
      await paneItemOpening()
      expect(atom.workspace.getCenter().getActivePaneItem().getPath()).toContain('sample.');
    });

    it("opens the file containing the result in a non-pending state when the search result is double-clicked", async () => {
      const pathNode = resultsView.refs.listView.element.querySelectorAll(".search-result")[0];
      const click1 = buildMouseEvent('mousedown', {target: pathNode, detail: 1});
      const click2 = buildMouseEvent('mousedown', {target: pathNode, detail: 2});
      pathNode.dispatchEvent(click1);
      pathNode.dispatchEvent(click2);

      // Otherwise, the double click will transfer focus back to the results view
      expect(click2.defaultPrevented).toBe(true);

      await paneItemOpening()
      const editor = atom.workspace.getCenter().getActiveTextEditor();
      expect(atom.workspace.getCenter().getActivePane().getPendingItem()).toBe(null);
      expect(atom.views.getView(editor)).toHaveFocus();
    });

    it("opens the file containing the result in a pending state when the search result is single-clicked", async () => {
      const pathNode = resultsView.refs.listView.element.querySelectorAll(".search-result")[0];
      pathNode.dispatchEvent(buildMouseEvent('mousedown', {target: pathNode, which: 1}));
      await paneItemOpening()
      const editor = atom.workspace.getCenter().getActiveTextEditor();
      expect(atom.workspace.getCenter().getActivePane().getPendingItem()).toBe(editor);
      expect(atom.views.getView(editor)).toHaveFocus();
    })

    describe("the `projectSearchResultsPaneSplitDirection` option", () => {
      beforeEach(() => {
        spyOn(atom.workspace, 'open').andCallThrough()
      });

      it("does not create a split when the option is 'none'", async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'none');
        atom.commands.dispatch(resultsView.element, 'core:move-down');
        atom.commands.dispatch(resultsView.element, 'core:confirm');
        await paneItemOpening()
        expect(atom.workspace.open.mostRecentCall.args[1].split).toBeUndefined();
      });

      it("always opens the file in the left pane when the option is 'right'", async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'right');
        atom.commands.dispatch(resultsView.element, 'core:move-down');
        atom.commands.dispatch(resultsView.element, 'core:confirm');
        await paneItemOpening()
        expect(atom.workspace.open.mostRecentCall.args[1].split).toBe('left');
      });

      it("always opens the file in the pane above when the options is 'down'", async () => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'down')
        atom.commands.dispatch(resultsView.element, 'core:move-down');
        atom.commands.dispatch(resultsView.element, 'core:confirm');
        await paneItemOpening()
        expect(atom.workspace.open.mostRecentCall.args[1].split).toBe('up');
      });
    });
  });

  describe("arrowing through the list", () => {
    it("arrows through the entire list without selecting paths and overshooting the boundaries", async () => {
      await atom.workspace.open('sample.js');

      projectFindView.findEditor.setText('items');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();

      let {length: resultCount} = resultsView.refs.listView.element.querySelectorAll(".search-result");
      expect(resultCount).toBe(13);

      resultsView.selectFirstResult();

      // moves down for 13 results + 2 files
      _.times(resultCount + 1, () => atom.commands.dispatch(resultsView.element, 'core:move-down'));
      let selectedItem = resultsView.element.querySelector('.selected');
      expect(selectedItem).toHaveClass('match-line');

      // stays at the bottom
      let lastSelectedItem = selectedItem;
      _.times(2, () => atom.commands.dispatch(resultsView.element, 'core:move-down'));
      selectedItem = resultsView.element.querySelector('.selected');
      expect(selectedItem).toBe(lastSelectedItem);

      // moves up to the top
      lastSelectedItem = selectedItem;
      _.times(resultCount + 1, () => atom.commands.dispatch(resultsView.element, 'core:move-up'));
      selectedItem = resultsView.element.querySelector('.selected');
      expect(selectedItem).toHaveClass('path');
      expect(selectedItem).not.toBe(lastSelectedItem);

      // stays at the top
      lastSelectedItem = selectedItem;
      _.times(2, () => atom.commands.dispatch(resultsView.element, 'core:move-up'));
      selectedItem = resultsView.element.querySelector('.selected');
      expect(selectedItem).toBe(lastSelectedItem);
    });

    describe("when there are a list of items", () => {
      beforeEach(async () => {
        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;
        resultsView = getResultsView();
      });

      it("shows the preview-controls", () => {
        expect(getResultsPane().refs.previewControls).toBeVisible();
        expect(getResultsPane().refs.previewControls.style).not.toBe('hidden');
      });

      it("collapses the selected results view", () => {
        clickOn(resultsView.refs.listView.element.querySelector('.search-result'));

        atom.commands.dispatch(resultsView.element, 'core:move-left');

        let selectedItem = resultsView.element.querySelector('.selected');
        expect(selectedItem).toHaveClass('collapsed');
        expect(selectedItem).toBe(resultsView.refs.listView.element.querySelector('.path'));
      });

      it("collapses all results if collapse All button is pressed", () => {
        clickOn(getResultsPane().refs.collapseAll);
        for (let item of Array.from(resultsView.element.querySelector('.list-nested-item'))) {
          expect(item).toHaveClass('collapsed');
        }
      });

      it("expands the selected results view", () => {
        clickOn(resultsView.refs.listView.element.querySelector('.path'));

        atom.commands.dispatch(resultsView.element, 'core:move-right');

        let selectedItem = resultsView.element.querySelector('.selected');
        expect(selectedItem).toHaveClass('match-line');
        expect(selectedItem).toBe(resultsView.refs.listView.element.querySelector('.match-line'));
      });

      it("expands all results if 'Expand All' button is pressed", () => {
        clickOn(getResultsPane().refs.expandAll);
        for (let item of Array.from(resultsView.element.querySelector('.list-nested-item'))) {
          expect(item).not.toHaveClass('collapsed');
        }
      });

      describe("when there are collapsed results", () => {
        it("moves to the correct next result when a path is selected", () => {
          clickOn(resultsView.element.querySelectorAll('.path')[1]);
          clickOn(resultsView.element.querySelectorAll('.path')[0].querySelector('.search-result:last-child'));

          atom.commands.dispatch(resultsView.element, 'core:move-down');

          let selectedItem = resultsView.element.querySelector('.selected');
          expect(selectedItem).toHaveClass('path');
          expect(selectedItem).toBe(resultsView.element.querySelectorAll('.path')[1]);
        });

        it("moves to the correct previous result when a path is selected", () => {
          clickOn(resultsView.element.querySelectorAll('.path')[0]);
          clickOn(resultsView.element.querySelectorAll('.path')[1].querySelector('.search-result'));

          atom.commands.dispatch(resultsView.element, 'core:move-up');
          expect(resultsView.element.querySelectorAll('.path')[1]).toHaveClass('selected');

          atom.commands.dispatch(resultsView.element, 'core:move-up');
          expect(resultsView.refs.listView.element.querySelectorAll('.path')[0]).toHaveClass('selected');
        });
      });
    });
  });

  describe("when the results view is empty", () => {
    it("ignores core:confirm and other commands for selecting results", async () => {
      projectFindView.findEditor.setText('thiswillnotmatchanythingintheproject');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;
      resultsView = getResultsView();
      atom.commands.dispatch(resultsView.element, 'core:confirm');
      atom.commands.dispatch(resultsView.element, 'core:move-down');
      atom.commands.dispatch(resultsView.element, 'core:move-up');
      atom.commands.dispatch(resultsView.element, 'core:move-to-top');
      atom.commands.dispatch(resultsView.element, 'core:move-to-bottom');
      atom.commands.dispatch(resultsView.element, 'core:page-down');
      atom.commands.dispatch(resultsView.element, 'core:page-up');
    });

    it("won't show the preview-controls", async () => {
      projectFindView.findEditor.setText('thiswillnotmatchanythingintheproject');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;
      expect(getResultsPane().refs.previewControls.style.visibility).toBe('hidden');
    });
  });

  describe("copying items with core:copy", () => {
    it("copies the selected line onto the clipboard", async () => {
      await atom.workspace.open('sample.js');

      projectFindView.findEditor.setText('items');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      resultsView.selectFirstResult();

      _.times(2, () => atom.commands.dispatch(resultsView.element, 'core:move-down'));
      atom.commands.dispatch(resultsView.element, 'core:copy');
      expect(atom.clipboard.read()).toBe('    return items if items.length <= 1');
    });
  });

  describe("copying path with find-and-replace:copy-path", () => {
    it("copies the selected file path to clipboard", async () => {
      projectFindView.findEditor.setText('items');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      resultsView.selectFirstResult();
      resultsView.collapseResult();

      atom.commands.dispatch(resultsView.element, 'find-and-replace:copy-path');
      expect(atom.clipboard.read()).toBe('sample.coffee');
      atom.commands.dispatch(resultsView.element, 'core:move-down');
      atom.commands.dispatch(resultsView.element, 'find-and-replace:copy-path');
      expect(atom.clipboard.read()).toBe('sample.js');
    });

    it("copies the selected file path to the clipboard when there are multiple project folders", async () => {
        const folder1 = temp.mkdirSync('folder-1')
        const file1 = path.join(folder1, 'sample.txt')
        fs.writeFileSync(file1, 'items')

        const folder2 = temp.mkdirSync('folder-2')
        const file2 = path.join(folder2, 'sample.txt')
        fs.writeFileSync(file2, 'items')

        atom.project.setPaths([folder1, folder2]);
        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        resultsView = getResultsView();
        resultsView.selectFirstResult();
        resultsView.collapseResult();
        atom.commands.dispatch(resultsView.element, 'find-and-replace:copy-path');
        expect(atom.clipboard.read()).toBe(path.join(path.basename(folder1), path.basename(file1)));
        atom.commands.dispatch(resultsView.element, 'core:move-down');
        atom.commands.dispatch(resultsView.element, 'find-and-replace:copy-path');
        expect(atom.clipboard.read()).toBe(path.join(path.basename(folder2), path.basename(file2)));
    });
  });

  describe("preview font", () => {
    it('respects the editor.fontFamily setting', async () => {
      atom.config.set('editor.fontFamily', 'Courier');

      projectFindView.findEditor.setText('items');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      const previewElement = resultsView.element.querySelector('.match-line .preview');
      expect(previewElement.style.fontFamily).toBe('Courier');

      atom.config.set('editor.fontFamily', 'Helvetica');
      expect(previewElement.style.fontFamily).toBe('Helvetica');
    })
  });

  describe('icon services', () => {
    describe('atom.file-icons', () => {
      it('has a default handler', () => {
        expect(getIconServices().fileIcons).toBe(DefaultFileIcons)
      })

      it('displays icons for common filetypes', () => {
        expect(DefaultFileIcons.iconClassForPath('README.md')).toBe('icon-book')
        expect(DefaultFileIcons.iconClassForPath('zip.zip')).toBe('icon-file-zip')
        expect(DefaultFileIcons.iconClassForPath('a.gif')).toBe('icon-file-media')
        expect(DefaultFileIcons.iconClassForPath('a.pdf')).toBe('icon-file-pdf')
        expect(DefaultFileIcons.iconClassForPath('an.exe')).toBe('icon-file-binary')
        expect(DefaultFileIcons.iconClassForPath('jg.js')).toBe('icon-file-text')
      })

      it('allows a service provider to change the handler', async () => {
        const provider = {
          iconClassForPath(path, context) {
            expect(context).toBe('find-and-replace')
            return (path.endsWith('one-long-line.coffee'))
              ? 'first-icon-class second-icon-class'
              : ['third-icon-class', 'fourth-icon-class']
          }
        }
        const disposable = atom.packages.serviceHub.provide('atom.file-icons', '1.0.0', provider);
        expect(getIconServices().fileIcons).toBe(provider)

        projectFindView.findEditor.setText('i');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;

        resultsView = getResultsView();
        let fileIconClasses = Array.from(resultsView.element.querySelectorAll('.path-details .icon')).map(el => el.className);
        expect(fileIconClasses).toContain('first-icon-class second-icon-class icon');
        expect(fileIconClasses).toContain('third-icon-class fourth-icon-class icon');
        expect(fileIconClasses).not.toContain('icon-file-text icon');

        disposable.dispose();
        projectFindView.findEditor.setText('e');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');

        await searchPromise;
        resultsView = getResultsView();
        fileIconClasses = Array.from(resultsView.element.querySelectorAll('.path-details .icon')).map(el => el.className);
        expect(fileIconClasses).not.toContain('first-icon-class second-icon-class icon');
        expect(fileIconClasses).not.toContain('third-icon-class fourth-icon-class icon');
        expect(fileIconClasses).toContain('icon-file-text icon');
      })
    })

    describe('file-icons.element-icons', () => {
      beforeEach(() => jasmine.useRealClock())

      it('has no default handler', () => {
        expect(getIconServices().elementIcons).toBe(null)
      })

      it('uses the element-icon service if available', () => {
        const iconSelector = '.path-details .icon:not([data-name="fake-file-path"])'
        const provider = (element, path) => {
          expect(element).toBeInstanceOf(HTMLElement)
          expect(typeof path === "string").toBe(true)
          expect(path.length).toBeGreaterThan(0)
          const classes = path.endsWith('one-long-line.coffee')
            ? ['foo', 'bar']
            : ['baz', 'qlux']
          element.classList.add(...classes)
          return new Disposable(() => {
            element.classList.remove(...classes)
          })
        }
        let disposable
        
        waitsForPromise(() => {
          disposable = atom.packages.serviceHub.provide('file-icons.element-icons', '1.0.0', provider)
          expect(getIconServices().elementIcons).toBe(provider)
          projectFindView.findEditor.setText('i');
          atom.commands.dispatch(projectFindView.element, 'core:confirm');
          return searchPromise
        })

        waitsForPromise(() => delayFor(35))

        runs(() => {
          resultsView = getResultsView()
          const iconElements = resultsView.element.querySelectorAll(iconSelector)
          expect(iconElements[0].className.trim()).toBe('icon foo bar')
          expect(iconElements[1].className.trim()).toBe('icon baz qlux')
          expect(resultsView.element.querySelector('.icon-file-text')).toBe(null)

          disposable.dispose()
          projectFindView.findEditor.setText('e')
          atom.commands.dispatch(projectFindView.element, 'core:confirm')
        })

        waitsForPromise(() => searchPromise)

        waitsForPromise(() => delayFor(35))

        runs(() => {
          resultsView = getResultsView()
          const iconElements = resultsView.element.querySelectorAll(iconSelector)
          expect(iconElements[0].className.trim()).toBe('icon-file-text icon')
          expect(iconElements[1].className.trim()).toBe('icon-file-text icon')
          expect(resultsView.element.querySelector('.foo, .bar, .baz, .qlux')).toBe(null)
        })
      })
    })
  })

  describe('updating the search while viewing results', () => {
    it('resets the results message', async () => {
      projectFindView.findEditor.setText('a');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsPane = getResultsPane();
      expect(resultsPane.refs.previewCount.textContent).toContain('3 files');

      projectFindView.findEditor.setText('');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      expect(resultsPane.refs.previewCount.textContent).toContain('Project search results');
    })
  });

  describe('search result context lines', () => {
    beforeEach(async () => {
      atom.config.set('find-and-replace.searchContextLineCountBefore', 2);
      atom.config.set('find-and-replace.searchContextLineCountAfter', 3);
      atom.config.set('find-and-replace.leadingContextLineCount', 0);
      atom.config.set('find-and-replace.trailingContextLineCount', 0);

      projectFindView.findEditor.setText('items');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
    });

    function getLineNodesMatchFirstPath(resultsView, matchIndex) {
      const pathNodes = resultsView.refs.listView.element.querySelectorAll('.path');
      expect(pathNodes.length).not.toBeLessThan(1);
      const pathNameNode = pathNodes[0].querySelector('.path-name');
      expect(pathNameNode.textContent).toBe('sample.coffee');
      // the second file is sample.js which we don't use
      expect(pathNodes.length).not.toBeLessThan(matchIndex + 1);
      const resultNode = pathNodes[matchIndex].querySelector('.search-result');
      return resultNode.querySelectorAll('.list-item');
    }

    it('shows the context lines', async () => {
      // show no context lines
      expect(resultsView.model.getFindOptions().leadingContextLineCount).toBe(0);
      expect(resultsView.model.getFindOptions().trailingContextLineCount).toBe(0);
      {
        const lineNodes = getLineNodesMatchFirstPath(resultsView, 0);
        expect(lineNodes.length).toBe(1);
        expect(lineNodes[0]).toHaveClass('match-line');
        expect(lineNodes[0].querySelector('.preview').textContent).toBe('  sort: (items) ->');
      }

      // show all leading context lines, show 1 trailing context line
      await resultsView.toggleLeadingContextLines();
      await resultsView.incrementTrailingContextLines();
      expect(resultsView.model.getFindOptions().leadingContextLineCount).toBe(2);
      expect(resultsView.model.getFindOptions().trailingContextLineCount).toBe(1);

      {
        const lineNodes = getLineNodesMatchFirstPath(resultsView, 0);
        expect(lineNodes.length).toBe(3);
        expect(lineNodes[0]).not.toHaveClass('match-line');
        expect(lineNodes[0].querySelector('.preview').textContent).toBe('class quicksort');
        expect(lineNodes[1]).toHaveClass('match-line');
        expect(lineNodes[1].querySelector('.preview').textContent).toBe('  sort: (items) ->');
        expect(lineNodes[2]).not.toHaveClass('match-line');
        expect(lineNodes[2].querySelector('.preview').textContent).toBe('    return items if items.length <= 1');
      }

      // show 1 leading context line, show 2 trailing context lines
      await resultsView.decrementLeadingContextLines();
      await resultsView.incrementTrailingContextLines();
      expect(resultsView.model.getFindOptions().leadingContextLineCount).toBe(1);
      expect(resultsView.model.getFindOptions().trailingContextLineCount).toBe(2);

      {
        const lineNodes = getLineNodesMatchFirstPath(resultsView, 0);
        expect(lineNodes.length).toBe(4);
        expect(lineNodes[0]).not.toHaveClass('match-line');
        expect(lineNodes[0].querySelector('.preview').textContent).toBe('class quicksort');
        expect(lineNodes[1]).toHaveClass('match-line');
        expect(lineNodes[1].querySelector('.preview').textContent).toBe('  sort: (items) ->');
        expect(lineNodes[2]).not.toHaveClass('match-line');
        expect(lineNodes[2].querySelector('.preview').textContent).toBe('    return items if items.length <= 1');
        expect(lineNodes[3]).not.toHaveClass('match-line');
        expect(lineNodes[3].querySelector('.preview').textContent).toBe('');
      }

      // show no leading context lines, show 3 trailing context lines
      await resultsView.decrementLeadingContextLines();
      await resultsView.incrementTrailingContextLines();
      expect(resultsView.model.getFindOptions().leadingContextLineCount).toBe(0);
      expect(resultsView.model.getFindOptions().trailingContextLineCount).toBe(3);

      {
        const lineNodes = getLineNodesMatchFirstPath(resultsView, 0);
        expect(lineNodes.length).toBe(4);
        expect(lineNodes[0]).toHaveClass('match-line');
        expect(lineNodes[0].querySelector('.preview').textContent).toBe('  sort: (items) ->');
        expect(lineNodes[1]).not.toHaveClass('match-line');
        expect(lineNodes[1].querySelector('.preview').textContent).toBe('    return items if items.length <= 1');
        expect(lineNodes[2]).not.toHaveClass('match-line');
        expect(lineNodes[2].querySelector('.preview').textContent).toBe('');
        expect(lineNodes[3]).not.toHaveClass('match-line');
        expect(lineNodes[3].querySelector('.preview').textContent).toBe('    pivot = items.shift()');
      }

      // show 1 leading context line, show 2 trailing context lines
      await resultsView.incrementLeadingContextLines();
      await resultsView.decrementTrailingContextLines();
      expect(resultsView.model.getFindOptions().leadingContextLineCount).toBe(1);
      expect(resultsView.model.getFindOptions().trailingContextLineCount).toBe(2);

      {
        const lineNodes = getLineNodesMatchFirstPath(resultsView, 0);
        expect(lineNodes.length).toBe(4);
        expect(lineNodes[0]).not.toHaveClass('match-line');
        expect(lineNodes[0].querySelector('.preview').textContent).toBe('class quicksort');
        expect(lineNodes[1]).toHaveClass('match-line');
        expect(lineNodes[1].querySelector('.preview').textContent).toBe('  sort: (items) ->');
        expect(lineNodes[2]).not.toHaveClass('match-line');
        expect(lineNodes[2].querySelector('.preview').textContent).toBe('    return items if items.length <= 1');
        expect(lineNodes[3]).not.toHaveClass('match-line');
        expect(lineNodes[3].querySelector('.preview').textContent).toBe('');
      }

      // show 1 leading context line, show 2 trailing context lines
      await resultsView.incrementTrailingContextLines();
      expect(resultsView.model.getFindOptions().trailingContextLineCount).toBe(3);
      await resultsView.incrementLeadingContextLines();
      await resultsView.toggleTrailingContextLines();
      expect(resultsView.model.getFindOptions().leadingContextLineCount).toBe(2);
      expect(resultsView.model.getFindOptions().trailingContextLineCount).toBe(0);

      {
        const lineNodes = getLineNodesMatchFirstPath(resultsView, 0);
        expect(lineNodes.length).toBe(2);
        expect(lineNodes[0]).not.toHaveClass('match-line');
        expect(lineNodes[0].querySelector('.preview').textContent).toBe('class quicksort');
        expect(lineNodes[1]).toHaveClass('match-line');
        expect(lineNodes[1].querySelector('.preview').textContent).toBe('  sort: (items) ->');
      }
    });
  });

  describe('selected result and match index', () => {
    beforeEach(async () => {
      projectFindView.findEditor.setText('push');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
    });

    it('maintains selected result when adding and removing results', async () => {
      {
        const matchLines = resultsView.refs.listView.element.querySelectorAll('.match-line');
        expect(matchLines.length).toBe(4);

        resultsView.moveDown();
        resultsView.moveDown();
        resultsView.moveDown();
        resultsView.moveDown();
        expect(matchLines[3]).toHaveClass('selected');
        expect(matchLines[3].querySelector('.preview').textContent).toBe('      current < pivot ? left.push(current) : right.push(current);');
        expect(resultsView.selectedResultIndex).toBe(1);
        expect(resultsView.selectedMatchIndex).toBe(1);
      }

      // remove the first result
      const firstPath = resultsView.model.getPaths()[0];
      const firstResult = resultsView.model.getResult(firstPath);
      resultsView.model.removeResult(firstPath);

      // check that the same match is still selected
      {
        const matchLines = resultsView.refs.listView.element.querySelectorAll('.match-line');
        expect(matchLines.length).toBe(2);
        expect(matchLines[1]).toHaveClass('selected');
        expect(matchLines[1].querySelector('.preview').textContent).toBe('      current < pivot ? left.push(current) : right.push(current);');
        expect(resultsView.selectedResultIndex).toBe(0);
        expect(resultsView.selectedMatchIndex).toBe(1);

      }

      // re-add the first result
      resultsView.model.addResult(firstPath, firstResult);

      // check that the same match is still selected
      {
        const matchLines = resultsView.refs.listView.element.querySelectorAll('.match-line');
        expect(matchLines.length).toBe(4);
        expect(matchLines[3]).toHaveClass('selected');
        expect(matchLines[3].querySelector('.preview').textContent).toBe('      current < pivot ? left.push(current) : right.push(current);');
        expect(resultsView.selectedResultIndex).toBe(1);
        expect(resultsView.selectedMatchIndex).toBe(1);
      }
    });
  })
});

function buildMouseEvent(type, properties) {
  properties = _.extend({bubbles: true, cancelable: true, detail: 1}, properties);
  const event = new MouseEvent(type, properties);
  if (properties.which) {
    Object.defineProperty(event, 'which', {get() { return properties.which; }});
  }
  if (properties.target) {
    Object.defineProperty(event, 'target', {get() { return properties.target; }});
    Object.defineProperty(event, 'srcObject', {get() { return properties.target; }});
  }
  return event;
}

function clickOn(element) {
  element.dispatchEvent(buildMouseEvent('mousedown', { detail: 1 }));
}

function delayFor(ms) {
  return new Promise(done => {
    setTimeout(() => done(), ms)
  })
}
