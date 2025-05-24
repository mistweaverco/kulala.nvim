# Importing and exporting HTTP collections to and from Postman, OpenAPI, Bruno

Kulala comes with built-in support for importing and exporting HTTP collections to and from various formats like Postman, OpenAPI, and Bruno.

## Usage

### Importing

The import is provided by the formatter module which should be enabled in the options:

```lua
opts = { ui = { formatter = true } }
```

Import can be run either through `Convert to HTTP` code action, which is available in `json`, `yaml`, and `bruno` files, or directly 
with `require("kulala").import(from)` command, where `from=nil|"postman"|"openapi"|"bruno"`, while inside the buffer with the file to import.

The importer will try to detect the format automatically, but if it fails, you can specify it explicitly by passing the format as an argument.

### Exporting

Currently, Kulala supports exporting to Postman collections format only.

Export can be run either through `Export requests` code action, which is available in `http` and `rest` files, or directly 
with `require("kulala").export()` command, while inside the buffer with the HTTP collection to export.
