const _ = require('underscore-plus');
const {TextBuffer, TextEditor, CompositeDisposable} = require('atom');
const Util = require('./project/util');
const etch = require('etch');
const $ = etch.dom;

module.exports =
class FindView {
  constructor(model, {findBuffer, replaceBuffer, findHistoryCycler, replaceHistoryCycler} = {}) {
    this.model = model;
    this.findBuffer = findBuffer;
    this.replaceBuffer = replaceBuffer;
    this.findHistoryCycler = findHistoryCycler;
    this.replaceHistoryCycler = replaceHistoryCycler;
    this.subscriptions = new CompositeDisposable();

    etch.initialize(this)

    this.findHistoryCycler.addEditorElement(this.findEditor.getElement());
    this.replaceHistoryCycler.addEditorElement(this.replaceEditor.getElement());
    this.handleEvents();
    this.clearMessage();
    this.updateOptionViews();
    this.updateReplaceEnablement();
    this.createWrapIcon();
  }

  update(props) {}

  render() {
    return (
      $.div({tabIndex: -1, className: 'find-and-replace'},
        $.header({className: 'header'},
          $.span({ref: 'closeButton', className: 'header-item close-button pull-right'},
            $.i({className: "icon icon-x clickable"})
          ),

          $.span({ref: 'descriptionLabel', className: 'header-item description'},
            'Find in Current Buffer'
          ),

          $.span({className: 'header-item options-label pull-right'},
            $.span({}, 'Finding with Options: '),
            $.span({ref: 'optionsLabel', className: 'options'}),
            $.span({className: 'btn-group btn-toggle btn-group-options'},
              $.button({ref: 'regexOptionButton', className: 'btn'},
                $.svg({className: "icon", innerHTML: '<use href="#find-and-replace-icon-regex" />'})
              ),

              $.button({ref: 'caseOptionButton', className: 'btn'},
                $.svg({className: "icon", innerHTML: '<use href="#find-and-replace-icon-case" />'})
              ),

              $.button({ref: 'selectionOptionButton', className: 'btn option-selection'},
                $.svg({className: "icon", innerHTML: '<use href="#find-and-replace-icon-selection" />'})
              ),

              $.button({ref: 'wholeWordOptionButton', className: 'btn option-whole-word'},
                $.svg({className: "icon", innerHTML: '<use href="#find-and-replace-icon-word" />'})
              )
            )
          )
        ),

        $.section({className: 'input-block find-container'},
          $.div({className: 'input-block-item input-block-item--flex editor-container'},
            $(TextEditor, {
              ref: 'findEditor',
              mini: true,
              placeholderText: 'Find in current buffer',
              buffer: this.findBuffer
            }),

            $.div({className: 'find-meta-container'},
              $.span({ref: 'resultCounter', className: 'text-subtle result-counter'})
            )
          ),

          $.div({className: 'input-block-item'},
            $.div({className: 'btn-group btn-group-find'},
              $.button({ref: 'nextButton', className: 'btn btn-next'}, 'Find')
            ),

            $.div({className: 'btn-group btn-group-find-all'},
              $.button({ref: 'findAllButton', className: 'btn btn-all'}, 'Find All')
            )
          )
        ),

        $.section({className: 'input-block replace-container'},
          $.div({className: 'input-block-item input-block-item--flex editor-container'},
            $(TextEditor, {
              ref: 'replaceEditor',
              mini: true,
              placeholderText: 'Replace in current buffer',
              buffer: this.replaceBuffer
            })
          ),

          $.div({className: 'input-block-btn'},
            $.span({className: 'btn-group btn-toggle btn-group-replace-function'},
              $.button({ref: 'functionOptionButton', className: 'btn'},
                $.svg({className: "icon", innerHTML: '<use href="#find-and-replace-icon-function" />'})
              )
            )
          ),

          $.div({className: 'input-block-item'},
            $.div({className: 'btn-group btn-group-replace'},
              $.button({ref: 'replaceNextButton', className: 'btn btn-next'}, 'Replace')
            ),

            $.div({className: 'btn-group btn-group-replace-all'},
              $.button({ref: 'replaceAllButton', className: 'btn btn-all'}, 'Replace All')
            )
          )
        ),

        $.svg({style: {display: 'none'}, innerHTML: `
          <symbol id="find-and-replace-icon-function" viewBox="0 0 60 54" stroke="none" fill-rule="evenodd">
            <path d="M24.703,17.77l-3.428,13.535c-1.602,6.387-3.164,11.016-4.688,13.887s-3.306,4.995-5.347,6.372   c-2.041,1.377-4.38,2.065-7.017,2.065c-1.66,0-2.881-0.318-3.662-0.952c-0.781-0.635-1.172-1.382-1.172-2.241   c0-0.801,0.322-1.494,0.967-2.08s1.494-0.879,2.549-0.879c0.879,0,1.553,0.225,2.021,0.674s0.703,1.016,0.703,1.699   c0,0.625-0.146,1.088-0.439,1.392c-0.293,0.303-0.439,0.503-0.439,0.601l0.146,0.205c0.117,0.098,0.254,0.146,0.41,0.146   c0.586,0,1.084-0.186,1.494-0.557c1.036-0.918,1.807-2.031,2.314-3.34c0.352-0.898,1.025-3.271,2.021-7.119l5.977-23.408h-4.072   l0.967-3.428c1.465,0.02,2.529-0.166,3.193-0.557c0.664-0.391,1.367-1.27,2.109-2.637c2.148-3.965,4.414-6.807,6.797-8.525   c2.383-1.718,5.039-2.578,7.969-2.578c1.875,0,3.237,0.362,4.087,1.084c0.85,0.723,1.274,1.66,1.274,2.813   c0,1.016-0.283,1.821-0.85,2.417c-0.566,0.596-1.27,0.894-2.109,0.894c-0.781,0-1.426-0.244-1.934-0.732   c-0.508-0.488-0.762-1.074-0.762-1.758c0-0.488,0.161-1.006,0.483-1.553c0.322-0.546,0.483-0.918,0.483-1.113   c0-0.215-0.073-0.391-0.22-0.527c-0.146-0.136-0.337-0.205-0.571-0.205c-1.152,0-2.334,0.713-3.545,2.139   c-1.992,2.285-3.594,5.899-4.805,10.84h4.248l-1.025,3.428H24.703z"/><path d="M31.705,15.279l10.225-1.758c1.855,2.911,3.164,6.113,3.926,9.609c1.914-2.832,3.359-4.814,4.336-5.947   c1.309-1.523,2.388-2.515,3.237-2.974c0.85-0.458,1.753-0.688,2.71-0.688c1.074,0,1.899,0.293,2.476,0.879   c0.575,0.586,0.864,1.377,0.864,2.373c0,0.938-0.289,1.704-0.864,2.3c-0.576,0.596-1.294,0.894-2.153,0.894   c-0.625,0-1.344-0.112-2.153-0.337c-0.811-0.224-1.372-0.337-1.685-0.337c-0.82,0-1.602,0.293-2.344,0.879   c-1.016,0.801-2.266,2.51-3.75,5.127c1.66,5.859,2.988,9.434,3.984,10.723c0.586,0.762,1.182,1.143,1.787,1.143   c0.508,0,0.947-0.127,1.318-0.381c0.566-0.41,1.436-1.436,2.607-3.076l1.055,0.615c-1.719,2.773-3.398,4.727-5.039,5.859   c-1.25,0.879-2.48,1.318-3.691,1.318c-1.25,0-2.29-0.278-3.12-0.835c-0.831-0.557-1.567-1.465-2.212-2.725s-1.406-3.276-2.285-6.05   c-2.285,2.91-4.077,5.035-5.376,6.372c-1.3,1.338-2.378,2.212-3.237,2.622S30.543,41.5,29.566,41.5   c-1.015,0-1.821-0.293-2.417-0.879c-0.596-0.586-0.894-1.348-0.894-2.285c0-0.996,0.322-1.816,0.967-2.461s1.465-0.967,2.461-0.967   c0.527,0,1.123,0.156,1.787,0.469c0.977,0.469,1.68,0.703,2.109,0.703c0.566,0,1.074-0.117,1.523-0.352   c0.586-0.293,1.328-0.928,2.227-1.904c0.547-0.605,1.553-1.895,3.018-3.867c-1.875-6.953-3.34-11.113-4.395-12.48   c-0.664-0.879-1.504-1.318-2.52-1.318c-0.527,0-1.172,0.078-1.934,0.234L31.705,15.279z"></path>
          </symbol>

          <symbol id="find-and-replace-icon-regex" viewBox="0 0 20 16" stroke="none" fill-rule="evenodd">
            <rect x="3" y="10" width="3" height="3" rx="1"></rect>
            <rect x="12" y="3" width="2" height="9" rx="1"></rect>
            <rect transform="translate(13.000000, 7.500000) rotate(60.000000) translate(-13.000000, -7.500000) " x="12" y="3" width="2" height="9" rx="1"></rect>
            <rect transform="translate(13.000000, 7.500000) rotate(-60.000000) translate(-13.000000, -7.500000) " x="12" y="3" width="2" height="9" rx="1"></rect>
          </symbol>

          <symbol id="find-and-replace-icon-case" viewBox="0 0 20 16" stroke="none" fill-rule="evenodd">
            <path d="M10.919,13 L9.463,13 C9.29966585,13 9.16550052,12.9591671 9.0605,12.8775 C8.95549947,12.7958329 8.8796669,12.6943339 8.833,12.573 L8.077,10.508 L3.884,10.508 L3.128,12.573 C3.09066648,12.6803339 3.01716722,12.7783329 2.9075,12.867 C2.79783279,12.9556671 2.66366746,13 2.505,13 L1.042,13 L5.018,2.878 L6.943,2.878 L10.919,13 Z M4.367,9.178 L7.594,9.178 L6.362,5.811 C6.30599972,5.66166592 6.24416701,5.48550102 6.1765,5.2825 C6.108833,5.07949898 6.04233366,4.85900119 5.977,4.621 C5.91166634,4.85900119 5.84750032,5.08066564 5.7845,5.286 C5.72149969,5.49133436 5.65966697,5.67099923 5.599,5.825 L4.367,9.178 Z M18.892,13 L18.115,13 C17.9516658,13 17.8233338,12.9755002 17.73,12.9265 C17.6366662,12.8774998 17.5666669,12.7783341 17.52,12.629 L17.366,12.118 C17.1839991,12.2813341 17.0055009,12.4248327 16.8305,12.5485 C16.6554991,12.6721673 16.4746676,12.7759996 16.288,12.86 C16.1013324,12.9440004 15.903001,13.0069998 15.693,13.049 C15.4829989,13.0910002 15.2496679,13.112 14.993,13.112 C14.6896651,13.112 14.4096679,13.0711671 14.153,12.9895 C13.896332,12.9078329 13.6758342,12.7853342 13.4915,12.622 C13.3071657,12.4586658 13.1636672,12.2556679 13.061,12.013 C12.9583328,11.7703321 12.907,11.4880016 12.907,11.166 C12.907,10.895332 12.9781659,10.628168 13.1205,10.3645 C13.262834,10.100832 13.499665,9.8628344 13.831,9.6505 C14.162335,9.43816561 14.6033306,9.2620007 15.154,9.122 C15.7046694,8.9819993 16.3883292,8.90266676 17.205,8.884 L17.205,8.464 C17.205,7.98333093 17.103501,7.62750116 16.9005,7.3965 C16.697499,7.16549885 16.4023352,7.05 16.015,7.05 C15.7349986,7.05 15.5016676,7.08266634 15.315,7.148 C15.1283324,7.21333366 14.9661673,7.28683292 14.8285,7.3685 C14.6908326,7.45016707 14.5636672,7.52366634 14.447,7.589 C14.3303327,7.65433366 14.2020007,7.687 14.062,7.687 C13.9453327,7.687 13.8450004,7.65666697 13.761,7.596 C13.6769996,7.53533303 13.6093336,7.46066711 13.558,7.372 L13.243,6.819 C14.0690041,6.06299622 15.0653275,5.685 16.232,5.685 C16.6520021,5.685 17.0264983,5.75383264 17.3555,5.8915 C17.6845016,6.02916736 17.9633322,6.22049877 18.192,6.4655 C18.4206678,6.71050122 18.5944994,7.00333163 18.7135,7.344 C18.8325006,7.68466837 18.892,8.05799797 18.892,8.464 L18.892,13 Z M15.532,11.922 C15.7093342,11.922 15.8726659,11.9056668 16.022,11.873 C16.1713341,11.8403332 16.3124993,11.7913337 16.4455,11.726 C16.5785006,11.6606663 16.7068327,11.5801671 16.8305,11.4845 C16.9541673,11.3888329 17.0789993,11.2756673 17.205,11.145 L17.205,9.934 C16.7009975,9.95733345 16.279835,10.0004997 15.9415,10.0635 C15.603165,10.1265003 15.3313343,10.2069995 15.126,10.305 C14.9206656,10.4030005 14.7748337,10.5173327 14.6885,10.648 C14.6021662,10.7786673 14.559,10.9209992 14.559,11.075 C14.559,11.3783349 14.6488324,11.5953327 14.8285,11.726 C15.0081675,11.8566673 15.2426652,11.922 15.532,11.922 L15.532,11.922 Z"></path>
          </symbol>

          <symbol id="find-and-replace-icon-selection" viewBox="0 0 20 16" stroke="none" fill-rule="evenodd">
            <rect opacity="0.6" x="17" y="9" width="2" height="4"></rect>
            <rect opacity="0.6" x="14" y="9" width="2" height="4"></rect>
            <rect opacity="0.6" x="1" y="3" width="2" height="4"></rect>
            <rect x="1" y="9" width="11" height="4"></rect>
            <rect x="5" y="3" width="14" height="4"></rect>
          </symbol>

          <symbol id="find-and-replace-icon-word" viewBox="0 0 20 16" stroke="none" fill-rule="evenodd">
            <rect opacity="0.6" x="1" y="3" width="2" height="6"></rect>
            <rect opacity="0.6" x="17" y="3" width="2" height="6"></rect>
            <rect x="6" y="3" width="2" height="6"></rect>
            <rect x="12" y="3" width="2" height="6"></rect>
            <rect x="9" y="3" width="2" height="6"></rect>
            <path d="M4.5,13 L15.5,13 L16,13 L16,12 L15.5,12 L4.5,12 L4,12 L4,13 L4.5,13 L4.5,13 Z"></path>
            <path d="M4,10.5 L4,12.5 L4,13 L5,13 L5,12.5 L5,10.5 L5,10 L4,10 L4,10.5 L4,10.5 Z"></path>
            <path d="M15,10.5 L15,12.5 L15,13 L16,13 L16,12.5 L16,10.5 L16,10 L15,10 L15,10.5 L15,10.5 Z"></path>
          </symbol>

          <symbol id="find-and-replace-context-lines-before" viewBox="0 0 20 16" stroke="none" fill-rule="evenodd">
            <rect opacity="0.6" x="2" y="11" width="16" height="2"></rect>
            <rect x="2" y="7" width="10" height="2"></rect>
            <rect x="2" y="3" width="10" height="2"></rect>
          </symbol>

          <symbol id="find-and-replace-context-lines-after" viewBox="0 0 20 16" stroke="none" fill-rule="evenodd">
            <rect x="2" y="11" width="10" height="2"></rect>
            <rect x="2" y="7" width="10" height="2"></rect>
            <rect opacity="0.6" x="2" y="3" width="16" height="2"></rect>
          </symbol>
        `})
      )
    );
  }

  get findEditor() { return this.refs.findEditor; }

  get replaceEditor() { return this.refs.replaceEditor; }

  destroy() {
    if (this.subscriptions) this.subscriptions.dispose();
    if (this.tooltipSubscriptions) this.tooltipSubscriptions.dispose();
  }

  setPanel(panel) {
    this.panel = panel;
    this.subscriptions.add(this.panel.onDidChangeVisible(visible => {
      if (visible) {
        this.didShow();
      } else {
        this.didHide();
      }
    }));
  }

  didShow() {
    atom.views.getView(atom.workspace).classList.add('find-visible');
    if (this.tooltipSubscriptions) return;

    this.tooltipSubscriptions = new CompositeDisposable(
      atom.tooltips.add(this.refs.closeButton, {
        title: 'Close Panel <span class="keystroke">Esc</span>',
        html: true
      }),
      atom.tooltips.add(this.refs.regexOptionButton, {
        title: "Use Regex",
        keyBindingCommand: 'find-and-replace:toggle-regex-option',
        keyBindingTarget: this.findEditor.element
      }),
      atom.tooltips.add(this.refs.caseOptionButton, {
        title: "Match Case",
        keyBindingCommand: 'find-and-replace:toggle-case-option',
        keyBindingTarget: this.findEditor.element
      }),
      atom.tooltips.add(this.refs.selectionOptionButton, {
        title: "Only In Selection",
        keyBindingCommand: 'find-and-replace:toggle-selection-option',
        keyBindingTarget: this.findEditor.element
      }),
      atom.tooltips.add(this.refs.wholeWordOptionButton, {
        title: "Whole Word",
        keyBindingCommand: 'find-and-replace:toggle-whole-word-option',
        keyBindingTarget: this.findEditor.element
      }),

      atom.tooltips.add(this.refs.nextButton, {
        title: "Find Next",
        keyBindingCommand: 'find-and-replace:find-next',
        keyBindingTarget: this.findEditor.element
      }),
      atom.tooltips.add(this.refs.findAllButton, {
        title: "Find All",
        keyBindingCommand: 'find-and-replace:find-all',
        keyBindingTarget: this.findEditor.element
      }),

      atom.tooltips.add(this.refs.functionOptionButton, {
        title: "Use Function",
        keyBindingCommand: 'find-and-replace:toggle-function-option',
        keyBindingTarget: this.findEditor.element
      })
    );
  }

  didHide() {
    this.hideAllTooltips();
    let workspaceElement = atom.views.getView(atom.workspace);
    workspaceElement.focus();
    workspaceElement.classList.remove('find-visible');
  }

  hideAllTooltips() {
    this.tooltipSubscriptions.dispose();
    this.tooltipSubscriptions = null;
  }

  handleEvents() {
    this.handleFindEvents();
    this.handleReplaceEvents();

    this.subscriptions.add(atom.commands.add(this.findEditor.element, {
      'core:confirm': () => this.confirm(),
      'find-and-replace:confirm': () => this.confirm(),
      'find-and-replace:show-previous': () => this.showPrevious(),
      'find-and-replace:find-all': () => this.findAll()
    }));

    this.subscriptions.add(atom.commands.add(this.replaceEditor.element, {
      'core:confirm': () => this.replaceNext()
    }));

    this.subscriptions.add(atom.commands.add(this.element, {
      'core:close': () => this.panel && this.panel.hide(),
      'core:cancel': () => this.panel && this.panel.hide(),
      'find-and-replace:focus-next': this.toggleFocus.bind(this),
      'find-and-replace:focus-previous': this.toggleFocus.bind(this),
      'find-and-replace:toggle-regex-option': this.toggleRegexOption.bind(this),
      'find-and-replace:toggle-case-option': this.toggleCaseOption.bind(this),
      'find-and-replace:toggle-selection-option': this.toggleSelectionOption.bind(this),
      'find-and-replace:toggle-whole-word-option': this.toggleWholeWordOption.bind(this),
      'find-and-replace:toggle-function-option': this.toggleFunctionOption.bind(this)
    }));

    this.subscriptions.add(this.model.onDidUpdate(this.markersUpdated.bind(this)));
    this.subscriptions.add(this.model.onDidError(this.findError.bind(this)));
    this.subscriptions.add(this.model.onDidChangeCurrentResult(this.updateResultCounter.bind(this)));
    this.subscriptions.add(this.model.getFindOptions().onDidChange(this.updateOptionViews.bind(this)));

    this.refs.closeButton.addEventListener('click', () => this.panel && this.panel.hide());
    this.refs.regexOptionButton.addEventListener('click', this.toggleRegexOption.bind(this));
    this.refs.caseOptionButton.addEventListener('click', this.toggleCaseOption.bind(this));
    this.refs.selectionOptionButton.addEventListener('click', this.toggleSelectionOption.bind(this));
    this.refs.wholeWordOptionButton.addEventListener('click', this.toggleWholeWordOption.bind(this));

    this.refs.functionOptionButton.addEventListener('click', this.toggleFunctionOption.bind(this));

    this.element.addEventListener('focus', () => this.findEditor.element.focus());
    this.element.addEventListener('click', (e) => {
      if (e.target.tagName === 'button') {
        let workspaceElement = atom.views.getView(atom.workspace);
        workspaceElement.focus();
      }
    });
  }

  handleFindEvents() {
    this.findEditor.onDidStopChanging(() => this.liveSearch());
    this.refs.nextButton.addEventListener('click', e => e.shiftKey ? this.findPrevious({focusEditorAfter: true}) : this.findNext({focusEditorAfter: true}));
    this.refs.findAllButton.addEventListener('click', this.findAll.bind(this));
    this.subscriptions.add(atom.commands.add('atom-workspace', {
      'find-and-replace:find-next': () => this.findNext({focusEditorAfter: true}),
      'find-and-replace:find-previous': () => this.findPrevious({focusEditorAfter: true}),
      'find-and-replace:find-all': () => this.findAll({focusEditorAfter: true}),
      'find-and-replace:find-next-selected': this.findNextSelected.bind(this),
      'find-and-replace:find-previous-selected': this.findPreviousSelected.bind(this),
      'find-and-replace:use-selection-as-find-pattern': this.setSelectionAsFindPattern.bind(this)
    }));
  }

  handleReplaceEvents() {
    this.refs.replaceNextButton.addEventListener('click', this.replaceNext.bind(this));
    this.refs.replaceAllButton.addEventListener('click', this.replaceAll.bind(this));
    this.subscriptions.add(atom.commands.add('atom-workspace', {
      'find-and-replace:replace-previous': this.replacePrevious.bind(this),
      'find-and-replace:replace-next': this.replaceNext.bind(this),
      'find-and-replace:replace-all': this.replaceAll.bind(this),
    }));
  }

  focusFindEditor() {
    const activeEditor = atom.workspace.getCenter().getActiveTextEditor()
    let selectedText = activeEditor && activeEditor.getSelectedText()
    if (selectedText && selectedText.indexOf('\n') < 0) {
      if (this.model.getFindOptions().useRegex) {
        selectedText = Util.escapeRegex(selectedText);
      }
      this.findEditor.setText(selectedText);
    }
    this.findEditor.element.focus();
    this.findEditor.selectAll();
  }

  focusReplaceEditor() {
    const activeEditor = atom.workspace.getCenter().getActiveTextEditor()
    const selectedText = activeEditor && activeEditor.getSelectedText()
    if (selectedText && selectedText.indexOf('\n') < 0) {
      this.replaceEditor.setText(selectedText);
    }
    this.replaceEditor.getElement().focus();
    this.replaceEditor.selectAll();
  }

  toggleFocus() {
    if (this.findEditor.element.hasFocus()) {
      this.replaceEditor.element.focus();
    } else {
      this.findEditor.element.focus();
    }
  }

  confirm() {
    this.findNext({focusEditorAfter: atom.config.get('find-and-replace.focusEditorAfterSearch')});
  }

  showPrevious() {
    this.findPrevious({focusEditorAfter: atom.config.get('find-and-replace.focusEditorAfterSearch')});
  }

  liveSearch() {
    let findPattern = this.findEditor.getText();
    if (findPattern.length === 0 || (findPattern.length >= atom.config.get('find-and-replace.liveSearchMinimumCharacters') && !this.model.patternMatchesEmptyString(findPattern))) {
      return this.model.search(findPattern);
    }
  }

  search(findPattern, options) {
    if (arguments.length === 1 && typeof findPattern === 'object') {
      options = findPattern;
      findPattern = null;
    }
    if (findPattern == null) { findPattern = this.findEditor.getText(); }
    return this.model.search(findPattern, options);
  }

  findAll(options = {focusEditorAfter: true}) {
    this.findAndSelectResult(this.selectAllMarkers, options);
  }

  findNext(options = {focusEditorAfter: false}) {
    this.findAndSelectResult(this.selectFirstMarkerAfterCursor, options);
  }

  findPrevious(options = {focusEditorAfter: false}) {
    this.findAndSelectResult(this.selectFirstMarkerBeforeCursor, options);
  }

  findAndSelectResult(selectFunction, {focusEditorAfter, fieldToFocus}) {
    this.search();
    this.findHistoryCycler.store();

    if (this.markers && this.markers.length > 0) {
      selectFunction.call(this);
      if (fieldToFocus) {
        fieldToFocus.getElement().focus();
      } else if (focusEditorAfter) {
        let workspaceElement = atom.views.getView(atom.workspace);
        workspaceElement.focus();
      } else {
        this.findEditor.getElement().focus();
      }
    } else {
      atom.beep();
    }
  }

  replaceNext() {
    this.replace('findNext', 'firstMarkerIndexStartingFromCursor');
  }

  replacePrevious() {
    this.replace('findPrevious', 'firstMarkerIndexBeforeCursor');
  }

  replace(nextOrPreviousFn, nextIndexFn) {
    this.search();
    this.findHistoryCycler.store();
    this.replaceHistoryCycler.store();

    if (this.markers && this.markers.length > 0) {
      let currentMarker = this.model.currentResultMarker;
      if (!currentMarker) {
        let position = this[nextIndexFn]();
        if (position) {
          currentMarker = this.markers[position.index];
        }
      }

      const error = this.model.replace([currentMarker], this.replaceEditor.getText());
      if(!error){
        this[nextOrPreviousFn]({fieldToFocus: this.replaceEditor});
      } else {
        atom.beep()
      }
    } else {
      atom.beep();
    }
  }

  replaceAll() {
    this.search();
    if (this.markers && this.markers.length > 0) {
      this.findHistoryCycler.store();
      this.replaceHistoryCycler.store();
      this.model.replace(this.markers, this.replaceEditor.getText());
    } else {
      atom.beep();
    }
  }

  markersUpdated(markers) {
    this.markers = markers;
    this.findError = null;
    this.updateResultCounter();
    this.updateReplaceEnablement();

    if (this.model.getFindOptions().findPattern) {
      let results = this.markers.length;
      let resultsStr = results ? _.pluralize(results, 'result') : 'No results';
      this.element.classList.remove('has-results', 'has-no-results');
      this.element.classList.add(results ? 'has-results' : 'has-no-results');
      this.setInfoMessage(`${resultsStr} found for '${this.model.getFindOptions().findPattern}'`);
      if (this.findEditor.getElement().hasFocus() && results > 0 && atom.config.get('find-and-replace.scrollToResultOnLiveSearch')) {
        this.findAndSelectResult(this.selectFirstMarkerStartingFromCursor, {focusEditorAfter: false});
      }
    } else {
      this.clearMessage();
    }
  }

  findError(error) {
    this.setErrorMessage(error.message);
  }

  updateResultCounter() {
    let text;

    const index = this.markers && this.markers.indexOf(this.model.currentResultMarker);
    if (index != null && index > -1) {
      text = `${ index + 1} of ${this.markers.length}`;
    } else {
      if (this.markers == null || this.markers.length === 0) {
        text = "no results";
      } else if (this.markers.length === 1) {
        text = "1 found";
      } else {
        text = `${this.markers.length} found`;
      }
    }

    this.refs.resultCounter.textContent = text;
  }

  setInfoMessage(infoMessage) {
    this.refs.descriptionLabel.textContent = infoMessage;
    this.refs.descriptionLabel.classList.remove('text-error');
  }

  setErrorMessage(errorMessage) {
    this.refs.descriptionLabel.textContent = errorMessage;
    this.refs.descriptionLabel.classList.add('text-error');
  }

  clearMessage() {
    this.element.classList.remove('has-results', 'has-no-results');
    this.refs.descriptionLabel.innerHTML = 'Find in Current Buffer'
    this.refs.descriptionLabel.classList.remove('text-error');
  }

  selectFirstMarkerAfterCursor() {
    let marker = this.firstMarkerIndexAfterCursor();
    if (!marker) { return; }
    let {index, wrapped} = marker;
    this.selectMarkerAtIndex(index, wrapped);
  }

  selectFirstMarkerStartingFromCursor() {
    let marker = this.firstMarkerIndexAfterCursor(true);
    if (!marker) { return; }
    let {index, wrapped} = marker;
    this.selectMarkerAtIndex(index, wrapped);
  }

  selectFirstMarkerBeforeCursor() {
    let marker = this.firstMarkerIndexBeforeCursor();
    if (!marker) { return; }
    let {index, wrapped} = marker;
    this.selectMarkerAtIndex(index, wrapped);
  }

  firstMarkerIndexStartingFromCursor() {
    return this.firstMarkerIndexAfterCursor(true);
  }

  firstMarkerIndexAfterCursor(indexIncluded = false) {
    const editor = this.model.getEditor();
    if (!editor || !this.markers) return null;

    const selection = editor.getLastSelection();
    let {start, end} = selection.getBufferRange();
    if (selection.isReversed()) start = end;

    for (let index = 0, length = this.markers.length; index < length; index++) {
      const marker = this.markers[index];
      const markerStartPosition = marker.bufferMarker.getStartPosition();
      switch (markerStartPosition.compare(start)) {
        case -1:
          continue;
        case 0:
          if (!indexIncluded) continue;
          break;
      }
      return {index, wrapped: null};
    }

    return {index: 0, wrapped: 'up'};
  }

  firstMarkerIndexBeforeCursor() {
    const editor = this.model.getEditor();
    if (!editor) return null;

    const selection = this.model.getEditor().getLastSelection();
    let {start, end} = selection.getBufferRange();
    if (selection.isReversed()) start = end;

    for (let index = this.markers.length - 1; index >= 0; index--) {
      const marker = this.markers[index];
      const markerEndPosition = marker.bufferMarker.getEndPosition();
      if (markerEndPosition.isLessThan(start)) {
        return {index, wrapped: null};
      }
    }

    return {index: this.markers.length - 1, wrapped: 'down'};
  }

  selectAllMarkers() {
    if (!this.markers || this.markers.length === 0) return;
    let ranges = (Array.from(this.markers).map((marker) => marker.getBufferRange()));
    let scrollMarker = this.markers[this.firstMarkerIndexAfterCursor().index];
    let editor = this.model.getEditor();
    for(let range of ranges) {
      editor.unfoldBufferRow(range.start.row);
    }
    editor.setSelectedBufferRanges(ranges, {flash: true});
    editor.scrollToBufferPosition(scrollMarker.getStartBufferPosition(), {center: true});
  }

  selectMarkerAtIndex(markerIndex, wrapped) {
    let marker;
    if (!this.markers || this.markers.length === 0) return;

    if (marker = this.markers[markerIndex]) {
      let editor = this.model.getEditor();
      let bufferRange = marker.getBufferRange();
      let screenRange = marker.getScreenRange();

      if (
        screenRange.start.row < editor.getFirstVisibleScreenRow() ||
        screenRange.end.row > editor.getLastVisibleScreenRow()
      ) {
        switch (wrapped) {
          case 'up':
            this.showWrapIcon('icon-move-up');
            break;
          case 'down':
            this.showWrapIcon('icon-move-down');
            break;
        }
      }

      editor.unfoldBufferRow(bufferRange.start.row);
      editor.setSelectedBufferRange(bufferRange, {flash: true});
      editor.scrollToCursorPosition({center: true});
    }
  }

  setSelectionAsFindPattern() {
    let editor = this.model.getEditor();
    if (editor && editor.getSelectedText) {
      let findPattern = editor.getSelectedText() || editor.getWordUnderCursor();
      if (this.model.getFindOptions().useRegex) {
        findPattern = Util.escapeRegex(findPattern);
      }
      if (findPattern) {
        this.findEditor.setText(findPattern);
        this.search();
      }
    }
  }

  findNextSelected() {
    this.setSelectionAsFindPattern();
    this.findNext({focusEditorAfter: true});
  }

  findPreviousSelected() {
    this.setSelectionAsFindPattern();
    this.findPrevious({focusEditorAfter: true});
  }

  updateOptionViews() {
    this.updateOptionButtons();
    this.updateOptionsLabel();
    this.updateSyntaxHighlighting();
  }

  updateSyntaxHighlighting() {
    const {useRegex, useFunction} = this.model.getFindOptions();
    if (useRegex) {
      this.findEditor.setGrammar(atom.grammars.grammarForScopeName('source.js.regexp'));
    } else {
      this.findEditor.setGrammar(atom.grammars.nullGrammar);
    }
    if (useFunction) {
      this.replaceEditor.setGrammar(atom.grammars.grammarForScopeName('source.js'));
    } else if (useRegex) {
      this.replaceEditor.setGrammar(atom.grammars.grammarForScopeName('source.js.regexp.replacement'));
    } else {
      this.replaceEditor.setGrammar(atom.grammars.nullGrammar);
    }
  }

  updateOptionsLabel() {
    const label = [];

    if (this.model.getFindOptions().useRegex) {
      label.push('Regex');
    }

    if (this.model.getFindOptions().caseSensitive) {
      label.push('Case Sensitive');
    } else {
      label.push('Case Insensitive');
    }

    if (this.model.getFindOptions().inCurrentSelection) {
      label.push('Within Current Selection');
    }

    if (this.model.getFindOptions().wholeWord) {
      label.push('Whole Word');
    }

    this.refs.optionsLabel.textContent = label.join(', ');
  }

  updateOptionButtons() {
    this.setOptionButtonState(this.refs.regexOptionButton, this.model.getFindOptions().useRegex);
    this.setOptionButtonState(this.refs.caseOptionButton, this.model.getFindOptions().caseSensitive);
    this.setOptionButtonState(this.refs.selectionOptionButton, this.model.getFindOptions().inCurrentSelection);
    this.setOptionButtonState(this.refs.wholeWordOptionButton, this.model.getFindOptions().wholeWord);

    this.setOptionButtonState(this.refs.functionOptionButton, this.model.getFindOptions().useFunction);
  }

  setOptionButtonState(optionButton, selected) {
    if (selected) {
      optionButton.classList.add('selected');
    } else {
      optionButton.classList.remove('selected');
    }
  }

  anyMarkersAreSelected() {
    let editor = this.model.getEditor();
    if (editor) {
      return editor.getSelectedBufferRanges().some(selectedRange => {
        return this.model.findMarker(selectedRange);
      });
    }
  }

  toggleRegexOption() {
    this.search({useRegex: !this.model.getFindOptions().useRegex});
    if (!this.anyMarkersAreSelected()) {
      this.selectFirstMarkerAfterCursor();
    }
  }

  toggleCaseOption() {
    this.search({caseSensitive: !this.model.getFindOptions().caseSensitive});
    if (!this.anyMarkersAreSelected()) {
      this.selectFirstMarkerAfterCursor();
    }
  }

  toggleSelectionOption() {
    this.search({inCurrentSelection: !this.model.getFindOptions().inCurrentSelection});
    if (!this.anyMarkersAreSelected()) {
      this.selectFirstMarkerAfterCursor();
    }
  }

  toggleWholeWordOption() {
    this.search(this.findEditor.getText(), {wholeWord: !this.model.getFindOptions().wholeWord});
    if (!this.anyMarkersAreSelected()) {
      this.selectFirstMarkerAfterCursor();
    }
  }

  toggleFunctionOption() {
    this.search({useFunction: !this.model.getFindOptions().useFunction});
  }

  updateReplaceEnablement() {
    let canReplace = this.markers && this.markers.length > 0;
    if (canReplace && !this.refs.replaceAllButton.classList.contains('disabled')) return;

    if (this.replaceTooltipSubscriptions) this.replaceTooltipSubscriptions.dispose();
    this.replaceTooltipSubscriptions = new CompositeDisposable;

    if (canReplace) {
      this.refs.replaceAllButton.classList.remove('disabled');
      this.refs.replaceNextButton.classList.remove('disabled');

      this.replaceTooltipSubscriptions.add(atom.tooltips.add(this.refs.replaceNextButton, {
        title: "Replace Next",
        keyBindingCommand: 'find-and-replace:replace-next',
        keyBindingTarget: this.replaceEditor.element
      }));
      this.replaceTooltipSubscriptions.add(atom.tooltips.add(this.refs.replaceAllButton, {
        title: "Replace All",
        keyBindingCommand: 'find-and-replace:replace-all',
        keyBindingTarget: this.replaceEditor.element
      }));
    } else {
      this.refs.replaceAllButton.classList.add('disabled');
      this.refs.replaceNextButton.classList.add('disabled');

      this.replaceTooltipSubscriptions.add(atom.tooltips.add(this.refs.replaceNextButton, {
        title: "Replace Next [when there are results]"
      }));
      this.replaceTooltipSubscriptions.add(atom.tooltips.add(this.refs.replaceAllButton, {
        title: "Replace All [when there are results]"
      }));
    }
  }

  createWrapIcon() {
    this.wrapIcon = document.createElement('div');
  }

  showWrapIcon(icon) {
    if (!atom.config.get('find-and-replace.showSearchWrapIcon')) return;
    let editor = this.model.getEditor();
    if (!editor) return;

    let editorView = atom.views.getView(editor);
    if (!editorView.parentNode) return;
    editorView.parentNode.appendChild(this.wrapIcon);

    this.wrapIcon.className = `find-wrap-icon ${icon} visible`;
    clearTimeout(this.wrapTimeout);
    this.wrapTimeout = setTimeout((() => this.wrapIcon.classList.remove('visible')), 500);
  }
};
