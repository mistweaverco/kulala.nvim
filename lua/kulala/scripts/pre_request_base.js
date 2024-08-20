const __fs = require('fs');
const __path = require('path');
const __REQUEST_VARIABLES_FILEPATH = __path.join(__dirname, 'request_variables.json');
const __GLOBAL_VARIABLES_FILEPATH = __path.join(__dirname, '..', 'global_variables.json');

const request = {};
request.variables = {};
request.variables.set = function (key, value) {
  let json = {};
  if (__fs.existsSync(__REQUEST_VARIABLES_FILEPATH)) {
    json = JSON.parse(__fs.readFileSync(__REQUEST_VARIABLES_FILEPATH));
  }
  json[key] = value;
  __fs.writeFileSync(__REQUEST_VARIABLES_FILEPATH, JSON.stringify(json));
}
request.variables.get = function (key) {
  let json = {};
  if (__fs.existsSync(__REQUEST_VARIABLES_FILEPATH)) {
    json = JSON.parse(__fs.readFileSync(__REQUEST_VARIABLES_FILEPATH));
  }
  return json[key];
};
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
