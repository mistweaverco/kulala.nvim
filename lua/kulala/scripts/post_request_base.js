const __fs = require('fs');
const __path = require('path');
const __GLOBAL_VARIABLES_FILEPATH = __path.join(__dirname, '..', 'global_variables.json');
const __RESPONSE_HEADERS_FILEPATH = __path.join(__dirname, '..', '..', 'headers.txt');
const __RESPONSE_BODY_FILEPATH = __path.join(__dirname, '..', '..', 'body.txt');

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

const response = {};
response.body = null;
response.headers = {
  headers: {},
  valueOf: function (headerName) {
    return this.headers[headerName];
  },
  valuesOf: function (headerName) {
    const values = [];
    for (const key in this.headers) {
      if (key.toLowerCase() === headerName.toLowerCase()) {
        values.push(this[key]);
      }
    }
    return values;
  },
};
response.status = null;
response.contentType = {
  mimeType: null,
  charset: null,
};

if (__fs.existsSync(__RESPONSE_HEADERS_FILEPATH)) {
  const headers = __fs.readFileSync(__RESPONSE_HEADERS_FILEPATH, 'utf8');
  headers.split('\n').forEach(header => {
    const [key, _] = header.split(':');
    response.headers.headers[key] = header.split(':').slice(1).join(':').trim();
  });
}

if (__fs.existsSync(__RESPONSE_BODY_FILEPATH)) {
  response.body = __fs.readFileSync(__RESPONSE_BODY_FILEPATH, 'utf8');
  try {
    response.body = JSON.parse(response.body);
  } catch (e) {
    // do nothing
  }
}
