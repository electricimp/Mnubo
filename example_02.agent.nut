// Copyright (c) 2015 SMS Diagnostics Pty Ltd
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Initial version: 05-12-2015
// Author: Aron Steg 
//
// To Do:
//
//    - Show multiple readings, queued in the device and delivered as a batch to mnubo
//    - Show automatic timestamp
//

#require "bullwinkle.class.nut:2.0.0"
#require "rocky.class.nut:1.2.3"
#require "promise.class.nut:1.0.0"
#require "mnubo.agent.nut:1.0.0"

/**********[ Application ]*****************************************************/
class Application {

    agentid = null;
    client = null;
    bull = null;
    rocky = null;
    
    constructor(id, secret, env) {

        agentid = split(http.agenturl(), "/").pop();
        
        // Create a new client with client id and client secret.
        client = Mnubo.Client({"id": id, "secret": secret, "env": env});
        bull = Bullwinkle();
        rocky = Rocky();

        // Setup the event handlers
        rocky.get("/", on_get_root.bindenv(this));
        rocky.post("/request", on_post_request.bindenv(this));
        bull.on("boot", on_boot.bindenv(this));
        bull.on("reading", on_reading.bindenv(this));
    }


    // Handle the incoming GET / hits
    // Nothing much to do here but respond with Hello
    function on_get_root(context) {
        context.send("Hello");
    }
        
    // Handle the incoming POST /request hits
    // The body should contain a JSON object and the Content-Type header should contain "application/json"
    // The only value currently expected in the body is "type" which is either "pressure" or "tempandhum".
    // NOTE: Protect your requests with some sort of authentication/authorisation.
    function on_post_request(context) {
        
        try {
            if ("type" in context.req.body) {
                local type = context.req.body.type;
                switch (type) {
                    case "pressure":
                    case "tempandhum":
                        // Notify mnubo that there was a request event
                        on_request(type, context.req);
                        
                        // Forward the request to the device and wait for a reply 
                        bull.send(type, context.req.body)
                            // When the reply arrives send it to the requestor
                            .onReply(function(message) {
                                context.send(200, message.data);
                            }.bindenv(this))
                            // When there is an error, send that to the requestor
                            .onFail(function(err, message, retry) {
                                context.send(500, err);
                            }.bindenv(this))
                        return 
                    default:
                        context.send(400, "Unknown request type: " + type)
                }
            } else {
                context.send(400, "Request type not provided")
            }
        } catch (e) {
            context.send(500, e);
        }

    }
    
    
    // Handle the "boot" message from the device
    // Notify mnubo of the new (or existing) agentid and mac address and send the first event
    function on_boot(message, reply) {
        
        local mac = message.data.mac;
        client.objects
            .create({
                "x_object_type": "example",
                "x_device_id": agentid,
                // "mac": mac,
                })
            .then(function (response) {
                server.log("Objects create success: " + http.jsonencode(response));
            }.bindenv(this))
            .fail(function (err) {
                server.log("Objects create failed: " + http.jsonencode(err));
            }.bindenv(this));
        
        client.events
            .send([{
                "x_object": {
                    "x_device_id": agentid,
                },
                "x_event_type": "boot",
                }])
            .then(function(response) {
                server.log("Event boot send success: " + http.jsonencode(response));
            }.bindenv(this))
            .fail(function (err) {
                server.log("Event boot send failed: " + http.jsonencode(err));
            }.bindenv(this));
        
        get_location(message.data.wifi);
    }
    

    // Send a request event to mnubo containing the HTTP request data    
    function on_request(type, req) {

        client.events
            .send([{
                "x_object": {
                    "x_device_id": agentid,
                },
                "x_event_type": "request",
                // "type": type,
                // "request": req 
                }])
            .then(function(response) {
                server.log("Event request send success: " + http.jsonencode(response));
            }.bindenv(this))
            .fail(function (err) {
                server.log("Event request send failed: " + http.jsonencode(err));
            }.bindenv(this));
        
    }
    
    
    // Handle the "reading" message from the device
    // Send the readings to mnubo as an event
    function on_reading(message, reply) {

        local reading = message.data;
        client.events
            .send([{
                "x_object": {
                    "x_device_id": agentid,
                },
                "x_event_type": "reading",
                // "reading": reading
                }])
            .then(function(response) {
                server.log("Event reading send success: " + http.jsonencode(response));
            }.bindenv(this))
            .fail(function (err) {
                server.log("Event reading send failed: " + http.jsonencode(err));
            }.bindenv(this));

    }
    
    
    // Sends the visible Wifi networks to Google to geolocate
    function get_location(wifis) {
        
        if (wifis.len() == 0) return server.log("No wifi networks detected, so can't geolocate.")

        // Build the URL and POST data
        local url = "https://maps.googleapis.com/maps/api/browserlocation/json?browser=electric-imp&sensor=false";
        local headers = {};
        foreach (newwifi in wifis) {
           
            local bssid = format("%s:%s:%s:%s:%s:%s", newwifi.bssid.slice(0,2), 
                                                      newwifi.bssid.slice(2,4), 
                                                      newwifi.bssid.slice(4,6), 
                                                      newwifi.bssid.slice(6,8), 
                                                      newwifi.bssid.slice(8,10), 
                                                      newwifi.bssid.slice(10,12));
            url += format("&wifi=mac:%s|ss:%d", bssid, newwifi.rssi);
            
       }
       
       // POST it to Google
       local req = http.get(url, headers).sendasync(function(res) {
    
            local err = null;
            if (res.statuscode == 200) {
                local json = http.jsondecode(res.body);
                if (!("status" in json)) {
                    err = format("Unexpected response from Google Location: %s", res.body);
                } else if (json.status == "OK") {
                    
                    // We have a location, update the client
                    // server.log("Location: " + http.jsonencode(json.location));
                    client.objects.update(agentid, {
                        "x_registration_latitude":  json.location.lat,
                        "x_registration_longitude": json.location.lng
                    })
                    .then(function(response) {
                        server.log("Object update location success: " + http.jsonencode(response));
                    }.bindenv(this)) 
                    .fail(function(err) {
                        server.log("Object update location failed: " + http.jsonencode(err));
                    }.bindenv(this)) 
                    
                } else {
                    err = format("Received status %s from Google Location", json.status);
                }
            } else {
                err = format("Received error response %d from Google Location", res.statuscode);
            }
            
            if (err) server.error(err);
           
        }.bindenv(this));
        
    }
        
}


// Bootstrap the application
application <- Application("id", "secret", "sandbox");

