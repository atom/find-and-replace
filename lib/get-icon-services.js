const DefaultFileIcons = require('./default-file-icons')
const {Emitter, CompositeDisposable} = require('atom')

let iconServices
module.exports = function () {
  if (!iconServices) iconServices = new IconServices()
  return iconServices
}

class IconServices {
  constructor () {
    this.emitter = new Emitter()
    this.elementIcons = null
    this.elementIconDisposables = new CompositeDisposable()
    this.fileIcons = DefaultFileIcons
  }

  onDidChange (callback) {
    return this.emitter.on('did-change', callback)
  }

  resetElementIcons () {
    this.setElementIcons(null)
  }

  resetFileIcons () {
    this.setFileIcons(DefaultFileIcons)
  }

  setElementIcons (service) {
    if (service !== this.elementIcons) {
      if (this.elementIconDisposables != null) {
        this.elementIconDisposables.dispose()
      }
      if (service) { this.elementIconDisposables = new CompositeDisposable() }
      this.elementIcons = service
      return this.emitter.emit('did-change')
    }
  }

  setFileIcons (service) {
    if (service !== this.fileIcons) {
      this.fileIcons = service
      return this.emitter.emit('did-change')
    }
  }

  getIconClasses (view) {
    let iconClass = ''
    if (this.elementIcons) {
      this.waitToAttach(view).then(() => {
        if (!view.iconDisposable) {
          view.iconDisposable = new CompositeDisposable()
        }
        view.iconDisposable.add(this.elementIcons(view.refs.icon, view.filePath))
      })
    } else {
      iconClass = this.fileIcons.iconClassForPath(view.filePath, 'find-and-replace') || ''
      if (Array.isArray(iconClass)) {
        iconClass = iconClass.join(' ')
      }
    }
    return iconClass
  }

  async waitToAttach(view, delay = 10){
    if (view.refs && view.refs.icon instanceof Element) {
      return Promise.resolve()
    } else {
      await new Promise(done => setTimeout(done, delay))
      return this.waitToAttach(view, delay)
    }
  }
}
