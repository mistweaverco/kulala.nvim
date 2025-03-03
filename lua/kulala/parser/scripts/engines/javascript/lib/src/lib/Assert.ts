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
import { Response, type ResponseType } from './PostRequestResponse';

const _REQUEST_ASSERTS_FILEPATH = path.join(__dirname, '..', '..', 'request_asserts.json');

interface AssertResult {
  name: string;
  message: string;
  status: boolean;
};

interface Asserts {
  results: AssertResult[];
  status: boolean;
}

interface AssertFunction {
  testSuite: string;
  test: (name: string, fn: () => void) => void;

  (value: any, message?: string): void;

  true: (value: any, message?: string) => void;
  false: (value: any, message?: string) => void;
  same: (value: any, expected: any, message?: string) => void;
  hasString: (value: string, expected: string, message?: string) => void;
  responseHas: (key: string, expected: any, message?: string) => void;
  headersHas: (key: string, expected: any, message?: string) => void;
  bodyHas: (expected: string, message?: string) => void;
  jsonHas: (key: string, expected: any, message?: string) => void;
  save: (status: boolean, message?: string, expected?: any, value?: any) => void;
}

const getAsserts = (): Asserts => {
  const path = _REQUEST_ASSERTS_FILEPATH;
  let asserts: Asserts = { results: [], status: true };

  if (fs.existsSync(path)) {
    try {
      asserts = JSON.parse(fs.readFileSync(path, { encoding: 'utf8' })) as Asserts;
    } catch (e) {
      console.log(e);
    }
  }
  return asserts;
}

const getResponse = (): ResponseType => {
  const response = Response;
  return response;
}

const getNestedValue = (obj: any, path: string): any => {
  return path.split('.').reduce((prev, curr) => 
    prev && typeof prev === 'object' ? prev[curr] : undefined, obj);
}

export const Assert: AssertFunction = function (value:any, message?:string) {
  const status = Boolean(value);
  Assert.save(status, message);
};

Assert.testSuite = '';

Assert.test = function (name: string, fn: () => void) {
  Assert.testSuite = name ?? 'Test Suite';
  try {
    fn();
  } catch (e) {
    console.log(e);
  }
  Assert.testSuite = ''
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

Assert.hasString = function(value: string, expected: string, message?: string) {
  const status = typeof value === 'string' && value.includes(expected);
  const shortValue = value.length > 50 
    ? value.substring(0, 47) + '...' 
    : value;

  Assert.save(status, message, expected, shortValue);
};

Assert.responseHas = function(key: string, expected: any, message?: string) {
  const response = getResponse() as unknown as Record<string, any>;
  const value = response[key];
  const status = value === expected;

  Assert.save(status, message, expected, value);
};

Assert.headersHas = function(key: string, expected: any, message?: string) {
  const headers = getResponse().headers;
  const value = headers.valueOf(key);
  const status = value === expected;

  Assert.save(status, message, expected, value);
};

Assert.bodyHas = function(expected: string, message?: string) {
  const body = getResponse().body as string;
  Assert.hasString(body, expected, message);
};

Assert.jsonHas = function(key: string, expected: any, message?: string) {
  const json = getResponse().body;
  let status = false;
  let value = null;

  if (typeof json === 'object') {
    value = getNestedValue(json, key);
    status = value === expected;
  }

  Assert.save(status, message, expected, value);
};

Assert.save = function(status: boolean, message?: string, expected?: any, value?: any) {
  const statusStr = status ? 'succeeded' : 'failed';
  const name = Assert.testSuite ?? '';

  message = message ?? `Assertion ${statusStr}`;
  message += expected != null ? `: expected "${expected}", got "${value}"` : '';

  try {
    const asserts = getAsserts();

    asserts.results.push({name, message, status});
    asserts.status = asserts.status && status;

    fs.writeFileSync(_REQUEST_ASSERTS_FILEPATH, JSON.stringify(asserts));

  } catch (e) {
    console.log(e);
  }
};
