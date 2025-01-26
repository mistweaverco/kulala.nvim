" Syntax file for highlighting verbose response buffer of kulala.nvim
if exists("b:current_syntax")
  finish
endif

syntax clear

" Highlight connection details
syntax match ConnectionDetails /^\*.*$/ containedin=ALL
hi def link ConnectionDetails Comment

" Highlight IPv4 and IPv6 details
syntax match IPDetails /IPv[46]:.*/ containedin=ALL
hi def link IPDetails Number

" Highlight TLS handshake data
syntax match TLSHandshake /^\* TLSv[0-9]\.[0-9].*$/ containedin=ALL
hi def link TLSHandshake Identifier

" Highlight HTTP request and response headers
syntax match HTTPHeader /^\(>\|<\) .*$/ containedin=ALL
hi def link HTTPHeader Statement

" Highlight JSON response keys
syntax match JSONKey /"[^"]\+"\s*:/ containedin=ALL
hi def link JSONKey Type

" Highlight JSON response values
syntax match JSONValue /: \("[^"]*"\|[0-9]\+\|true\|false\|null\)/ containedin=ALL
hi def link JSONValue String

" Highlight server certificate information
syntax match CertificateInfo /^\*  \(subject\|issuer\|Certificate level\):.*/ containedin=ALL
hi def link CertificateInfo Constant

" Highlight HTTP body (form data or response body)
syntax match HTTPBody /\({.*}\|\[.*\]\)/ containedin=ALL
hi def link HTTPBody Special

" Highlight separators or data markers
syntax match DataMarker /\({\|}\|\[\|\]\)/ containedin=ALL
hi def link DataMarker SpecialChar

" Highlight XML tags
syntax match XMLTag /<\/?[a-zA-Z0-9_-]\+\( [^>]*\)?>/ containedin=ALL
hi def link XMLTag Keyword

" Highlight XML attributes
syntax match XMLAttribute /[a-zA-Z0-9_-]\+="[^"]*"/ containedin=ALL
hi def link XMLAttribute Identifier

" Highlight HTML tags (reuse XML)
syntax match HTMLTag /<\/?[a-zA-Z0-9_-]\+\( [^>]*\)?>/ containedin=ALL
hi def link HTMLTag Keyword

" Highlight HTML attributes (reuse XML)
syntax match HTMLAttribute /[a-zA-Z0-9_-]\+="[^"]*"/ containedin=ALL
hi def link HTMLAttribute Identifier

" Highlight plaintext sections
syntax match PlainText /[^<>{}"\[\]:]*$/ containedin=ALL
hi def link PlainText Normal

let b:current_syntax = "kulala_verbose_result"
