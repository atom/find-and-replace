const path = require("path");
const ResultsModel = require("../lib/project/results-model");
const FindOptions = require("../lib/find-options");

describe("ResultsModel", () => {
  let editor, resultsModel, searchPromise;

  beforeEach(() => {
    atom.config.set("core.excludeVcsIgnoredPaths", false);
    atom.project.setPaths([path.join(__dirname, "fixtures")]);

    waitsForPromise(() => atom.workspace.open("sample.js"));

    runs(() => {
      editor = atom.workspace.getActiveTextEditor();
      resultsModel = new ResultsModel(new FindOptions());
    });
  });

  describe("searching for a pattern", () => {
    it("populates the model with all the results, and updates in response to changes in the buffer", () => {
      const resultAddedSpy = jasmine.createSpy();
      const resultRemovedSpy = jasmine.createSpy();

      runs(() => {
        resultsModel.onDidAddResult(resultAddedSpy);
        resultsModel.onDidRemoveResult(resultRemovedSpy);
        searchPromise = resultsModel.search("items", "*.js", "");
      });

      waitsForPromise(() => searchPromise);

      runs(() => {
        expect(resultAddedSpy).toHaveBeenCalled();
        expect(resultAddedSpy.callCount).toBe(1);
        var result = resultsModel.getResult(editor.getPath());
        expect(result.matches.length).toBe(6);
        expect(resultsModel.getPathCount()).toBe(1);
        expect(resultsModel.getMatchCount()).toBe(6);
        expect(resultsModel.getPaths()).toEqual([editor.getPath()]);
        editor.setText("there are some items in here");
        advanceClock(editor.buffer.stoppedChangingDelay);
        expect(resultAddedSpy.callCount).toBe(2);
        result = resultsModel.getResult(editor.getPath());
        expect(result.matches.length).toBe(1);
        expect(resultsModel.getPathCount()).toBe(1);
        expect(resultsModel.getMatchCount()).toBe(1);
        expect(resultsModel.getPaths()).toEqual([editor.getPath()]);
        expect(result.matches[0].lineText).toBe("there are some items in here");
        editor.setText("no matches in here");
        advanceClock(editor.buffer.stoppedChangingDelay);
        expect(resultAddedSpy.callCount).toBe(2);
        expect(resultRemovedSpy.callCount).toBe(1);
        result = resultsModel.getResult(editor.getPath());
        expect(result).not.toBeDefined();
        expect(resultsModel.getPathCount()).toBe(0);
        expect(resultsModel.getMatchCount()).toBe(0);
        resultsModel.clear();
        spyOn(editor, "scan").andCallThrough();
        editor.setText("no matches in here");
        advanceClock(editor.buffer.stoppedChangingDelay);
        expect(editor.scan).not.toHaveBeenCalled();
        expect(resultsModel.getPathCount()).toBe(0);
        expect(resultsModel.getMatchCount()).toBe(0);
      });
    });

    it("ignores changes in untitled buffers", () => {
      const resultAddedSpy = jasmine.createSpy();
      const resultRemovedSpy = jasmine.createSpy();

      waitsForPromise(() => atom.workspace.open());

      runs(() => {
        resultsModel.onDidAddResult(resultAddedSpy);
        resultsModel.onDidRemoveResult(resultRemovedSpy);
        searchPromise = resultsModel.search("items", "*.js", "");
      });

      waitsForPromise(() => searchPromise);

      runs(() => {
        editor = atom.workspace.getActiveTextEditor();
        editor.setText("items\nitems");
        spyOn(editor, "scan").andCallThrough();
        advanceClock(editor.buffer.stoppedChangingDelay);
        expect(editor.scan).not.toHaveBeenCalled();
      });
    });
  });

  describe("cancelling a search", () => {
    let cancelledSpy;

    beforeEach(() => {
      cancelledSpy = jasmine.createSpy();
      resultsModel.onDidCancelSearching(cancelledSpy);
    });

    it("populates the model with all the results, and updates in response to changes in the buffer", () => {
      searchPromise = resultsModel.search("items", "*.js", "");
      expect(resultsModel.inProgressSearchPromise).toBeTruthy();
      resultsModel.clear();
      expect(resultsModel.inProgressSearchPromise).toBeFalsy();

      waitsForPromise(() => searchPromise);

      runs(() => {
        expect(cancelledSpy).toHaveBeenCalled();
      });
    });

    it("populates the model with all the results, and updates in response to changes in the buffer", () => {
      searchPromise = resultsModel.search("items", "*.js", "");
      searchPromise = resultsModel.search("sort", "*.js", "");
      waitsForPromise(() => searchPromise);

      runs(() => {
        expect(cancelledSpy).toHaveBeenCalled();
        expect(resultsModel.getPathCount()).toBe(1);
        expect(resultsModel.getMatchCount()).toBe(5);
      });
    });
  });
});
