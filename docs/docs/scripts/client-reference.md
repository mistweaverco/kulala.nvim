# Scripts client reference

These helper functions are available in the client object in scripts.

## client.global.set

Set a variable.

Variables are persisted across script runs and Neovim restarts.

```javascript
client.global.set("SOME_TOKEN", "123");
client.global.set("SOME.DEEP.VAR", "123");
```

## client.global.get

Get a variable.

Variables are persisted across script runs and Neovim restarts.

```javascript
client.global.get("SOME_TOKEN");
client.global.get("SOME.DEEP.VAR");
```

## client.log

Logs arbitrary data to the console.

```javascript
client.log("Hello, world!");
```

## client.test

Define a test suite and individual test cases within it.
See [Testing and Reporting](./../usage/testing-and-reporting.md) for more information.

## client.assert and client.assert.*

A collection of assertion functions to validate various aspects of the response.
See [Testing and Reporting](./../usage/testing-and-reporting.md) for more information.

## client.exit

Terminates execution of the response handler script.

```javascript
client.exit();
```
### client.isEmpty

Checks whether the `global` object has no variables defined.

```javascript
const isEmpty = client.isEmpty();
if (isEmpty) {
  client.log("No global variables defined");
}
```


## client.clear

Removes the `varName` variable from the global variables storage.

```javascript
client.clear("SOME_TOKEN");
```

## client.clearAll

Removes all variables from the global variables storage.

```javascript
client.clearAll();
```
