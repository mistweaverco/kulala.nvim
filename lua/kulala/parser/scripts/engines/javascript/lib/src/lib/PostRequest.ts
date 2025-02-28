/* eslint-disable @typescript-eslint/no-unsafe-return */
/* eslint-disable @typescript-eslint/strict-boolean-expressions */
/* eslint-disable @typescript-eslint/consistent-type-assertions */
/* eslint-disable @typescript-eslint/no-unnecessary-condition */
/* eslint-disable @typescript-eslint/no-magic-numbers */
/* eslint-disable no-extra-boolean-cast */
/* eslint-disable @typescript-eslint/no-unsafe-assignment */
/* eslint-disable @typescript-eslint/no-unsafe-call */
/* eslint-disable @typescript-eslint/no-unsafe-member-access */
/* eslint-disable @typescript-eslint/no-explicit-any */
import * as fs from 'fs';
import * as path from 'path';
import { Response, type ResponseType, type ResponseBody } from './PostRequestResponse';

const _REQUEST_FILEPATH = path.join(__dirname, '..', '..', 'request.json');
const _REQUEST_VARIABLES_FILEPATH = path.join(__dirname, 'request_variables.json');
const _REQUEST_ASSERTS_FILEPATH = path.join(__dirname, '..', '..', 'request_asserts.json');

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


interface Asserts {
  testResults: Array<[string, number]>;
}

const getAsserts = (): Asserts => {
  const path = _REQUEST_ASSERTS_FILEPATH;
  let reqAsserts: Asserts = { testResults: [] };

  if (fs.existsSync(path)) {
    try {
      reqAsserts = JSON.parse(fs.readFileSync(path, { encoding: 'utf8' })) as Asserts;
    } catch (e) {
      console.log(e);
    }
  }
  return reqAsserts;
}

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
};

interface AssertFunction {
  (value: any, message?: string): void;
  true: (value: any, message?: string) => void;
  false: (value: any, message?: string) => void;
  same: (value: any, expected: any, message?: string) => void;
  hasString: (value: string, expected: string, message?: string) => void;
  responseHas: (key: string, expected: any, message?: string) => void;
  headersHas: (key: string, expected: any, message?: string) => void;
  bodyHas: (key: string, expected: any, message?: string) => void;
  jsonHas: (key: string, expected: any, message?: string) => void;
  save: (status: boolean, message?: string, expected?: any, value?: any) => void;
}

const getResponse = (): ResponseBody => {
  const response = Response as unknown as ResponseType;
  response.body = response.body ?? {} as ResponseBody;

  response.body.headers ??= {};
  response.body.body ??= {}; 
  response.body.json ??= {}; 

  return response.body;
}

const getNestedValue = (obj: any, path: string): any => {
  return path.split('.').reduce((prev, curr) => 
    prev && typeof prev === 'object' ? prev[curr] : undefined, obj);
}

export const Assert: AssertFunction = function (value:any, message?:string) {
  const status = Boolean(value);
  Assert.save(status, message);
};

Assert.true = function(value: any, message?: string) {
  const status = value === true;
  Assert.save(status, message, true, false);
};

Assert.false = function(value: any, message?: string) {
  const status = value === false;
  Assert.save(status, message, false, true);
};

Assert.same = function(value: any, expected: any, message?: string) {
  const status = value === expected;
  Assert.save(status, message, expected, value);
};

Assert.hasString = function(value: any, expected: string, message?: string) {
  const status = value === 'string' && value.includes(expected) === true;
  Assert.save(status, message, expected, value);
};

Assert.responseHas = function(key: string, expected: any, message?: string) {
  const response = getResponse() as unknown as Record<string, any>;
  const value = getNestedValue(response, key);
  const status = value === expected;

  Assert.save(status, message, expected, value);
};

Assert.headersHas = function(key: string, expected: any, message?: string) {
  const headers = getResponse().headers;
  const status = headers[key] === expected;
  Assert.save(status, message, expected, headers[key]);
};

Assert.bodyHas = function(key: string, expected: any, message?: string) {
  const body = getResponse().body;
  const value = getNestedValue(body, key);
  const status = value === expected;

  Assert.save(status, message, expected, value);
};

Assert.jsonHas = function(key: string, expected: any, message?: string) {
  const json = getResponse().json;
  const value = getNestedValue(json, key);
  const status = value === expected;

  Assert.save(status, message, expected, value);
};

Assert.save = function(status: boolean, message?: string, expected?: any, value?: any) {
  const statusStr = status ? 'succeeded' : 'failed';

  message = message ?? `Assertion ${statusStr}`;
  message += expected != null ? `: expected "${expected}", got "${value}"` : '';

  const code = Boolean(status) ? 0 : 1;

  try {
    const reqAsserts = getAsserts();

    reqAsserts.testResults.push([message, code]);
    fs.writeFileSync(_REQUEST_ASSERTS_FILEPATH, JSON.stringify(reqAsserts));

  } catch (e) {
    console.log(e);
  }
};
