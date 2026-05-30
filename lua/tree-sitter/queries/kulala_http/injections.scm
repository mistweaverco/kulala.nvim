; Comments
((comment) @injection.content
  (#set! injection.language "comment"))

; Body
((json_body) @injection.content
  (#set! injection.language "json"))

((xml_body) @injection.content
  (#set! injection.language "xml"))

((graphql_data) @injection.content
  (#set! injection.language "graphql"))

; Inline script: `{% lang=lua` on the opening line
((script
  (script_body) @injection.content) @_script
  (#match? @_script "lang=lua")
  (#set! injection.include-children)
  (#set! injection.language "lua"))

; Inline script: `{% lang=ts` on the opening line
((script
  (script_body) @injection.content) @_script
  (#match? @_script "lang=ts")
  (#set! injection.include-children)
  (#set! injection.language "typescript"))

; Inline script (default: JavaScript)
((script
  (script_body) @injection.content) @_script
  (#not-match? @_script "lang=lua")
  (#not-match? @_script "lang=ts")
  (#set! injection.include-children)
  (#set! injection.language "javascript"))
