path = require "path"

# TODO: move this functionality to core. Other packages need it as well.
module.exports =
  splitProjectPath: (filePath) ->
    for projectPath in atom.project?.getPaths() ? []
      if filePath is projectPath or filePath.startsWith(projectPath + path.sep)
        return [projectPath, path.relative(projectPath, filePath)]
    return [null, filePath]
