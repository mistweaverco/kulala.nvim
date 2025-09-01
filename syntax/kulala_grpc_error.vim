" Highlight the word "ERROR"
syntax match ErrorHeader /^ERROR:/
highlight link ErrorHeader Error

" Highlight "Code", "Message", and "Details"
syntax match ErrorKey /^\s*\(Code\|Message\|Details\):/
highlight link ErrorKey WarningMsg

" Highlight numbers
syntax match ErrorNumber /\v\d+/
highlight link ErrorNumber Number

" Highlight JSON-like keys inside the details section
syntax match JsonKey /@\=\w\+\ze":/ containedin=ALL
highlight link JsonKey Error

" Highlight JSON-like values inside the details section
syntax match JsonValue /: \zs".\{-}"/ containedin=ALL
highlight link JsonValue String

" Highlight JSON-like structures (start and end braces)
syntax match JsonBrace /[{}]/
highlight link JsonBrace Delimiter

" Highlight strings (quoted text)
syntax match ErrorString /".\{-}"/ contained
highlight link ErrorString String

" Highlight all non-highlighted text as Title
syntax match DefaultText /./ contains=ALL
highlight link DefaultText Title
