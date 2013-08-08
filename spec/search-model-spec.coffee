RootView = require 'root-view'
SearchModel = require 'search-in-buffer/lib/search-model'

describe 'SearchModel', ->
  [goToLine, editor, subject, buffer] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    editor = rootView.getActiveView()
    buffer = editor.activeEditSession.buffer

    subject = new SearchModel()

  describe "setPattern()", ->
    it "kicks out an event", ->
      subject.on 'change', spy = jasmine.createSpy()
      subject.setPattern('items')
      expect(spy).toHaveBeenCalled()
      expect(spy.mostRecentCall.args[0]).toEqual subject
      expect(spy.mostRecentCall.args[1]).toEqual regex: subject.regex
