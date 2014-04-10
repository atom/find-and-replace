module.exports =
  unescapeEscapeSequence: (string,  {ignoreEscapedBackslash}={}) ->
    string.replace /\\(.)/gm, (match, char) ->
      if char == 't'
        '\t'
      else if char == 'n'
        '\n'
      else if char == 'r'
        '\r'
      else if char == '\\'
        if ignoreEscapedBackslash
          '\\\\'
        else
          '\\'
      else
        match
