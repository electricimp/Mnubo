# Mnubo Client 1.0.0

The Mnubo client is an Electric Imp agent side library for interfacing to the Mnubo API v3. It only supports the `ingestion` (insertion of records) features and not the `restitution` (searching the records) features.

**To add this library to your project, add `#require "mnubo.agent.nut:1.0.0"` to the top of your agent code.**
**This library is dependant on the Promise library. Please also add `#require "promise.class.nut:1.0.0"` to the top of your agent code.**

You can view the library's source code on [GitHub](https://github.com/electricimp/mnubo/tree/v1.0.0).
This class is ported from and designed to be as close as possible to the [JavaScript SDK](https://github.com/mnubo/mnubo-js-sdk). Refer to the JavaScript SDK for further information.

## Class Usage

### Constructor: Mnubo.Client(*ClientOptions*)

The Mnubo client class is instantiated with a table of client options. The following fields are available:

| key         | default         | notes                                                                               |
| ----------- | --------------- | ----------------------------------------------------------------------------------- |
| id          | none, mandatory | This is the `client_id` field, available in the [security section](https://sop.mtl.mnubo.com/apps/security?a=p#/) of the [mnubo dashboard](https://sop.mtl.mnubo.com/apps/).  |
| secret      | none, mandatory | This is the `client_secret` field, available in the [security section](https://sop.mtl.mnubo.com/apps/security?a=p#/) of the [mnubo dashboard](https://sop.mtl.mnubo.com/apps/).  |
| env         | "sandbox"       | Should be `sandbox` or `production` |
| httpOptions | see below       | Configuration of the HTTP client. See below for details.    |

#### httpOptions

| key         | default                       | notes                        |
| ----------- | ----------------------------- | -----------------------------|
| protocol    | https                         | Should be `http` or `https`  |
| port        | 443                           |                              |
| hostname    | rest.[sandbox/api].mnubo.com  |                              |

```squirrel
#require "promise.class.nut:1.0.0"
#require "mnubo.agent.nut:1.0.0"

// Instantiate an mnubo sandbox client with the default values.
const CLIENT_ID = ".....";
const CLIENT_SECRET = ".....";
const MNUBO_ENV = "sandbox";
client <- Mnubo.Client({"id": CLIENT_ID, "secret": CLIENT_SECRET, "env": MNUBO_ENV});
```

## Class Properties

### objects

The *objects* property holds the methods for inserting data about objects. These are usually a mapping of real-world devices. The class can *create*, *update* and *remove* objects. Each object is identified by a user-generated *deviceId* (commonly the mac address or agentId of the imp).


```squirrel
// Create a new object
agentid <- split(http.agenturl(), "/").pop();
client.objects
  .create({
      "x_device_id": agentid,
      "x_object_type": "widget",
  })
  .then(function(response) {
    server.log("Object creation was successful");
  });
```

### events

The *events* object holds the functions for inserting data about (usually time sensitive) events that have taken place. The class can *send* (multiple) events when they are not attached to a device and *sendFromDevice* when the events are directly associated with a device.


```squirrel
// Record an event by a device
client.events
  .sendFromDevice(agentid, [
    { "x_event_type": "boot" }
  ])
  .then(function(response) {
    server.log("Event sending was successful");
  })
```

### owners

The *owners* object holds the functions for inserting data about the end-user. The class can *create*, *update* and *remove* owners plus it can *claim* objects for the owner. Owners are identified by an email address.

```squirrel
// Create a new user
client.owners
  .create({
    "username": "user@example.com",
    "x_password": "password"
  })
  .then(function(success, response) {
    server.log("Owner creation was successful");

    // Claim an object on behalf of a user
    client.owners
      .claim("user@example.com", agentid)
      .then(function(response) {
        server.log("Object claim was successful");
      }.bindenv(this));

  }.bindenv(this))
```

## Authentication

The authentication is wrapped for every API call. The library will first fetch a new Access Token and make the API call. There is nothing to do from a developer's perspective besides setting the client id, client secret and environment during initialization.

## API Calls

All the API calls return a [Promise](https://developer.mozilla.org/en-US/docs/Mozilla/JavaScript_code_modules/Promise.jsm/Promise).

- When a promise is successful, you can call the `.then()` function to get the data returned by the mnubo servers. If there is no data, the value is `null`. ex: `client.events.send({...}).then(function(data) { server.log(http.jsonencode(data)); });`

- When a promise is fails, you can call the `.fail()` function to get the error returned by the mnubo servers. If there is no data, the value is `null`. ex: `client.events.send({...}).fail(function(data) { server.log(http.jsonencode(data)); });`

If you are not familiar with promises, there is an excellent article on [html5rocks](http://www.html5rocks.com/en/tutorials/es6/promises/).


## Examples

There are further examples in the [GitHub repository](https://github.com/electricimp/mnubo/tree/v1.0.0).

# License

The Mnubo class is licensed under the [MIT License](./LICENSE.txt).
