import * as fs from 'fs';
import * as path from 'path';
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
  global: {
    set: function (key: string, value: string) {
      const json = getGlobalVariables();
      json[key] = value;
      fs.writeFileSync(_GLOBAL_VARIABLES_FILEPATH, JSON.stringify(json));
    },
    get: function (key: string) {
      const json = getGlobalVariables();
      return json[key];
    }
  }
};
