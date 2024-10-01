import * as fs from 'fs';
import * as path from 'path';
const _REQUEST_FILEPATH = path.join(__dirname, '..', '..', 'request.json');
const _REQUEST_VARIABLES_FILEPATH = path.join(__dirname, 'request_variables.json');

type RequestVariables = Record<string, string>;

interface RequestJson {
  headers: Record<string, string>,
  body_raw: string,
  body: string | object,
  method: string,
  url_raw: string,
  url: string,
  environment: Record<string, string>,
};

const getRequestVariables = (): RequestVariables => {
  let reqVariables: RequestVariables = {};
  try {
    reqVariables = JSON.parse(fs.readFileSync(_REQUEST_VARIABLES_FILEPATH, { encoding: 'utf8' })) as RequestVariables;
  } catch (e) {
    // do nothing
  }
  return reqVariables;
};
const req = JSON.parse(fs.readFileSync(_REQUEST_FILEPATH, { encoding: 'utf8' })) as RequestJson;

export const Request = {
  body: {
    getRaw: () => {
      return req.body_raw;
    },
    tryGetSubstituted: () => {
      return req.body;
    },
  },
  headers: {
    findByName: (headerName: string) => {
      return req.headers[headerName];
    },
    all: function (): Record<string, string> {
      return req.headers;
    },
  },
  environment: {
    getName: (name: string): string | null => {
      if (name in req.environment) {
        return req.environment[name];
      }
      return null;
    }
  },
  method: req.method,
  url: {
    getRaw: () => {
      return req.url_raw;
    },
    tryGetSubstituted: () => {
      return req.url
    },
  },
  status: null,
  contentType: {
    mimeType: null,
    charset: null,
  },
  variables: {
    set: function (key: string, value: string) {
      const reqVariables = getRequestVariables();
      reqVariables[key] = value;
      fs.writeFileSync(_REQUEST_VARIABLES_FILEPATH, JSON.stringify(reqVariables));
    },
    get: function (key: string) {
      const reqVariables = getRequestVariables();
      if (key in reqVariables) {
        return reqVariables[key];
      }
      return null;
    }
  },
};

