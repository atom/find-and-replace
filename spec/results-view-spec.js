/** @babel */

const _ = require('underscore-plus');
const path = require('path');
const temp = require("temp");
const etch = require('etch');
const ResultsPaneView = require('../lib/project/results-pane');
const FileIcons = require('../lib/file-icons');
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

    function getSelectedPosition() {
      return getSelectedItem().offsetTop;
    }

    function toNearest(n, multiple) {
      return Math.round(n / multiple) * multiple;
    }

    it("selects the first result on the next page when core:page-down is triggered", async () => {
      const {listView} = resultsView.refs;
      const pageHeight = listView.element.clientHeight;
      expect(listView.element.querySelectorAll('li').length).toBeLessThan(resultsView.model.getPathCount() + resultsView.model.getMatchCount());

      let initiallySelectedPosition = getSelectedPosition();
      await resultsView.pageDown();
      await etch.getScheduler().getNextUpdatePromise()
      expect(listView.element.scrollTop).toBe(pageHeight);
      expect(getSelectedPosition()).toBeGreaterThan(initiallySelectedPosition);

      initiallySelectedPosition = getSelectedPosition();
      await resultsView.pageDown();
      await etch.getScheduler().getNextUpdatePromise()
      expect(listView.element.scrollTop).toBe(pageHeight * 2);
      expect(getSelectedPosition()).toBeGreaterThan(initiallySelectedPosition);

      for (let i = 0; i < 100; i++) await resultsView.pageDown();
      expect(_.last(resultsView.element.querySelectorAll('.search-result'))).toHaveClass('selected');
    });

    it("selects the first result on the previous page when core:page-up is triggered", async () => {
      await resultsView.moveToBottom();

      const itemHeight = resultsView.element.querySelector('.selected').offsetHeight;
      const {listView} = resultsView.refs;
      const pageHeight = listView.element.clientHeight;
      const initialScrollTop = listView.element.scrollTop;
      const initiallySelectedPosition = getSelectedPosition();

      await resultsView.pageUp();
      expect(getSelectedPosition()).toBeWithin(initiallySelectedPosition - pageHeight, 20);
      expect(listView.element.scrollTop).toBeWithin(initialScrollTop - pageHeight, 20);

      await resultsView.pageUp();
      expect(getSelectedPosition()).toBeWithin(initiallySelectedPosition - pageHeight * 2, 20);
      expect(listView.element.scrollTop).toBeWithin(initialScrollTop - pageHeight * 2, 20);

      for (let i = 0; i < 100; i++) await resultsView.pageUp();
      expect(listView.element.querySelector('.path')).toHaveClass('selected');
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
        expect(listView.element.querySelectorAll('li')[1]).toHaveClass('selected');
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
      expect(selectedMatch).toHaveClass('search-result');

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
      expect(resultsView.element.querySelector('.selected')).toHaveClass('search-result');

      // Moving up while the path is collapsed moves to the previous path,
      // as opposed to moving up to the next match within the collapsed path.
      resultsView.collapseAllResults();
      resultsView.moveUp();
      resultsView.expandAllResults();
      expect(resultsView.element.querySelector('.selected')).toBe(selectedPath);
    });
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
      expect(atom.workspace.getActivePaneItem().getPath()).toContain('sample.');

      // open something in sample.js
      resultsView.element.focus();
      _.times(6, () => atom.commands.dispatch(resultsView.element, 'core:move-down'));
      atom.commands.dispatch(resultsView.element, 'core:confirm');
      await paneItemOpening()
      expect(atom.workspace.getActivePaneItem().getPath()).toContain('sample.');
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
      const editor = atom.workspace.getActiveTextEditor();
      expect(atom.workspace.getActivePane().getPendingItem()).toBe(null);
      expect(atom.views.getView(editor)).toHaveFocus();
    });

    it("opens the file containing the result in a pending state when the search result is single-clicked", async () => {
      const pathNode = resultsView.refs.listView.element.querySelectorAll(".search-result")[0];
      pathNode.dispatchEvent(buildMouseEvent('mousedown', {target: pathNode, which: 1}));
      await paneItemOpening()
      const editor = atom.workspace.getActiveTextEditor();
      expect(atom.workspace.getActivePane().getPendingItem()).toBe(editor);
      expect(atom.views.getView(editor)).toHaveFocus();
    })

    describe("when `projectSearchResultsPaneSplitDirection` option is none", () => {
      beforeEach(() => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'none');
      });

      it("does not specify a pane to split", () => {
        spyOn(atom.workspace, 'open').andCallThrough();
        atom.commands.dispatch(resultsView.element, 'core:move-down');
        atom.commands.dispatch(resultsView.element, 'core:confirm');
        expect(atom.workspace.open.mostRecentCall.args[1].split).toBeUndefined();
      });
    });

    describe("when `projectSearchResultsPaneSplitDirection` option is right", () => {
      beforeEach(() => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'right');
      });

      it("always opens the file in the left pane", () => {
        spyOn(atom.workspace, 'open').andCallThrough();
        atom.commands.dispatch(resultsView.element, 'core:move-down');
        atom.commands.dispatch(resultsView.element, 'core:confirm');
        expect(atom.workspace.open.mostRecentCall.args[1].split).toBe('left');
      });
    });

    describe("when `projectSearchResultsPaneSplitDirection` option is down", () => {
      beforeEach(() => {
        atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'down')
      });

      it("always opens the file in the up pane", () => {
        spyOn(atom.workspace, 'open').andCallThrough();
        atom.commands.dispatch(resultsView.element, 'core:move-down');
        atom.commands.dispatch(resultsView.element, 'core:confirm');
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
      expect(selectedItem).toHaveClass('search-result');

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
        expect(selectedItem).toHaveClass('search-result');
        expect(selectedItem).toBe(resultsView.refs.listView.element.querySelector('.search-result'));
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
    it("ignores core:confirm events", async () => {
      projectFindView.findEditor.setText('thiswillnotmatchanythingintheproject');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;
      resultsView = getResultsView();
      atom.commands.dispatch(resultsView.element, 'core:confirm');
    });

    it("won't show the preview-controls", async () => {
      projectFindView.findEditor.setText('thiswillnotmatchanythingintheproject');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;
      expect(getResultsPane().refs.previewControls).not.toBeVisible();
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
  });

  describe("preview font", () => {
    it('respects the editor.fontFamily setting', async () => {
      atom.config.set('editor.fontFamily', 'Courier');

      projectFindView.findEditor.setText('items');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      const previewElement = resultsView.element.querySelector('.search-result .preview');
      expect(previewElement.style.fontFamily).toBe('Courier');

      atom.config.set('editor.fontFamily', 'Helvetica');
      expect(previewElement.style.fontFamily).toBe('Helvetica');
    })
  });

  describe("icon-service lifecycle", () => {
    it('renders file icon classes based on the provided file-icons service', async () => {
      const fileIconsDisposable = atom.packages.serviceHub.provide('atom.file-icons', '1.0.0', {
        iconClassForPath(path, context) {
          expect(context).toBe("find-and-replace");
          if (path.endsWith('one-long-line.coffee')) {
            return "first-icon-class second-icon-class";
          } else {
            return ['third-icon-class', 'fourth-icon-class'];
          }
        }
      });

      projectFindView.findEditor.setText('i');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      let fileIconClasses = Array.from(resultsView.element.querySelectorAll('.path-details .icon')).map(el => el.className);
      expect(fileIconClasses).toContain('first-icon-class second-icon-class icon');
      expect(fileIconClasses).toContain('third-icon-class fourth-icon-class icon');
      expect(fileIconClasses).not.toContain('icon-file-text icon');

      fileIconsDisposable.dispose();
      projectFindView.findEditor.setText('e');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');

      await searchPromise;
      resultsView = getResultsView();
      fileIconClasses = Array.from(resultsView.element.querySelectorAll('.path-details .icon')).map(el => el.className);
      expect(fileIconClasses).not.toContain('first-icon-class second-icon-class icon');
      expect(fileIconClasses).not.toContain('third-icon-class fourth-icon-class icon');
      expect(fileIconClasses).toContain('icon-file-text icon');
    })
  });

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
