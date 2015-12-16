// Copyright (c) 2015 SMS Diagnostics Pty Ltd
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Initial version: 27-11-2015
// Author: Aron Steg
//

#require "promise.class.nut:1.0.0"
#require "mnubo.agent.nut:1.0.0"

// Create a new client with client id and client secret
local client = Mnubo.Client({
    "id": ID,
    "secret": SECRET,
    "env": ENV
});

// These requests are queued and will always be delivered in order.

// Remove an existing user
client.owners
  .remove("user@example.com")
  .then(function(user) {
    server.log("owner deleted");
  });

// Create a new user
client.owners
  .create({
    "username": "user@example.com",
    "x_password": "password"
  })
  .then(function(user) {
    server.log(http.jsonencode(user));
  });

// Update the details of an user
client.owners
  .update("user@example.com", {
    "x_registration_date": Mnubo.Client.datestr()
  })
  .then(function(user) {
    server.log("owner updated");
  });


// Remove an object 
client.objects
  .remove("BA2DBC92-E24C-48D4-8F73-7748683E18CC")
  .then(function(object) {
    server.log("object deleted");
  });

// Create a new object
client.objects
  .create({
    "x_device_id": "BA2DBC92-E24C-48D4-8F73-7748683E18CC",
    "x_object_type": "fridge",
    "x_owner": {
      "username": "user@example.com"
    }
  })
  .then(function(object) {
      server.log(http.jsonencode(object));
  })

// Claim an object on behalf of a user
client.owners
  .claim("user@example.com", "BA2DBC92-E24C-48D4-8F73-7748683E18CC")
  .then(function(object) {
    server.log("object claimed");
  })

// Record an event by a device
client.events
  .send([{
    "x_object": {
        "x_device_id": "BA2DBC92-E24C-48D4-8F73-7748683E18CC",
    },
    "x_event_type": "test"
  }])
  .then(function(event) {
    server.log("event posted");
  })

