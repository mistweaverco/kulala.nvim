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
(identifier) @variable (#set! priority 110)

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
(metadata
  "=" @operator)

(variable_declaration
  "=" @operator)

(variable_declaration_inline
  "=" @operator)

(operator) @operator

; keywords
(metadata
  "@" @character.special
   name: (_) @keyword)

(metadata
  "@" @character.special
  name: (_) @keyword
  value: (_) @constant)

; Literals
(query_param
  name: (_) @query_param.name)

(query_param
  name: (_) @query_param.name
  value: (_) @query_param.value)

(form_param
  name: (_) @form_param_name)

(form_param
  name: (_) @form_param_name
  value: (_) @form_param_value)

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

(external_body
  path: (_) @external_body_path)

; Multipart form data
(multipart_boundary_first) @keyword
(multipart_boundary) @keyword
(multipart_boundary_last) @keyword

; redirect
(res_redirect
  path: (_) @redirect_path)

; Comments
[
  (comment)
  (request_separator)
] @comment @spell

; Scripts
(pre_request_script
  (path) @number.special.path)

(res_handler_script
  (path) @number.special.path)
