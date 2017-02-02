/** @babel */

const _ = require('underscore-plus');
const path = require('path');
const temp = require("temp");
const etch = require('etch');
const ResultsPaneView = require('../lib/project/results-pane');
const FileIcons = require('../lib/file-icons');
const {beforeEach, it, fit, ffit, fffit} = require('./async-spec-helpers')

describe('ResultsView', () => {
  let projectFindView, resultsView, searchPromise, workspaceElement;

  function getExistingResultsPane() {
    let pane = atom.workspace.paneForURI(ResultsPaneView.URI);
    if (pane) return pane.itemForURI(ResultsPaneView.URI);
  }

  function getResultsView() {
    return getExistingResultsPane().refs.resultsView;
  }

  beforeEach(async () => {
    etch.setScheduler({
      updateDocument(callback) {
        callback();
      },

      async getNextUpdatePromise() {}
    });

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

  describe("result sorting", () => {
    beforeEach(async () => {
      projectFindView.findEditor.setText('i');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;
      resultsView = getResultsView();
    });

    describe("when shouldRenderMoreResults is true", () => {
      beforeEach(() => {
        spyOn(resultsView, 'shouldRenderMoreResults').andReturn(true)
      });

      it("displays the results in sorted order", () => {
        let match = {
          range: [[0, 0], [0, 3]],
          lineText: 'abcdef',
          lineTextOffset: 0,
          matchText: 'abc'
        };

        let pathNames = (Array.from(resultsView.element.querySelectorAll(".path-name")).map((el) => el.textContent));
        expect(pathNames).toHaveLength(3);
        expect(pathNames[0]).toContain('one-long-line.coffee');
        expect(pathNames[1]).toContain('sample.coffee');
        expect(pathNames[2]).toContain('sample.js');

        expect(resultsView.element.querySelector('.search-result')).toHaveClass('selected');

        // at the beginning
        let firstResult = path.resolve('/a');
        projectFindView.model.addResult(firstResult, {matches: [match]});
        expect(resultsView.element.querySelectorAll(".path-name")[0].textContent).toContain(firstResult);
        expect(resultsView.element.querySelector('.search-result')).toHaveClass('selected');

        // at the end
        let lastResult = path.resolve('/z');
        projectFindView.model.addResult(lastResult, {matches: [match]});
        expect(resultsView.element.querySelectorAll(".path-name")[4].textContent).toContain(lastResult);
        expect(resultsView.element.querySelector('.search-result')).toHaveClass('selected');

        // 2nd to last
        let almostLastResult = path.resolve('/x');
        projectFindView.model.addResult(almostLastResult, {matches: [match]});
        expect(resultsView.element.querySelectorAll(".path-name")[4].textContent).toContain(almostLastResult);
        expect(resultsView.element.querySelector('.search-result')).toHaveClass('selected');
      });
    });

    describe("when shouldRenderMoreResults is false", () => {
      beforeEach(() => {
        spyOn(resultsView, 'shouldRenderMoreResults').andReturn(false)
      });

      it("only renders new items within the currently displayed results", () => {
        let dirname = path.dirname(projectFindView.model.getPaths()[0]);
        let pathNames = (Array.from(resultsView.element.querySelectorAll(".path-name")).map((el) => el.textContent));
        expect(pathNames).toHaveLength(3);
        expect(pathNames[0]).toContain('one-long-line.coffee');
        expect(pathNames[1]).toContain('sample.coffee');
        expect(pathNames[2]).toContain('sample.js');

        // nope, not at the end
        projectFindView.model.addResult(path.resolve('/z'), {matches: []});
        expect(resultsView.element.querySelectorAll(".path-name")).toHaveLength(3);

        // yes, at the beginning
        let firstResult = path.resolve('/a');
        projectFindView.model.addResult(firstResult, {matches: []});
        expect(resultsView.element.querySelectorAll(".path-name")).toHaveLength(4);
        expect(resultsView.element.querySelectorAll(".path-name")[0].textContent).toContain(firstResult);

        // yes, in the middle
        projectFindView.model.addResult(path.resolve(`${dirname}/ppppp`), {matches: []});
        expect(resultsView.element.querySelectorAll(".path-name")).toHaveLength(5);
        expect(resultsView.element.querySelectorAll(".path-name")[2].textContent).toContain('ppppp');
      });
    });
  });

  describe("when the result is for a long line", () =>
    it("renders the context around the match", async () => {
      projectFindView.findEditor.setText('ghijkl');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.element.querySelector('.path-name').textContent).toBe("one-long-line.coffee");
      expect(resultsView.element.querySelectorAll('.preview').length).toBe(1);
      expect(resultsView.element.querySelector('.preview').textContent).toBe('test test test test test test test test test test test a b c d e f g h i j k l abcdefghijklmnopqrstuvwxyz');
      expect(resultsView.element.querySelector('.match').textContent).toBe('ghijkl');
    })
  );

  describe("when there are multiple project paths", () => {
    beforeEach(() => {
      atom.project.addPath(temp.mkdirSync("another-project-path"))
    });

    it("includes the basename of the project path that contains the match", async () => {
      projectFindView.findEditor.setText('ghijkl');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.element.querySelector('.path-name').textContent).toBe(path.join("fixtures", "one-long-line.coffee"));
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
      expect(resultsView.element.querySelector('.path-name').textContent).toBe("one-long-line.coffee");
      expect(resultsView.element.querySelectorAll('.preview').length).toBe(1);
      expect(resultsView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.element.querySelector('.replacement').textContent).toBe('cats');
    });

    it("renders the replacement when changing the text in the replacement field", async () => {
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.element.querySelector('.match')).toHaveClass('highlight-info');
      expect(resultsView.element.querySelector('.replacement').textContent).toBe('');
      expect(resultsView.element.querySelector('.replacement')).toBeHidden();

      projectFindView.replaceEditor.setText('cats');
      advanceClock(modifiedDelay);

      expect(resultsView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.element.querySelector('.match')).toHaveClass('highlight-error');
      expect(resultsView.element.querySelector('.replacement').textContent).toBe('cats');
      expect(resultsView.element.querySelector('.replacement')).toBeVisible();

      projectFindView.replaceEditor.setText('');
      advanceClock(modifiedDelay);

      expect(resultsView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.element.querySelector('.match')).toHaveClass('highlight-info');
      expect(resultsView.element.querySelector('.replacement')).toBeHidden();
    });
  });

  describe("when list is scrollable", () => {
    it("adds more results to the DOM when scrolling", async () => {
      projectFindView.findEditor.setText(' ');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.element.scrollHeight).toBeGreaterThan(resultsView.element.offsetHeight);
      const previousScrollHeight = resultsView.element.scrollHeight;
      const previousOperationCount = resultsView.element.querySelectorAll("li").length;

      resultsView.element.scrollTop = resultsView.pixelOverdraw * 2;
      resultsView.element.dispatchEvent(new Event('scroll'));
      expect(resultsView.element.scrollHeight).toBeGreaterThan(previousScrollHeight);
      expect(resultsView.element.querySelectorAll('li').length).toBeGreaterThan(previousOperationCount);
    });

    it("adds more results to the DOM when scrolled to bottom", async () => {
      projectFindView.findEditor.setText(' ');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.element.scrollHeight).toBeGreaterThan(resultsView.element.offsetHeight);
      const previousScrollHeight = resultsView.element.scrollHeight;
      const previousOperationCount = resultsView.element.querySelectorAll('li').length;

      resultsView.scrollToBottom();
      resultsView.element.dispatchEvent(new Event('scroll'));
      expect(resultsView.element.scrollHeight).toBeGreaterThan(previousScrollHeight);
      expect(resultsView.element.querySelectorAll('li').length).toBeGreaterThan(previousOperationCount);
    });

    it("renders more results when a result is collapsed via core:move-left", async () => {
      projectFindView.findEditor.setText(' ');
      projectFindView.confirm();
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.element.querySelectorAll(".path").length).toBe(1);

      let pathNode = resultsView.element.querySelectorAll(".path")[0];
      expect(pathNode).not.toHaveClass('collapsed');

      pathNode.dispatchEvent(buildMouseEvent('mousedown', {target: pathNode, which: 1}));
      expect(pathNode).toHaveClass('collapsed');
      expect(resultsView.element.querySelectorAll(".path").length).toBe(2);

      pathNode = resultsView.element.querySelectorAll(".path")[1];
      pathNode.dispatchEvent(buildMouseEvent('mousedown', {target: pathNode, which: 1}));
      expect(pathNode).toHaveClass('collapsed');
      expect(resultsView.element.querySelectorAll(".path").length).toBe(3);
    });

    it("renders more results when a result is collapsed via click", async () => {
      projectFindView.findEditor.setText(' ');
      projectFindView.confirm();
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.element.querySelectorAll(".path-details").length).toBe(1);

      atom.commands.dispatch(resultsView.element, 'core:move-down');
      atom.commands.dispatch(resultsView.element, 'core:move-left');

      expect(resultsView.element.querySelectorAll(".path-details").length).toBe(2);

      atom.commands.dispatch(resultsView.element, 'core:move-down');
      atom.commands.dispatch(resultsView.element, 'core:move-left');

      expect(resultsView.element.querySelectorAll(".path-details").length).toBe(3);
    });

    describe("core:page-up and core:page-down", () => {
      beforeEach(async () => {
        workspaceElement.style.height = '300px';
        workspaceElement.style.width = '1024px';
        projectFindView.findEditor.setText(' ');
        projectFindView.confirm();

        await searchPromise;

        resultsView = getResultsView();
        expect(resultsView.element.scrollTop).toBe(0);
        expect(resultsView.element.scrollHeight).toBeGreaterThan(resultsView.element.offsetHeight);
      });

      function indexOfItem(li) {
        return Array.from(resultsView.element.querySelectorAll("li")).indexOf(li);
      }

      function getSelectedItem() {
        return resultsView.element.querySelector('.selected');
      }

      function getSelectedIndex() {
        return indexOfItem(getSelectedItem());
      }

      it("selects the first result on the next page when core:page-down is triggered", async () => {
        const pageHeight = resultsView.element.offsetHeight;
        expect(resultsView.element.querySelectorAll('li').length).toBeLessThan(resultsView.model.getPathCount() + resultsView.model.getMatchCount());

        let initialIndex = getSelectedIndex();
        await resultsView.pageDown();
        expect(resultsView.element.scrollTop).toBe(pageHeight);
        expect(getSelectedIndex()).toBeGreaterThan(initialIndex);

        initialIndex = getSelectedIndex();
        await resultsView.pageDown();
        expect(resultsView.element.scrollTop).toBe(pageHeight * 2);
        expect(getSelectedIndex()).toBeGreaterThan(initialIndex);

        for (let i = 0; i < 100; i++) await resultsView.pageDown();
        expect(_.last(resultsView.element.querySelectorAll('.search-result'))).toHaveClass('selected');
      });

      it("selects the first result on the previous page when core:page-up is triggered", async () => {
        await resultsView.moveToBottom();

        let itemHeight = resultsView.element.querySelector('.selected').offsetHeight;
        let pageHeight = resultsView.element.offsetHeight;
        let initialScrollTop = resultsView.element.scrollTop;
        let itemsPerPage = Math.round(pageHeight / itemHeight);

        let initiallySelectedIndex = getSelectedIndex();

        await resultsView.pageUp();
        expect(getSelectedIndex()).toBe(initiallySelectedIndex - itemsPerPage);
        expect(resultsView.element.scrollTop).toBe(initialScrollTop - pageHeight);

        await resultsView.pageUp();
        expect(getSelectedIndex()).toBe(initiallySelectedIndex - itemsPerPage * 2);
        expect(resultsView.element.scrollTop).toBe(initialScrollTop - (pageHeight * 2));

        for (let i = 0; i < 60; i++) await resultsView.pageUp();
        expect(resultsView.element.querySelector('li')).toHaveClass('selected');
      });
    });

    describe("core:move-to-top and core:move-to-bottom", () => {
      beforeEach(async () => {
        workspaceElement.style.height = '200px';
        projectFindView.findEditor.setText('so');
        projectFindView.confirm();
        await searchPromise;
        resultsView = getResultsView();
      });

      it("renders all results and selects the last item when core:move-to-bottom is triggered; selects the first item when core:move-to-top is triggered", async () => {
        expect(resultsView.element.querySelectorAll('li').length).toBeLessThan(resultsView.model.getPathCount() + resultsView.model.getMatchCount());

        await resultsView.moveToBottom();
        expect(resultsView.element.querySelectorAll('li').length).toBe(resultsView.model.getPathCount() + resultsView.model.getMatchCount());
        expect(resultsView.element.querySelectorAll('li')[1]).not.toHaveClass('selected');
        expect(_.last(resultsView.element.querySelectorAll('li'))).toHaveClass('selected');
        expect(resultsView.element.scrollTop).not.toBe(0);

        await resultsView.moveToTop();
        expect(resultsView.element.querySelectorAll('li')[1]).toHaveClass('selected');
        expect(resultsView.element.scrollTop).toBe(0);
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

        expect(resultsView.element.querySelector('li').closest('.path')).toHaveClass('selected');
      });
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
      const pathNode = resultsView.element.querySelectorAll(".search-result")[0];
      pathNode.dispatchEvent(buildMouseEvent('mousedown', {target: pathNode, detail: 1}));
      pathNode.dispatchEvent(buildMouseEvent('mousedown', {target: pathNode, detail: 2}));
      await paneItemOpening()
      const editor = atom.workspace.getActiveTextEditor();
      expect(atom.workspace.getActivePane().getPendingItem()).toBe(null);
      expect(atom.views.getView(editor)).toHaveFocus();
    });

    it("opens the file containing the result in a pending state when the search result is single-clicked", async () => {
      const pathNode = resultsView.element.querySelectorAll(".search-result")[0];
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

      let {length: resultCount} = resultsView.element.querySelectorAll("li > ul > li");
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

    describe("when there are hidden .path elements", () => {
      beforeEach(async () => {
        projectFindView.findEditor.setText('i');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;
        resultsView = getResultsView();
      });

      xit("ignores the invisible path elements", () => {
        resultsView.element.querySelector('.path:nth-child(1)').style.display = 'none';

        atom.commands.dispatch(resultsView.element, 'core:move-down');
        expect(resultsView.element.querySelector('.path:nth-child(0) .search-result:nth-child(1)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-down');
        expect(resultsView.element.querySelector('.path:nth-child(2)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-down');
        expect(resultsView.element.querySelector('.path:nth-child(2) .search-result:nth-child(0)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-down');
        expect(resultsView.element.querySelector('.path:nth-child(2) .search-result:nth-child(1)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-up');
        expect(resultsView.element.querySelector('.path:nth-child(2) .search-result:nth-child(0)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-up');
        expect(resultsView.element.querySelector('.path:nth-child(2)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-up');
        expect(resultsView.element.querySelector('.path:nth-child(0) .search-result:nth-child(1)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-down');
        atom.commands.dispatch(resultsView.element, 'core:move-left');
        expect(resultsView.element.querySelector('.path:nth-child(2)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-up');
        expect(resultsView.element.querySelector('.path:nth-child(0) .search-result:nth-child(1)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-down');
        expect(resultsView.element.querySelector('.path:nth-child(2)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-up');
        atom.commands.dispatch(resultsView.element, 'core:move-left');
        expect(resultsView.element.querySelector('.path:nth-child(0)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-down');
        expect(resultsView.element.querySelector('.path:nth-child(2)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-down');
        expect(resultsView.element.querySelector('.path:nth-child(2)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-up');
        expect(resultsView.element.querySelector('.path:nth-child(0)')).toHaveClass('selected');

        atom.commands.dispatch(resultsView.element, 'core:move-up');
        expect(resultsView.element.querySelector('.path:nth-child(0)')).toHaveClass('selected');
      });
    });

    describe("when there are a list of items", () => {
      beforeEach(async () => {
        projectFindView.findEditor.setText('items');
        atom.commands.dispatch(projectFindView.element, 'core:confirm');
        await searchPromise;
        resultsView = getResultsView();
      });

      it("shows the preview-controls", () => {
        expect(getExistingResultsPane().refs.previewControls).toBeVisible();
      });

      it("collapses the selected results view", () => {
        clickOn(resultsView.element.querySelector('.path').querySelector('.search-result'));

        atom.commands.dispatch(resultsView.element, 'core:move-left');

        let selectedItem = resultsView.element.querySelector('.selected');
        expect(selectedItem).toHaveClass('collapsed');
        expect(selectedItem).toBe(resultsView.element.querySelector('.path'));
      });

      it("collapses all results if collapse All button is pressed", () => {
        clickOn(getExistingResultsPane().refs.collapseAll);
        for (let item of Array.from(resultsView.element.querySelector('.list-nested-item'))) {
          expect(item).toHaveClass('collapsed');
        }
      });

      it("expands the selected results view", () => {
        clickOn(resultsView.element.querySelector('.path'));

        atom.commands.dispatch(resultsView.element, 'core:move-right');

        let selectedItem = resultsView.element.querySelector('.selected');
        expect(selectedItem).toHaveClass('search-result');
        expect(selectedItem).toBe(resultsView.element.querySelector('.path').querySelector('.search-result'));
      });

      it("expands all results if 'Expand All' button is pressed", () => {
        clickOn(getExistingResultsPane().refs.expandAll);
        for (let item of Array.from(resultsView.element.querySelector('.list-nested-item'))) {
          expect(item).not.toHaveClass('collapsed');
        }
      });

      xdescribe("when nothing is selected", () => {
        it("doesnt error when the user arrows down", () => {
          resultsView.element.querySelector('.selected').removeClass('selected');
          expect(resultsView.element.querySelector('.selected')).not.toExist();
          atom.commands.dispatch(resultsView.element, 'core:move-down');
          expect(resultsView.element.querySelector('.selected')).toExist();
        });

        it("doesnt error when the user arrows up", () => {
          resultsView.element.querySelector('.selected').removeClass('selected');
          expect(resultsView.element.querySelector('.selected')).not.toExist();
          atom.commands.dispatch(resultsView.element, 'core:move-up');
          expect(resultsView.element.querySelector('.selected')).toExist();
        });
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
          expect(resultsView.element.querySelectorAll('.path')[0]).toHaveClass('selected');
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
      expect(() => atom.commands.dispatch(resultsView.element, 'core:confirm')).not.toThrow();
    });

    it("won't show the preview-controls", async () => {
      projectFindView.findEditor.setText('thiswillnotmatchanythingintheproject');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;
      expect(getExistingResultsPane().refs.previewControls).not.toBeVisible();
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

  describe("icon-service lifecycle", () => {
    it('renders file icon classes based on the provided file-icons service', async () => {
      const fileIconsDisposable = atom.packages.serviceHub.provide('atom.file-icons', '1.0.0', {
        iconClassForPath(path, context) {
          expect(context).toBe("find-and-replace");
          if (path.endsWith('sample.js')) {
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
      let fileIconClasses = Array.from(resultsView.element.querySelector('.path-details .icon')).map(el => el.className);
      expect(fileIconClasses).toContain('first-icon-class second-icon-class icon');
      expect(fileIconClasses).toContain('third-icon-class fourth-icon-class icon');
      expect(fileIconClasses).not.toContain('icon-file-text icon');

      fileIconsDisposable.dispose();
      projectFindView.findEditor.setText('e');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');

      await searchPromise;
      resultsView = getResultsView();
      fileIconClasses = Array.from(resultsView.element.querySelector('.path-details .icon')).map(el => el.className);
      expect(fileIconClasses).not.toContain('first-icon-class second-icon-class icon');
      expect(fileIconClasses).not.toContain('third-icon-class fourth-icon-class icon');
      expect(fileIconClasses).toContain('icon-file-text icon');
    })
  });
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
  // element.dispatchEvent(buildMouseEvent('click', { detail: 1 }));
}
