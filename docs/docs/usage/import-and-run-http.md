# Import and Run *.http files

Kulala lets you import HTTP requests from other .http files. You can:

- Run all HTTP requests from specified files
- Run specific HTTP requests from imported files
- Run specific HTTP requests from current file

## Usage

### Run all requests from another .http file

In your .http file, enter `run` followed by the name of another .http that you want to include. If the file is in the same directory, enter its name. Otherwise, specify a relative or absolute path to it. For example:

```http
run ./requests/get-requests.http
```

### Run specific requests from another .http file

At the top of your .http file, enter `import` followed by the name or path of another .http that contains necessary requests.
Enter `run` and specify the name of the request that you want to run prefixed with `#`. The name of the request is specified next to delimiter `###`, otherwise the `URL` without the http version is used.
To autocomplete available requests, use the `Ctrl-X Ctrl-U` shortcut.


```http get-requests.http
### Request 1

GET https://httpbin.org/advanced_1 HTTP/1.1

###

POST https://httpbin.org/advanced_2 HTTP/1.1
```

```http
import ./requests/get-requests.http

run #Request 1
run #POST https://httpbin.org/advanced_2
```

### Override variables from imported .http files

If the imported .http file contains variables, you can specify or change their values for specific executions.
Enter `run` and specify the name of an .http file or a request.

After the name of a request or a file, enter variables in the `(@variable=value)` format. To specify multiple variables, separate them by commas. For example:

```http
import new-requests.http

run #Request with one var (@host=example.com)

run #Request with two vars (@host=example.com, @user=userName)
```

:::info

- The `import` command is bound to the whole document, while the `run` command is bound to a request section.
- Nested imports are supported. You can import .http files that contain `import` and `run` from other .http files. 

:::

### Run specific requests from the current .http file

In the example below, when you run `#Request_one`, it will run the `Autenticate` request first, and then the `Request_one` request.

```http
### Autenticate
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/x-ndjson

< ./sample.ndjson



### Request_one

run #Autenticate

POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "results": [
    { "id": 1, "desc": "some_username" },
    { "id": 2, "desc": "another_username" }
  ]
}
```
