;Request
(request_separator
  value: (_) @keyword)

; Methods
(method) @function.method

; Headers
(header
  name: (_) @constant)

(header
  value: (_) @string)

; Variables
(identifier) @variable

(variable_declaration
  "@" @character.special)

(variable_declaration
  (value) @string)

(variable_declaration_inline
  "@" @character.special)

(variable_declaration_inline
  (value) @string)

; Commands
(command
  name: (_) @function.method
  value: (_) @keyword)

; Operators
(comment
  "=" @operator)

(metadata
  "=" @operator)

(variable_declaration
  "=" @operator)

; keywords
(metadata
  "@" @keyword
   name: (_) @keyword)

(metadata
  "@" @keyword
  name: (_) @keyword
  value: (_) @constant)

; Literals
(request
  url: (_) @string.special.url)

(http_version) @string.special

; Response
(status_code) @number

(status_text) @string

; Punctuation
[
  "{{"
  "}}"
  "{%"
  "%}"
] @punctuation.bracket

">" @punctuation.special

(header
  ":" @punctuation.delimiter)

; external JSON body
(external_body
  path: (_) @string.special.path)

; Comments
[
  (comment)
  (request_separator)
] @comment @spell

; Scripts
(pre_request_script
  (path) @property.special.path)

(res_handler_script
  (path) @property.special.path)
