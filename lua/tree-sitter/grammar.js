/**
 * @file Kulala HTTP Parser
 * @author Yaro Apletov <yaro@dream-it.es>
 * @license MIT
 */

/// <reference types="./node_modules/tree-sitter-cli/dsl.d.ts" />
// @ts-check

const PREC = {
  VAR_COMMENT_PREFIX: 2,
  BODY_PREFIX: 2,
  RAW_BODY: 3,
  GRAPHQL_JSON_PREFIX: 4,
  COMMENT_PREFIX: 1,
  REQ_SEPARATOR: 9,
};

const WORD_CHAR = /[\p{L}\p{N}]/u;
const PUNCTUATION = /[^\n\r\p{Z}\p{L}\p{N}]/u;
const WS = /\p{Zs}+/u;
const NL = token(choice("\n", "\r", "\r\n", "\0"));
const LINE_TAIL = token(seq(/.*/, NL));
const ESCAPED = token(/\\[^\n\r]/);
const BOUNDARY_CHAR = /[^\s\n\r]/;
const COMMENT_PREFIX = token(
  prec(PREC.COMMENT_PREFIX, choice(/#\s*/, /\/\/\s*/)),
);

module.exports = grammar({
  name: "kulala_http",

  extras: (_) => [],
  conflicts: ($) => [
    [$.target_url], 
    [$._section_content], 
    [$.value], 
    [$.multipart_boundary, $.multipart_boundary_last]
  ],
  inline: ($) => [$._target_url_line, $.__body],

  rules: {
    document: ($) => repeat($.section),
    // NOTE: just for debugging purpose
    WORD_CHAR: (_) => WORD_CHAR,
    PUNCTUATION: (_) => PUNCTUATION,
    WS: (_) => WS,
    NL: (_) => NL,
    LINE_TAIL: (_) => LINE_TAIL,
    BOUNDARY_CHAR: (_) => BOUNDARY_CHAR,
    COMMENT_PREFIX: (_) => COMMENT_PREFIX,

    comment: ($) => $._plain_comment,
    _plain_comment: (_) => seq(COMMENT_PREFIX, LINE_TAIL),

    metadata: ($) =>
      prec(
        PREC.COMMENT_PREFIX + 1,
        seq(
          COMMENT_PREFIX,
          token(prec(PREC.VAR_COMMENT_PREFIX, "@")),
          field("name", $.identifier),

          optional(
            choice(
              // Case: @field=value
              prec.left(3, seq("=", optional(WS), field("value", $.value))),

              // Case: @field =value or @field = value
              prec.left(2, seq(WS, "=", optional(WS), field("value", $.value))),

              // Case: @field value
              prec.left(1, seq(WS, field("value", $.value))),

              // Just whitespace with no value
              prec.right(0, WS),
            ),
          ),

          NL,
        ),
      ),

    request_separator: ($) =>
      seq(
        token(prec(PREC.REQ_SEPARATOR, /###+\p{Zs}*/)),
        optional(token(prec(1, WS))),
        optional(field("value", $.value)),
        NL,
      ),

    section: ($) =>
      prec.right(
        choice(
          seq($.request_separator, optional($._section_content)),
          $._section_content,
        ),
      ),

    // NOTE: grammatically, each request section should contain only single `$.request` node
    // we are allowing multiple `$.request` nodes here to lower the parser size
    _section_content: ($) =>
      choice(
        seq($._blank_line, optional($._section_content)),
        seq($.comment, optional($._section_content)),
        seq($.metadata, optional($._section_content)),
        seq($.variable_declaration, optional($._section_content)),
        seq($.command, optional($._section_content)),
        seq($.pre_request_script, optional($._section_content)),
        field("request", $.request),
        field("response", $.response),
      ),

    // LIST http verb is arbitrary and required to use vaultproject
    method: (_) =>
      /(OPTIONS|GET|HEAD|POST|PUT|DELETE|TRACE|CONNECT|PATCH|LIST|GRAPHQL|GRPC|WEBSOCKET)/,

    http_version: (_) => prec.dynamic(1, token(prec(0, /HTTP\/[\d\.]+/))),

    target_url: ($) =>
      seq($._target_url_line, repeat(seq(NL, WS, $._target_url_line))),

    _target_url_line: ($) =>
      repeat1(
        choice(
          WORD_CHAR,
          PUNCTUATION,
          $.variable,
          $.query_string,
          $.fragment,
          WS,
        ),
      ),

    query_string: ($) =>
      prec.right(
        seq(
          choice("?", "&"),
          field("params", $.query_param),
          repeat(seq("&", field("params", $.query_param))),
          optional($.fragment),
        ),
      ),

    query_param: ($) =>
      prec.right(
        seq(
          field("name", $.query_param_name),
          optional(seq("=", optional(field("value", $.query_param_value)))),
        ),
      ),

    query_param_name: ($) =>
      prec.right(
        seq(
          choice(WORD_CHAR, $.variable, token(/[^\s\n\r=&#]/)),
          repeat(choice(
            WORD_CHAR,
            $.variable,
            token(/[^\s\n\r=&#]/),
            token(prec(1, /\s+[^\s\n\r=&#]/))
          ))
        )
      ),

    query_param_value: ($) =>
      prec.right(
        seq(
          choice(WORD_CHAR, $.variable, token(prec(1, /[^\n\r&#\s]/))),
          repeat(choice(
            WORD_CHAR,
            $.variable,
            token(prec(1, /[^\n\r&#\s]/)),
            token(prec(2, /[ \t]+[^\n\r&#\sH]/)),
            token(prec(2, /[ \t]+H[^T]/)),
            token(prec(2, /[ \t]+HT[^T]/)),
            token(prec(2, /[ \t]+HTT[^P]/)),
            token(prec(2, /[ \t]+HTTP[^\/]/))
          ))
        )
      ),

    fragment: ($) =>
      prec.right(seq("#", repeat1(choice(WORD_CHAR, PUNCTUATION, $.variable)))),

    status_code: (_) => /[1-5]\d{2}/,
    status_text: (_) =>
      /(Continue|Switching Protocols|Processing|OK|Created|Accepted|Non-Authoritative Information|No Content|Reset Content|Partial Content|Multi-Status|Already Reported|IM Used|Multiple Choices|Moved Permanently|Found|See Other|Not Modified|Use Proxy|Switch Proxy|Temporary Redirect|Permanent Redirect|Bad Request|Unauthorized|Payment Required|Forbidden|Not Found|Method Not Allowed|Not Acceptable|Proxy Authentication Required|Request Timeout|Conflict|Gone|Length Required|Precondition Failed|Payload Too Large|URI Too Long|Unsupported Media Type|Range Not Satisfiable|Expectation Failed|I'm a teapot|Misdirected Request|Unprocessable Entity|Locked|Failed Dependency|Too Early|Upgrade Required|Precondition Required|Too Many Requests|Request Header Fields Too Large|Unavailable For Legal Reasons|Internal Server Error|Not Implemented|Bad Gateway|Service Unavailable|Gateway Timeout|HTTP Version Not Supported|Variant Also Negotiates|Insufficient Storage|Loop Detected|Not Extended|Network Authentication Required)/,

    __body: ($) =>
      seq(
        repeat1($._blank_line),
        prec.right(
          repeat(
            choice(
              alias($.metadata, $.comment),
              field(
                "body",
                choice(
                  $.multipart_form_data,
                  $.xml_body,
                  $.json_body,
                  $.graphql_body,
                  $.form_urlencoded_body,
                  $._external_body,
                  $.raw_body,
                ),
              ),
              NL,
              $.res_handler_script,
              $.res_redirect,
            ),
          ),
        ),
      ),

    response: ($) =>
      prec.right(
        seq(
          $.http_version,
          WS,
          $.status_code,
          WS,
          optional($.status_text),
          NL,
          repeat(field("header", $.header)),
          optional($.__body),
        ),
      ),

    request: ($) =>
      prec.right(
        seq(
          optional(seq(field("method", $.method), WS)),
          field("url", $.target_url),
          optional(seq(WS, field("version", $.http_version))),
          NL,
          repeat(choice($.comment, field("header", $.header))),
          optional($.__body),
        ),
      ),

    header: ($) =>
      seq(
        field("name", $.header_entity),
        optional(WS),
        ":",
        optional(token(prec(1, WS))),
        optional(field("value", choice($.value))),
        NL,
      ),

    // {{foo}} {{$bar}} {{ fizzbuzz }}
    variable: ($) =>
      seq(
        token(prec(1, "{{")),
        optional(WS),
        field("name", $.identifier),
        optional(WS),
        token(prec(1, "}}")),
      ),

    pre_request_script: ($) =>
      seq("<", WS, choice($.script, $.path), token(repeat1(NL))),
    res_handler_script: ($) =>
      seq(
        token(prec(PREC.REQ_SEPARATOR, ">")),
        WS,
        choice($.script, $.path),
        token(repeat1(NL)),
      ),
    script: (_) =>
      seq(token(prec(1, "{%")), NL, repeat(LINE_TAIL), token(prec(1, "%}"))),

    res_redirect: ($) =>
      seq(
        token(prec(PREC.REQ_SEPARATOR, />>!?/)),
        WS,
        field("path", $.path),
        token(repeat1(NL)),
      ),

    variable_declaration: ($) =>
      seq(
        "@",
        field("name", $.identifier),
        optional(WS),
        "=",
        optional(token(prec(1, WS))),
        field("value", $.value),
        NL,
      ),

    variable_declaration_inline: ($) =>
      seq(
        "@",
        field("name", $.identifier),
        optional(WS),
        "=",
        optional(token(prec(1, WS))),
        field("value", $.value),
      ),

    command: ($) =>
      seq(
        field("name", alias(choice("run", "import"), $.command_name)),
        WS,
        field("value", prec.left($.value)), // Add precedence here
        optional(
          seq(
            optional(WS),
            "(",
            optional(WS),
            optional(
              seq(
                field("variable", $.variable_declaration_inline),
                repeat(
                  seq(
                    optional(WS),
                    ",",
                    optional(WS),
                    field("variable", $.variable_declaration_inline),
                  ),
                ),
              ),
            ),
            optional(WS),
            ")",
          ),
        ),
        NL,
      ),

    xml_body: ($) => seq(token(prec(PREC.BODY_PREFIX, /<[^\s@]/)), $._raw_body),

    json_body: ($) =>
      seq(token(prec(PREC.BODY_PREFIX, /[{\[]\s+/)), $._raw_body),

    graphql_body: ($) =>
      prec.right(
        seq(
          $.graphql_data,
          optional(alias($.graphql_json_body, $.json_body)),
          optional(alias($.graphql_external_body, $.external_body)),
        ),
      ),
    graphql_data: ($) =>
      seq(
        token(
          prec(
            PREC.BODY_PREFIX,
            seq(choice("query", "mutation"), WS, /[^\n]*(\n[^\n{(]*)*[\{\(]\s*/, NL),
          ),
        ),
        $._raw_body,
      ),
    graphql_json_body: ($) =>
      seq(token(prec(PREC.GRAPHQL_JSON_PREFIX, /[{\[]\s*/)), $._raw_body),

    graphql_external_body: ($) =>
      seq(
        token(prec(PREC.GRAPHQL_JSON_PREFIX, "<")),
        WS,
        field("path", $.path),
        NL,
      ),

    _external_body: ($) => seq($.external_body, NL),
    external_body: ($) =>
      seq(token(prec(PREC.BODY_PREFIX, "<")), WS, field("path", $.path)),

    multipart_form_data: ($) =>
      prec.right(2, prec(PREC.RAW_BODY + 1, 
        seq(
          $.multipart_boundary_first,
          repeat(choice(
            $.multipart_boundary,
            $.multipart_external_body,
            $.header,
            $.multipart_content_line,
            NL
          )),
          $.multipart_boundary_last
        )
      )),

    _multipart_body: ($) =>
      repeat1(choice(
        $.multipart_boundary,
        $.multipart_boundary_last,
        $.header,
        $.multipart_external_body,
        $.multipart_content_line,
        NL
      )),

    multipart_content_line: (_) =>
      seq(/[^\n\r-]+/, NL),

    multipart_external_body: ($) =>
      seq(
        token(prec(PREC.BODY_PREFIX + 1, "<")),
        WS,
        field("path", $.path),
        NL
      ),

    multipart_boundary_first: ($) =>
      seq(
        token(prec(PREC.BODY_PREFIX, /--/)),
        alias($._boundary_value, $.boundary_value),
        NL
      ),

    multipart_boundary: ($) =>
      seq(
        token(prec(PREC.BODY_PREFIX, /--/)),
        alias($._boundary_value, $.boundary_value),
        NL
      ),

    multipart_boundary_last: ($) =>
      prec.dynamic(3, seq(
        token(prec(PREC.BODY_PREFIX, /--/)),
        alias($._boundary_value, $.boundary_value),
        token(prec(100, /--[\t \n\r]/))
      )),

    _boundary_value: ($) =>
      prec.right(10, repeat1(choice($.variable, token(prec(1, /[^\s\n\r{]/))))),

    word_char: (_) => WORD_CHAR,
    punctuation: (_) => PUNCTUATION,
    ws: (_) => WS,
    form_urlencoded_body: ($) =>
      prec(1,
        prec.right(
          seq(
            field("params", alias($._form_param_first, $.form_param)),
            repeat(seq(alias("&", $.operator), optional(NL), field("params", $.form_param))),
            NL,
          )
        )
      ),

    _form_param_first: ($) =>
      seq(
        field("name", alias(token(prec(1, /[^\s\n\r=&#<{\[\]\}\-:,]+(\s+[^\s\n\r=&#<{\[\]\}\-:,]+)*/)), $.form_param_name)),
        alias("=", $.operator),
        optional(field("value", $.form_param_value)),
      ),

    form_param: ($) =>
      prec.right(
        seq(
          field("name", $.form_param_name),
          optional(seq(alias("=", $.operator), optional(field("value", $.form_param_value)))),
        ),
      ),

    form_param_name: ($) =>
      prec.right(
        seq(
          choice($.variable, token(/[a-zA-Z0-9_@.\[\]]/)),
          repeat(choice(
            $.variable,
            token(/[a-zA-Z0-9_@.\[\]]/),
            token(prec(1, /\s+[a-zA-Z0-9_@.\[\]]/))
          ))
        )
      ),

    form_param_value: ($) =>
      prec.right(
        seq(
          choice(WORD_CHAR, $.variable, token(prec(1, /[^\n\r&#\s]/))),
          repeat(choice(
            WORD_CHAR,
            $.variable,
            token(prec(1, /[^\n\r&#\s]/)),
            token(prec(2, /[ \t]+[^\n\r&#]/))
          ))
        )
      ),

    raw_body: ($) =>
      prec(2, seq(choice(
        token(prec(2, seq(/[^=\n\r\-<{\[]+/, NL))),
        token(prec(2, seq(/-[^-=\n\r]+/, NL)))
      ), optional($._raw_body))),
    _raw_body: ($) =>
      seq(choice(token(prec(PREC.RAW_BODY, LINE_TAIL))), optional($._raw_body)),
    _not_comment: (_) => token(seq(/[^@]*/, NL)),

    header_entity: (_) => /[\w\-]+/,
    identifier: (_) =>
      /[A-Za-z_.$\d\u00A1-\uFFFF-]+(\[[^\]]+\]|\.[A-Za-z_.$\d\u00A1-\uFFFF-]+|\([^)]*\))*/,
    path: ($) =>
      prec.right(repeat1(choice(WORD_CHAR, PUNCTUATION, $.variable, ESCAPED))),
    value: ($) => repeat1(choice(WORD_CHAR, PUNCTUATION, $.variable, WS)),
    _blank_line: (_) => seq(optional(WS), token(prec(-1, NL))),
  },
});
