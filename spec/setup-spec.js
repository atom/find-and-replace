require('etch').setScheduler({
  updateDocument(callback) { callback(); },
  getNextUpdatePromise() { return Promise.resolve(); }
});
