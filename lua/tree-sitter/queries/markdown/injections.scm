;extends

((fenced_code_block
  (info_string
    (language) @_lang)
  (code_fence_content) @injection.content)
  (#eq? @_lang "http")
  (#set! injection.language "kulala_http"))
