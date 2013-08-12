RootView = require 'root-view'
SearchModel = require 'buffer-find-and-replace/lib/search-model'

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

  describe "setOption()", ->
    it "kicks out an event", ->
      subject.on 'change', spy = jasmine.createSpy()
      subject.setOption('regex', true)
      expect(spy).toHaveBeenCalled()
      expect(subject.getOption('regex')).toEqual true

  describe "search() with options", ->
    beforeEach ->
    describe "regex option", ->
      it 'returns regex matches when on', ->
        subject.search('items.', regex: true)
        expect(subject.regex.test('items;')).toEqual(true)

      it 'returns only literal matches when off', ->
        subject.search('items.', regex: false)
        expect(subject.regex.test('items;')).toEqual(false)

    describe "caseSensitive option", ->
      it 'matches only same case when on', ->
        subject.search('Items', caseSensitive: true)
        expect(subject.regex.test('Items')).toEqual(true)
        expect(subject.regex.test('items')).toEqual(false)

      it 'matches diff case when off', ->
        subject.search('Items', caseSensitive: false)
        expect(subject.regex.test('items')).toEqual(true)
