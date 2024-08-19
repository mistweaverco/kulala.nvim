const __fs = require('fs');
const __path = require('path');
const __GLOBAL_VARIABLES_FILEPATH = __path.join(__dirname, '..', 'global_variables.json');

const client = {};
client.global = {};
client.global.set = function (key, value) {
  let json = {};
  if (__fs.existsSync(__GLOBAL_VARIABLES_FILEPATH)) {
    json = JSON.parse(__fs.readFileSync(__GLOBAL_VARIABLES_FILEPATH));
  }
  json[key] = value;
  __fs.writeFileSync(__GLOBAL_VARIABLES_FILEPATH, JSON.stringify(json));
};
client.global.get = function (key) {
  let json = {};
  if (__fs.existsSync(__GLOBAL_VARIABLES_FILEPATH)) {
    json = JSON.parse(__fs.readFileSync(__GLOBAL_VARIABLES_FILEPATH));
  }
  return json[key];
};
