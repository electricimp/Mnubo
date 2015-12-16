// Copyright (c) 2015 SMS Diagnostics Pty Ltd
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Initial version: 05-12-2015
// Author: Aron Steg
//

#require "bullwinkle.class.nut:2.0.0"

/******************************************************************************/
class Application {
    
    bull = null;
    
    constructor() {
        
        // Initialise Bullwinkle
        bull = Bullwinkle();

        // Setup some event handlers
        bull.on("tempandhum", read_tempandhum.bindenv(this));
        bull.on("pressure", read_pressure.bindenv(this));

        // Start a timer to read the sensors regularly
        imp.wakeup(10, read_all.bindenv(this));
        
        // Notify the agent that we are online
        bull.send("boot", { "mac": imp.getmacaddress(), "wifi": imp.scanwifinetworks() } );
    }

    // This function is called by a timer. Do not call it directly
    function read_all() {
        imp.wakeup(300, read_all.bindenv(this));
        read_tempandhum();
        read_pressure();
    } 
    
    // Read the sensors and send the results to the agent
    function read_tempandhum(message = null, reply = null) {
        local readings = {
            "temp": math.rand(),
            "hum": math.rand()
        }
        bull.send("reading", readings);
        
        // If this was a HTTP request, then reply to it as well.
        if (reply) reply(readings);
    }
    
    // Read the sensors and send the results to the agent
    function read_pressure(message = null, reply = null) {
        
        local readings = {
            "pressure": math.rand()
        }
        bull.send("reading", readings);
        
        // If this was a HTTP request, then reply to it as well.
        if (reply) reply(readings);
    }
    
}

// Bootstrap the application
application <- Application();
