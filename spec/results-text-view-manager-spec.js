/** @babel */
const path = require('path');
const ResultsPaneView = require('../lib/project/results-pane');
const {beforeEach, it, fit, ffit, fffit} = require('./async-spec-helpers')

global.beforeEach(function() {
  this.addMatchers({
    toBeWithin(value, delta) {
      this.message = `Expected ${this.actual} to be within ${delta} of ${value}`
      return Math.abs(this.actual - value) < delta;
    }
  });
});

describe('ResultsTextViewManager', () => {
  let projectFindView, resultsView, searchPromise, workspaceElement;

  function getResultsEditor() {
    return atom.workspace.getActiveTextEditor();
  }

  beforeEach(async () => {
    workspaceElement = atom.views.getView(atom.workspace);
    jasmine.attachToDOM(workspaceElement);

    atom.config.set('core.excludeVcsIgnoredPaths', false);
    atom.config.set('find-and-replace.findResultsAsText', true);
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
    it("renders just one line", async () => {
      projectFindView.findEditor.setText('ghijkl');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsEditor = getResultsEditor();
      resultsEditor.update({autoHeight: false})
      const lines = resultsEditor.getText().split('\n');
      expect(lines[1]).toBe("\x1B    1:\x1B test test test test test test test test test test test a b c d e f g h i j k l abcdefghijklmnopqrstuvwxyz");
    })
  });
});
