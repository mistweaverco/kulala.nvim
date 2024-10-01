import * as fs from 'fs';
import * as path from 'path';
const _RESPONSE_HEADERS_FILEPATH = path.join(__dirname, '..', '..', 'headers.txt');
const _RESPONSE_BODY_FILEPATH = path.join(__dirname, '..', '..', 'body.txt');

interface HeaderObject {
  name: string,
  value: string,
};

type Headers = Record<string, HeaderObject>;
type Body = null | string | object;

let body: Body = null;
const headers: Headers = {};

if (fs.existsSync(_RESPONSE_HEADERS_FILEPATH)) {
  const bodyRaw = fs.readFileSync(_RESPONSE_HEADERS_FILEPATH, { encoding: 'utf8' })
  const lines = bodyRaw.split('\n');
  const delimiter = ":";
  for (const line of lines) {
    if (!line.includes(delimiter)) {
      continue;
    }
    const [key] = line.split(delimiter);
    const lkey = key.toLowerCase();
    headers[lkey] = {
      name: key,
      value: line.slice(key.length + delimiter.length).trim()
    }
  }
}

if (fs.existsSync(_RESPONSE_BODY_FILEPATH)) {
  const bodyRaw = fs.readFileSync(_RESPONSE_BODY_FILEPATH, { encoding: 'utf8' })
  try {
    body = JSON.parse(bodyRaw) as object;
  } catch (e) {
    body = bodyRaw;
  }
}

export const Response = {
  body,
  headers: {
    valueOf: (headerName: string): string | null => {
      const lkey = headerName.toLowerCase();
      if (lkey in headers) {
        return headers[lkey].value;
      }
      return null;
    },
    valuesOf: function (headerName: string): HeaderObject | null {
      const lkey = headerName.toLowerCase();
      if (lkey in headers) {
        return headers[lkey];
      }
      return null;
    },
    all: function (): Headers {
      return headers;
    },
  },
  contentType: {
    mimeType: null,
    charset: null,
  }
};

