((string_content) @injection.content
  (#match? @injection.content "^[ \t\n]*[Ss][Ee][Ll][Ee][Cc][Tt]")
  (#set! injection.language "sql"))

((string_content) @injection.content
  (#match? @injection.content "^[ \t\n]*[Ii][Nn][Ss][Ee][Rr][Tt]")
  (#set! injection.language "sql"))

((string_content) @injection.content
  (#match? @injection.content "^[ \t\n]*[Uu][Pp][Dd][Aa][Tt][Ee]")
  (#set! injection.language "sql"))

((string_content) @injection.content
  (#match? @injection.content "^[ \t\n]*[Dd][Ee][Ll][Ee][Tt][Ee]")
  (#set! injection.language "sql"))

((string_content) @injection.content
  (#match? @injection.content "^[ \t\n]*[Cc][Rr][Ee][Aa][Tt][Ee]")
  (#set! injection.language "sql"))

((string_content) @injection.content
  (#match? @injection.content "^[ \t\n]*[Aa][Ll][Tt][Ee][Rr]")
  (#set! injection.language "sql"))

((string_content) @injection.content
  (#match? @injection.content "^[ \t\n]*[Dd][Rr][Oo][Pp]")
  (#set! injection.language "sql"))

((string_content) @injection.content
  (#match? @injection.content "^[ \t\n]*[Ww][Ii][Tt][Hh]")
  (#set! injection.language "sql"))
