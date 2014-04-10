module.exports =
  unescapeEscapeSequence: (string,  {unescapeBackslash}={}) ->
    string.replace /\\(.)/gm, (match, char) ->
      if char == 't'
        '\t'
      else if char == 'n'
        '\n'
      else if char == 'r'
        '\r'
      else if char == '\\'
        if unescapeBackslash
          '\\'
        else
          '\\\\'
      else
        match
