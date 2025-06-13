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

((metadata
  name: (_) @_name
  (#eq? @_name "lang")
  value: (_) @injection.language)?
  .
  (_
    (script) @injection.content
        (#match? @injection.content "-- lua")
    (#offset! @injection.content 0 2 0 -2))
  (#set! injection.language "lua"))

; Script (default to javascript)
((metadata
  name: (_) @_name
  (#eq? @_name "lang")
  value: (_) @injection.language)?
  .
  (_
    (script) @injection.content
    (#not-match? @injection.content "-- lua")
    (#offset! @injection.content 0 2 0 -2))
  (#set! injection.language "javascript"))
