import * as fs from 'fs';
import * as path from 'path';
const _REQUEST_FILEPATH = path.join(__dirname, '..', '..', 'request.json');
const _REQUEST_VARIABLES_FILEPATH = path.join(__dirname, 'request_variables.json');

type RequestVariables = Record<string, string>;

interface RequestJson {
  headers: Record<string, string>,
  headers_raw: Record<string, string>,
  body_raw: string,
  body_computed: string | undefined,
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

interface HeaderObject {
  name: () => string,
  getRawValue: () => string,
  tryGetSubstituted: () => string,
};

const getHeaderObject = (headerName: string, headerRawValue: string, headerValue: string | undefined): HeaderObject | null => {
  if (headerValue === undefined) {
    return null;
  }
  return {
    name: () => {
      return headerName
    },
    getRawValue: () => {
      return headerRawValue;
    },
    tryGetSubstituted: () => {
      return headerValue;
    },
  };
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
    getComputed: () => {
      return req.body_computed;
    },
  },
  headers: {
    findByName: (headerName: string) => {
      return getHeaderObject(headerName, req.headers_raw[headerName], req.headers[headerName]);
    },
    all: function (): HeaderObject[] {
      const h = [];
      for (const [key, value] of Object.entries(req.headers)) {
        const item = getHeaderObject(key, req.headers_raw[key], value);
        if (item !== null) {
          h.push(item);
        }
      }
      return h;
    },
  },
  environment: {
    getName: (name: string): string | null => {
      if (name in req.environment) {
        return req.environment[name];
      }
      return null;
    },
    get: (name: string): string | null => {
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
  skip: () => {
    Request.variables.set('__skip_request', "true");
  },
  iteration: () => {
    return Request.variables.get('__iteration');
  }
};

