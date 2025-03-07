import * as fs from 'fs';
import * as path from 'path';
import { Assert  } from './Assert';

const _GLOBAL_VARIABLES_FILEPATH = path.join(__dirname, '..', 'global_variables.json');

const getGlobalVariables = (): Record<string, string> => {
  let json: Record<string, string> = {};
  if (fs.existsSync(_GLOBAL_VARIABLES_FILEPATH)) {
    json = JSON.parse(fs.readFileSync(_GLOBAL_VARIABLES_FILEPATH, { encoding: 'utf8' })) as Record<string, string>;
  }
  return json;
};

export const Client = {
  log: (...args: unknown[]): void => {
    console.log(...args);
  },
  test: (name: string, fn: () => void): void => {
    Assert.test(name, fn);
  },
  assert: Assert,
  exit: (): void => {
    process.exit();
  },
  global: {
    set: function (key: string, value: string) {
      const json = getGlobalVariables();
      json[key] = value;
      fs.writeFileSync(_GLOBAL_VARIABLES_FILEPATH, JSON.stringify(json));
    },
    get: function (key: string) {
      const json = getGlobalVariables();
      return json[key];
    },
    isEmpty: function () {
      const noItemsInObject = 0;
      const json = getGlobalVariables();
      return Object.keys(json).length === noItemsInObject;
    },
    clear: function (key: string) {
      const json = getGlobalVariables();
      // eslint-disable-next-line @typescript-eslint/no-dynamic-delete
      if (key in json) delete json[key];
      fs.writeFileSync(_GLOBAL_VARIABLES_FILEPATH, JSON.stringify(json));
    },
    clearAll: function () {
      fs.writeFileSync(_GLOBAL_VARIABLES_FILEPATH, '{}');
    }
  }
};

