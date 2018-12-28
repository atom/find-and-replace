const {it, fit, ffit, beforeEach, afterEach} = require('./async-spec-helpers') // eslint-disable-line no-unused-vars

const BufferSearch = require('../lib/buffer-search')

describe('Find', () => {
	describe('updating the find model', () => {
		beforeEach(async () => {
			const activationPromise = atom.packages.activatePackage('find-and-replace')
			atom.commands.dispatch(atom.views.getView(atom.workspace), 'find-and-replace:show')
			await activationPromise

			spyOn(BufferSearch.prototype, 'setEditor')
		})

		it("sets the find model's editor whenever an editor is focused", async () => {
			let editor = await atom.workspace.open()
			expect(BufferSearch.prototype.setEditor).toHaveBeenCalledWith(editor)

			editor = await atom.workspace.open('sample.js')
			expect(BufferSearch.prototype.setEditor).toHaveBeenCalledWith(editor)
		})

		it("sets the find model's editor to null if a non-editor is focused", async () => {
			spyOn(atom.workspace, 'isTextEditor').andReturn(false)

			await atom.workspace.open()
			expect(BufferSearch.prototype.setEditor).toHaveBeenCalledWith(null)
		})
	})
})
