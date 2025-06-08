/**
 * @file Kulala HTTP Parser
 * @author Yaro Apletov <yaro@dream-it.es>
 * @license MIT
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

const PREC = {
  VAR_COMMENT_PREFIX: 2,
  BODY_PREFIX: 2,
  RAW_BODY: 3,
  GRAPQL_JSON_PREFIX: 4,
  COMMENT_PREFIX: 5,
  REQ_SEPARATOR: 9,
};

const WORD_CHAR = /[\p{L}\p{N}]/u;
const PUNCTUATION = /[^\n\r\p{Z}\p{L}\p{N}]/u;
const WS = /\p{Zs}+/u;
const NL = token(choice("\n", "\r", "\r\n", "\0"));
const LINE_TAIL = token(seq(/.*/, NL));
const ESCAPED = token(/\\[^\n\r]/);
const COMMENT_PREFIX = token(
  prec(PREC.COMMENT_PREFIX, choice(/#\s*/, /\/\/\s*/)),
);

module.exports = grammar({
  name: "kulala_http",

  extras: (_) => [],
  conflicts: ($) => [
    [$.target_url],
    [$.raw_body],
    [$._raw_body],
    [$._section_content],
    [$.value],
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
    COMMENT_PREFIX: (_) => COMMENT_PREFIX,

    comment: ($) => choice($._plain_comment, $._var_comment),
    _plain_comment: (_) => seq(COMMENT_PREFIX, LINE_TAIL),
    _var_comment: ($) =>
      seq(
        COMMENT_PREFIX,
        token(prec(PREC.VAR_COMMENT_PREFIX, "@")),
        field("name", $.identifier),
        optional(
          seq(
            choice(WS, "="),
            optional(token(prec(1, WS))),
            field("value", $.value),
          ),
        ),
        NL,
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
        seq($.variable_declaration, optional($._section_content)),
        seq($.command, optional($._section_content)),
        seq($.pre_request_script, optional($._section_content)),
        // field to easily find request node in each section
        field("request", $.request),
        field("response", $.response),
      ),

    // LIST http verb is arbitrary and required to use vaultproject
    method: (_) =>
      /(OPTIONS|GET|HEAD|POST|PUT|DELETE|TRACE|CONNECT|PATCH|LIST|GRAPHQL|WEBSOCKET)/,

    http_version: (_) => prec.dynamic(1, token(prec(0, /HTTP\/[\d\.]+/))),

    _target_url_line: ($) =>
      repeat1(choice(WORD_CHAR, PUNCTUATION, $.variable, WS)),
    target_url: ($) =>
      seq($._target_url_line, repeat(seq(NL, WS, $._target_url_line))),

    status_code: (_) => /[1-5]\d{2}/,
    status_text: (_) =>
      /(Continue|Switching Protocols|Processing|OK|Created|Accepted|Non-Authoritative Information|No Content|Reset Content|Partial Content|Multi-Status|Already Reported|IM Used|Multiple Choices|Moved Permanently|Found|See Other|Not Modified|Use Proxy|Switch Proxy|Temporary Redirect|Permanent Redirect|Bad Request|Unauthorized|Payment Required|Forbidden|Not Found|Method Not Allowed|Not Acceptable|Proxy Authentication Required|Request Timeout|Conflict|Gone|Length Required|Precondition Failed|Payload Too Large|URI Too Long|Unsupported Media Type|Range Not Satisfiable|Expectation Failed|I'm a teapot|Misdirected Request|Unprocessable Entity|Locked|Failed Dependency|Too Early|Upgrade Required|Precondition Required|Too Many Requests|Request Header Fields Too Large|Unavailable For Legal Reasons|Internal Server Error|Not Implemented|Bad Gateway|Service Unavailable|Gateway Timeout|HTTP Version Not Supported|Variant Also Negotiates|Insufficient Storage|Loop Detected|Not Extended|Network Authentication Required)/,
    __body: ($) =>
      seq(
        repeat1($._blank_line),
        prec.right(
          repeat(
            choice(
              alias($._var_comment, $.comment),
              field(
                "body",
                choice(
                  $.raw_body,
                  $.multipart_form_data,
                  $.xml_body,
                  $.json_body,
                  $.graphql_body,
                  $._external_body,
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

    query_param: ($) =>
      prec.right(
        seq(
          field("key", $.value),
          optional(seq("=", optional(field("value", $.value)))),
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
        field("name", $.identifier),
        WS,
        "#",
        field("value", prec.left($.value)), // Add precedence here
        optional(
          seq(
            optional(WS),
            "(",
            optional(WS),
            optional(
              seq(
                $.variable_declaration_inline,
                repeat(
                  seq(
                    optional(WS),
                    ",",
                    optional(WS),
                    $.variable_declaration_inline,
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
        seq($.graphql_data, optional(alias($.graphql_json_body, $.json_body))),
      ),
    graphql_data: ($) =>
      seq(
        token(
          prec(
            PREC.BODY_PREFIX,
            seq(choice("query", "mutation"), WS, /.*\{/, NL),
          ),
        ),
        $._raw_body,
      ),
    graphql_json_body: ($) =>
      seq(token(prec(PREC.GRAPQL_JSON_PREFIX, /[{\[]\s+/)), $._raw_body),

    _external_body: ($) => seq($.external_body, NL),
    external_body: ($) =>
      seq(
        token(prec(PREC.BODY_PREFIX, "<")),
        optional(seq("@", optional(field("name", $.identifier)))),
        WS,
        field("path", $.path),
      ),

    multipart_form_data: ($) =>
      prec.right(
        seq(
          token(prec(PREC.BODY_PREFIX, "--")),
          token(prec(1, LINE_TAIL)),
          repeat(
            choice(
              $.comment,
              seq($.external_body, choice(WS, NL)),
              token(prec(2, /<[^\s@]/)),
              token(prec(2, "--")),
              token(prec(2, /[{\[]\s+/)),
              token(prec(1, LINE_TAIL)),
              token(prec(2, NL)),
            ),
          ),
        ),
      ),

    raw_body: ($) =>
      seq(
        choice(
          token(prec(1, seq(/.+/, NL))),
          seq(COMMENT_PREFIX, $._not_comment),
        ),
        optional($._raw_body),
      ),
    _raw_body: ($) =>
      seq(
        choice(
          token(prec(PREC.RAW_BODY, LINE_TAIL)),
          seq(COMMENT_PREFIX, $._not_comment),
        ),
        optional($._raw_body),
      ),
    _not_comment: (_) => token(seq(/[^@]*/, NL)),

    header_entity: (_) => /[\w\-]+/,
    identifier: (_) => /[A-Za-z_.\$\d\u00A1-\uFFFF-]+/,
    path: ($) =>
      prec.right(repeat1(choice(WORD_CHAR, PUNCTUATION, $.variable, ESCAPED))),
    value: ($) => repeat1(choice(WORD_CHAR, PUNCTUATION, $.variable, WS)),
    _blank_line: (_) => seq(optional(WS), token(prec(-1, NL))),
  },
});
