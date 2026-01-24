/* eslint-disable @typescript-eslint/no-magic-numbers */
import * as fs from "fs";
import * as path from "path";

import { getObjectValueByPath, setObjectValueByPath } from "./Utils";

const _RESPONSE_HEADERS_FILEPATH = path.join(
  __dirname,
  "..",
  "..",
  "headers.txt",
);
const _RESPONSE_BODY_FILEPATH = path.join(__dirname, "..", "..", "body.txt");

interface HeaderObject {
  name: string;
  value: string[];
}

type Headers = Record<string, HeaderObject>;
type Body = null | string | object;

interface ResponseHeaders {
  valueOf: (headerName: string) => string | null;
  valuesOf: (headerName: string) => HeaderObject | null;
  all: () => Headers;
}

export interface ResponseType {
  responseCode: number;
  status: number;
  body: Body;
  headers: ResponseHeaders;
  contentType: object;
}

let responseCode = 0;
let status = 0;
let body: Body = null;
const headers: Headers = {};

if (fs.existsSync(_RESPONSE_HEADERS_FILEPATH)) {
  const bodyRaw = fs.readFileSync(_RESPONSE_HEADERS_FILEPATH, {
    encoding: "utf8",
  });
  const lines = bodyRaw.split("\n");
  const delimiter = ":";

  for (const line of lines) {
    if (!line.includes(delimiter)) {
      continue;
    }

    const [key] = line.split(delimiter);
    if (!(key in headers)) {
      headers[key] = {
        name: key,
        value: [],
      };
    }

    headers[key].value.push(line.slice(key.length + delimiter.length).trim());
  }

  if (lines[0].length > 0) {
    const matches = lines[0].match(/HTTP\/\d(?:\.\d)?\s+(\d+)/);
    responseCode = status = ((matches?.[1]) != null) ? parseInt(matches[1], 10) : 0;
  }
}

if (fs.existsSync(_RESPONSE_BODY_FILEPATH)) {
  const bodyRaw = fs.readFileSync(_RESPONSE_BODY_FILEPATH, {
    encoding: "utf8",
  });
  try {
    body = JSON.parse(bodyRaw) as object;
  } catch (e) {
    body = bodyRaw;
  }
}

export const Response: ResponseType = {
  responseCode,
  status,
  body,
  headers: {
    valueOf: (headerName: string): string | null => {
      if (headerName in headers) {
        return headers[headerName].value[0];
      }
      return null;
    },
    valuesOf: function (headerName: string): HeaderObject | null {
      if (headerName in headers) {
        return headers[headerName];
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
  },
};
