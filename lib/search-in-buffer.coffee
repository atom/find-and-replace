{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
Point = require 'point'
SearchModel = require './search-model'
SearchResultsView = require './search-results-view'

module.exports =
class SearchInBufferView extends View

  @activate: -> new SearchInBufferView

  @content: ->
    @div class: 'search-in-buffer overlay from-top mini', =>
      @div class: 'find-container', =>
        @div class: 'btn-group pull-right btn-toggle', =>
          @button outlet: 'regexOptionButton', class: 'btn btn-mini', '.*'
          @button outlet: 'caseSensitiveOptionButton', class: 'btn btn-mini', 'Aa'

        @div class: 'find-editor-container', =>
          @subview 'miniEditor', new Editor(mini: true)

  detaching: false

  initialize: ->
    rootView.command 'search-in-buffer:display-find', @showFind
    rootView.command 'search-in-buffer:display-replace', @showReplace

    rootView.command 'search-in-buffer:find-previous', @findPrevious
    rootView.command 'search-in-buffer:find-next', @findNext

    #@miniEditor.on 'focusout', => @detach() unless @detaching
    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @detach()

    @searchModel = new SearchModel
    @searchResultsViews = []
    rootView.eachEditor (editor) =>
      if editor.attached and not editor.mini
        view = new SearchResultsView(@searchModel, editor)
        editor.underlayer.append(view)
        @searchResultsViews.push(view) 

  detach: ->
    return unless @hasParent()

    @detaching = true
    @miniEditor.setText('')

    view.hide() for view in @searchResultsViews

    if @previouslyFocusedElement?.isOnDom()
      @previouslyFocusedElement.focus()
    else
      rootView.focus()

    super

    @detaching = false

  attach: =>
    unless @hasParent()
      @previouslyFocusedElement = $(':focus')
      rootView.append(this)

    view.show() for view in @searchResultsViews
    @miniEditor.focus()

  confirm: =>
    @findNext()
    rootView.getActiveView().focus()

  showFind: =>
    @attach()

  showReplace: =>
  findPrevious: =>
  findNext: =>
    editor = rootView.getActiveView()
    editSession = editor.activeEditSession
    pattern = @miniEditor.getText()
    buffer = editSession.buffer

    @searchModel.search(pattern, @getFindOptions())

    bufferRange = @searchModel.getResultsForEditorId(editor.id).findNext(editSession.getSelection().getBufferRange())
    editSession.setSelectedBufferRange(bufferRange, autoscroll: true) if bufferRange

  getFindOptions: ->
    {
      regex: false
      caseSensitive: false
      inWord: false
      inSelection: false
    }

