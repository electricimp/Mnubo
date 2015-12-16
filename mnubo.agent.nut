// Copyright (c) 2015 SMS Diagnostics Pty Ltd
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Mnubo class for Squirrel (Electric Imp)
// 
// Initial version: 27-11-2015
// Author: Aron Steg 
//

// -----------------------------------------------------------------------------
class Mnubo {

    static version = [1,0,0];

    constructor() {
        const MNUBO_OAUTH2_SCOPE_ALL = 0;
        const MNUBO_OAUTH2_SCOPE_READ = 1;
        const MNUBO_OAUTH2_SCOPE_WRITE = 2;
    }

}


// -----------------------------------------------------------------------------
class Mnubo.AccessToken {

    requestedAt = null;
    value = null;
    type = null;
    expiresIn = null;
    jti = null;
    
    constructor(value, type, expiresIn, jti) {
        this.requestedAt = time();
        this.value = value;
        this.type = type;
        this.expiresIn = expiresIn;
        this.jti = jti;
    }
    
    function isValid() {
        return time() < this.requestedAt + this.expiresIn;
    }
}


// -----------------------------------------------------------------------------
class Mnubo.Client {
    
    owners = null;
    objects = null;
    events = null;
    search = null;
    
    options = null;
    
    token = null;
    
    constructor(options /* ClientOptions */) {
        
        if (typeof options != "table") options = {};
        
        this.options = options;
        if (!("env" in this.options)) {
            this.options.env <- "sandbox";
        }
        
        if (!("httpOptions" in this.options)) {
            this.options.httpOptions <- {
                "protocol": "https",
                "hostname": hostname(),
                "port": 443
            }
        }
        
        this.owners = Mnubo.Owners(this);
        this.objects = Mnubo.Objects(this);
        this.events = Mnubo.Events(this);
        // this.search = Mnubo.Search(this);
        
    }
    
    function hostname() {

        local part = "sandbox";
        if (this.options.env == "production") {
            part = "api";
        }
        
        return "rest." + part + ".mnubo.com";
    }
    
    function getAccessToken(scope = MNUBO_OAUTH2_SCOPE_ALL, callback = null) {

        if (typeof scope == "function") {
            callback = scope;
            scope = MNUBO_OAUTH2_SCOPE_ALL;
        }
        local id = this.options.id;
        local secret = this.options.secret;
        local payload = "grant_type=client_credentials&scope=";
        switch (scope) {
            case MNUBO_OAUTH2_SCOPE_READ:    
                payload += "READ"; 
                break;
            case MNUBO_OAUTH2_SCOPE_WRITE:   
                payload += "WRITE"; 
                break;
            case MNUBO_OAUTH2_SCOPE_ALL:
            default:
                payload += "ALL"; 
        }
        
        local options = {
            "path": "/oauth/token",
            "headers": {
                "Authorization" : "Basic " + http.base64encode(id + ":" + secret),
                "Content-Type" : "application/x-www-form-urlencoded",
                "Accept-Encoding" : "application/json"
            }
        };
        
        // Merge the default options into these local options without overriding anything
        merge(options, this.options);

        // Build the HTTPS request
        local protocol = ("protocol" in options.httpOptions) ? options.httpOptions.protocol : "https";
        local hostname = ("hostname" in options.httpOptions) ? options.httpOptions.hostname : hostname();
        local port = ("port" in options.httpOptions) ? options.httpOptions.port : 443;
        local url = protocol + "://" + hostname + ":" + port + options.path;
        local headers = options.headers;
        
        // Execute the POST method
        MnuboHTTPRetry.post(url, headers, payload).sendasync(function(res) {
            if (res.statuscode == 200) {
                local data = http.jsondecode(res.body);
                token = Mnubo.AccessToken(data.access_token, data.token_type, data.expires_in, data.jti);
            } else {
                token = null;
            }
            
            if (callback) callback(isAccessTokenValid());
        }.bindenv(this)) 

    }
    
    /**
     * Is the access token still valid?
     * @return {boolean} false if there is no access token or if it has expired.
     */
    function isAccessTokenValid() {
        return this.token != null && this.token.isValid();
    }
    
    function authenticate(callback) {
        if (isAccessTokenValid()) {
            if (callback) callback(true);
        } else {
            getAccessToken(callback);
        }
    }

    function authenticatedPromise(callback) {

        return Promise(function (fulfill, reject) {
            authenticate(function(success) {
                if (success) {
                    callback(fulfill, reject);
                } else {
                    reject({ "errorCode": 401, "message": "Authentication failed" });
                }
            }.bindenv(this));
        }.bindenv(this));
        
    }
    

    function buildHttpOptions(path, contentType = null) {
        
        local options = {
            "path": path,
            "headers": {
                "Authorization": "Bearer " + this.token.value,
                "Content-Type": contentType || "application/json"
            }
        };
    
        merge(options, this.options.httpOptions);
        
        // Build the HTTPS request
        local protocol = ("protocol" in options) ? options.protocol : "https";
        local hostname = ("hostname" in options) ? options.hostname : hostname();
        local port = ("port" in options) ? options.port : 443;
        options.url <- protocol + "://" + hostname + ":" + port + options.path;

        return options;
    }
    
    function merge(to, from) {
        foreach (k1,v1 in from) {
            if (k1 in to) {
                if (typeof to[v1] == "array" || typeof to[v1] == "table") {
                    foreach (k2,v2 in to[k1]) {
                        if (!(k2 in from[k1])) {
                            to[k1][k2] <- v2;
                        }
                    }
                }
            } else {
                to[k1] <- v1;
            }
        }
    }
    
    function datestr(timestamp = null) {
        if (timestamp == null) timestamp = time();
        local date = date(timestamp);
        return format("%4d-%02d-%02dT%02d:%02d:%02dZ", date.year, date.month+1, date.day, date.hour, date.min, date.sec);
    }
    
    function parser(callback) {
        return function(response) {
            local data = null;
            if ("content-type" in response.headers && response.headers["content-type"].find("application/json") != null) {
                data = http.jsondecode(response.body);
            }
            if (response.statuscode >= 200 && response.statuscode < 300) {
                if (callback) callback(true, data);
            } else {
                if (callback) callback(false, data);
            }
        }.bindenv(this)
    }
    
    function get(path, callback = null) {
        local options = this.buildHttpOptions(path);
        payload = http.jsonencode(payload);
        return MnuboHTTPRetry.get(options.url, options.headers).sendasync(parser(callback));
    }
    
    function post(path, payload, callback = null) {
        local options = this.buildHttpOptions(path);
        payload = http.jsonencode(payload);
        return MnuboHTTPRetry.post(options.url, options.headers, payload).sendasync(parser(callback));
    }
    
    function put(path, payload, callback = null) {
        local options = this.buildHttpOptions(path);
        payload = http.jsonencode(payload);
        return MnuboHTTPRetry.put(options.url, options.headers, payload).sendasync(parser(callback));
    }
    
    function remove(path, callback = null) {
        local options = this.buildHttpOptions(path);
        return MnuboHTTPRetry.request("delete", options.url, options.headers, "").sendasync(parser(callback));
    }

    
}


// -----------------------------------------------------------------------------
class Mnubo.Owners {
    
    path = null;
    client = null;
    
    constructor(client) {
        this.client = client;
        this.path = "/api/v3/owners";
    }

    function create(payload)  {
        return client.authenticatedPromise(function (fulfill, reject) {
            client.post(this.path, payload, function(success, response) {
                if (success) fulfill(response);
                else reject(response);
            }.bindenv(this));
        }.bindenv(this));
    }

    function update(username, payload) {
        return client.authenticatedPromise(function (fulfill, reject) {
            username = http.urlencode({ u=username }).slice(2);
            client.put(this.path + "/" + username, payload, function(success, response) {
                if (success) fulfill(response);
                else reject(response);
            }.bindenv(this));
        }.bindenv(this));
    }

    function remove(username) {
        return client.authenticatedPromise(function (fulfill, reject) {
            username = http.urlencode({ u=username }).slice(2);
            client.remove(this.path + "/" + username, function(success, response) {
                if (success) fulfill(response);
                else reject(response);
            }.bindenv(this));
        }.bindenv(this));
    }

    function claim(username, deviceId) {
        return client.authenticatedPromise(function (fulfill, reject) {
            username = http.urlencode({ u=username }).slice(2);
            deviceId = http.urlencode({ d=deviceId }).slice(2);
            client.post(this.path + "/" + username + "/objects/" + deviceId + "/claim", "", function(success, response) {
                if (success) fulfill(response);
                else reject(response);
            }.bindenv(this));
        }.bindenv(this));
    }
}


// -----------------------------------------------------------------------------
class Mnubo.Objects {
    
    path = null;
    client = null;
    
    constructor(client) {
        this.client = client;
        this.path = "/api/v3/objects";
    }

    function create(payload)  {
        return client.authenticatedPromise(function (fulfill, reject) {
            client.post(this.path, payload, function(success, response) {
                if (success) fulfill(response);
                else reject(response);
            }.bindenv(this));
        }.bindenv(this));
    }

    function update(deviceId, payload) {
        return client.authenticatedPromise(function (fulfill, reject) {
            deviceId = http.urlencode({ d=deviceId }).slice(2);
            client.put(this.path + "/" + deviceId, payload, function(success, response) {
                if (success) fulfill(response);
                else reject(response);
            }.bindenv(this));
        }.bindenv(this));
    }

    function remove(deviceId) {
        return client.authenticatedPromise(function (fulfill, reject) {
            deviceId = http.urlencode({ d=deviceId }).slice(2);
            client.remove(this.path + "/" + deviceId, function(success, response) {
                if (success) fulfill(response);
                else reject(response);
            }.bindenv(this));
        }.bindenv(this));
    }
}


// -----------------------------------------------------------------------------
class Mnubo.Events {
    
    path = null;
    client = null;
    
    constructor(client) {
        this.client = client;
        this.path = "/api/v3/events";
    }

    function send(payload)  {
        return client.authenticatedPromise(function (fulfill, reject) {
            client.post(this.path, payload, function(success, response) {
                if (success) fulfill(response);
                else reject(response);
            }.bindenv(this));
        }.bindenv(this));
    }

    function sendFromDevice(deviceId, payload) {
        return client.authenticatedPromise(function (fulfill, reject) {
            deviceId = http.urlencode({ d=deviceId }).slice(2);
            client.put("/api/v3/objects/" + deviceId + "/events", payload, function(success, response) {
                if (success) fulfill(response);
                else reject(response);
            }.bindenv(this));
        }.bindenv(this));
    }

}


/**********[ Mnubo HTTP Retry Class ]******************************************/
// The MnuboHTTPRetry class is mostly derived from the Electric Imp MnuboHTTPRetry class.
// https://github.com/electricimp/reference/tree/master/utility/httpplus
// It is tweaked slighly to meet the needs of the Mnubo class.
//
class MnuboHTTPRetry {

    _queue = null;
    _processing = false;

    constructor() {
        _queue = [];
        _processing = false;
    }
    
    function request(method, url, headers = {}, body = "") {
        local MnuboHTTPRetry = _factory();
        local params = [ method, url, headers, body ];
        return MnuboHTTPRetryRequest(MnuboHTTPRetry, http.request, params);
    }

    function get(url, headers = {}) {
        local MnuboHTTPRetry = _factory();
        local params = [ url, headers ];
        return MnuboHTTPRetryRequest(MnuboHTTPRetry, http.get, params);
    }

    function put(url, headers = {}, body = "") {
        local MnuboHTTPRetry = _factory();
        local params = [ url, headers, body ];
        return MnuboHTTPRetryRequest(MnuboHTTPRetry, http.put, params);
    }
    
    function post(url, headers = {}, body = "") {
        local MnuboHTTPRetry = _factory();
        local params = [ url, headers, body ];
        return MnuboHTTPRetryRequest(MnuboHTTPRetry, http.post, params);
    }
    
    function httpdelete(url, headers = {}) {
        local MnuboHTTPRetry = _factory();
        local params = [ url, headers ];
        return MnuboHTTPRetryRequest(MnuboHTTPRetry, http.httpdelete, params);
    }
    
    function _factory() {
        if (!("sharedMnuboHTTPRetry" in getroottable())) ::sharedMnuboHTTPRetry <- MnuboHTTPRetry();
        return ::sharedMnuboHTTPRetry;
    }
    
    function _enqueue(requestobj, callback) {
        _queue.push({requestobj=requestobj, callback=callback});
        _dequeue();
    }
    
    function _dequeue() {
        // Process the queue of non-long-polling requests
        if (_queue.len() > 0 && _processing == false) {
            local item = _queue[0];
            _processing = true;
            item.requestobj._sendasyncqueued(function(success, result, retry_delay=0) {
                if (success) {
                    _processing = false;
                    _queue.remove(0);
                    item.callback(result);
                    return _dequeue();
                } else {
                    imp.wakeup(retry_delay, function() {
                        _processing = false;
                        _dequeue();
                    }.bindenv(this));
                }
            }.bindenv(this));
        }
    }
    
    function _remove(requestobj) {
        foreach (k,v in _queue) {
            if (v.requestobj == requestobj) {
                _queue.remove(k);
                return k;
            }
        }
        return null;
    }
    
}


// -----------------------------------------------------------------------------
class MnuboHTTPRetryRequest {

    _parent = null;
    _request = null;
    _params = null;
    _retry = null;
    _httprequest = null;
    
    constructor(parent, request, params) {
        _parent = parent;
        _request = request;
        _params = params;
        _params.insert(0, http);
    }
    
    function _sendasyncqueued(callback) {

        _httprequest = _request.acall(_params);
        _httprequest.sendasync(function(result) {
            _httprequest = null;
            if (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
                // This is a retryable failure, wait for as long as are told then try again
                // server.error("HTTP request has been throttled. Queue: " + _parent._queue.len())
                callback(false, result, result.headers["retry-after"].tofloat());
            } else if (result.statuscode == 502 || result.statuscode == 503) {
                // Retry indefinitely in these cases
                callback(false, result, 1);
            } else {
                // This is a "success", so remove the item from the queue and start again
                callback(true, result);
            }
        }.bindenv(this));
    }
    
    function sendasync(oncomplete, longpolldata = null, longpolltimeout = 600) {
        if (longpolldata == null) {
            // Queue this request to be handled out of band
            _parent._enqueue(this, oncomplete);
        } else {
            // Handle a long-polling request. We can't queue it as it will block the whole queue.
            
            // Prepare the httprequest object
            _httprequest = _request.acall(_params);
            _httprequest.sendasync(function(result) {
                _httprequest = null;
                if (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
                    // This is a retryable failure, wait for as long as are told then try again
                    // server.error("HTTP long poll request has been throttled. Queue: " + _parent._queue.len())
                    _retry = imp.wakeup(result.headers["retry-after"].tofloat(), function() {
                        _retry = null;
                        sendasync(oncomplete, longpolldata, longpolltimeout);
                    }.bindenv(this))
                } else if (result.statuscode == 502 || result.statuscode == 503) {
                    // This is a retryable failure, wait a second and try again
                    _retry = imp.wakeup(1, function() {
                        _retry = null;
                        sendasync(oncomplete, longpolldata, longpolltimeout);
                    }.bindenv(this))
                } else {
                    // This is a success or a reportable failure
                    oncomplete(result);
                }
            }.bindenv(this), longpolldata, longpolltimeout);
        }
        return _httprequest;
    }
    
    function cancel() {
        if (_retry) {
            // Cancel the retry timer
            imp.cancelwakeup(_retry);
            _retry = null;
        } else if (_httprequest) {
            // Cancel the http request
            _httprequest.cancel();
            _httprequest = null;
        } else {
            // Pull it out of the queue
            _parent._remove(this);
        }
    }
    
}
