--- Abstract connection.
--
-- To add support for a new host environment, create a
-- class module with methods matching those listed here,
-- and insert it into `static.connection_classes`.
-- Moonwalk will call `connection:detect_host` on 
-- each module in that table. The first one to return a 
-- truthy value will be used as a base class for the `connection`.
--

local connection = {}
local unimplemented = 'this function is not implemented'

--- Static methods. Called on a "connection class,"
-- rather than an instance of one.
--
-- @section static
--

--- Detect the host environment. This function should check whether 
-- this connection class can support the current host environment.
-- If supported, return an appropriate name for the host environment,
-- otherwise return `nil`.
--
-- @return The name of the host environment if detected, else `nil`.
--
function connection:detect_host() 
  error(unimplemented)
end

--- Instance methods. Called on a connection instance.
--
-- @section static
--

--- Get the request method. Equivalent to CGI's
-- [REQUEST_METHOD](http://tools.ietf.org/html/rfc3875#section-4.1.12).
function connection:get_method()
  error(unimplemented)
end

--- Get the path info. Equivalent to CGI's
-- [PATH_INFO](http://tools.ietf.org/html/rfc3875#section-4.1.5).
--
-- This function should return the part of the path that follows
-- the script name in a CGI-style path. In other words,
-- the last part of the resource path, without the directory
-- the script is in. If the handler script is in the root path,
-- this should return "`/`".
--
-- For example, if you all rewrite requests for `/somewhere/...`
-- to `/somewhere/index.lua`, then the path info for a request to 
-- `/somewhere/something/123/` should be `/something/123/`
--
-- @return The path info.
-- @see connection:get_script
--
function connection:get_path()
  error(unimplemented)
end

--- Get the URI scheme.
--
-- @return The URI scheme. Should be `http` or `https`.
--
function connection:get_scheme()
  error(unimplemented)
end

--- Get the script's name. Equivalent to CGI's
-- [SCRIPT_NAME](http://tools.ietf.org/html/rfc3875#section-4.1.13).
--
-- This represents the path to the script that was requested,
-- relative to the web root.
--
-- For example, if you all rewrite requests for `/somewhere/...`
-- to `/somewhere/index.lua`, then the script for a request to 
-- `/somewhere/something/123/` should be `somewhere/index.lua`
--
-- @return The path to the script
-- @see connection:get_path
--
function connection:get_script()
  error(unimplemented)
end

--- Get the query string. Equivalent to CGI's
-- [QUERY_STRING](http://tools.ietf.org/html/rfc3875#section-4.1.7).
--
-- @return The query string.
--
function connection:get_query()
  error(unimplemented)
end

--- Get the value of an HTTP header.
--
-- @param name The name of the header.
-- @return String value of the header, or `nil` if the header wasn't found.
--
function connection:get_header(name) 
  error(unimplemented)
end

--- Send the response body.
--
-- This may be called multiple times per request after 
-- `connection:send_head` has been called. It should be
-- called at least once per request.
--
-- @param data A string containing (part of) the request body.
--
function connection:send(data) 
  error(unimplemented)
end

--- Send the response head.
--
-- This should only be called once per request.
--
-- @param status A string containing the HTTP status code and reason,
-- like `500 Internal Server Error`.
--
-- @param headers A table of header names and values.
--
function connection:send_head(status, headers) 
  error(unimplemented)
end

--- Receive the request body.
--
-- This may be called multiple times per request. 
-- It will be called at least once for each request
-- with a `Content-Length` header. When there is
-- no more data to receive, be sure to return `nil`.
--
-- @return String data received from consumer, or `nil`.
--
function connection:receive() 
  error(unimplemented)
end

return connection
