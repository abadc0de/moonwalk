--- Moonwalk core module. 
-- This module should contain everything API authors will need.
--

local connection = require 'moonwalk/connection'
local memoize = require 'moonwalk/lib/memoize'
local proto = require 'moonwalk/proto'

local class = require 'moonwalk/api/class'
local model = require 'moonwalk/api/model'
local operation = require 'moonwalk/api/operation'


local dump = require 'moonwalk/util'.dump

local api = {


  --- API definition classes.
  -- Each of these class constructors have the following special behavior:
  -- If the constructor is called with less than the documented number of
  -- arguments, it will return a *continuation object* that can be called
  -- or concatenated with any remaining arguments. This enables docstrings
  -- to be appended to operation functions as described in
  -- [DecoratorsAndDocstrings](http://lua-users.org/wiki/DecoratorsAndDocstrings),
  -- and it allows calling functions with only string and table literal
  -- arguments without any parentheses.
  --
  -- @section definition
  --

  --- Instantiate an API class. See `api.class` constructor.
  class = class,
  
  --- Instantiate an API model. See `api.model` constructor.
  model = model,
  
  --- Instantiate an API operation. See `api.operation` constructor.
  operation = operation,
  
  --- Configuration fields.
  --
  -- @section config
  --
  
  --- Connection modules.
  --
  -- A numeric table containing paths to implementations of
  --  `connection.abstract`.
  connection_modules = {
    'moonwalk/connection/cgi', -- CGI support.
    'moonwalk/connection/luanode', -- Experimental LuaNode support.
    'moonwalk/connection/mongoose', -- Mongoose and Civetweb support.
    'moonwalk/connection/socket', -- Support for built-in testing server.
  },
  
  --- Swagger version.
  --
  -- The version of the Swagger protocol being used. You probably don't
  -- need to change it.
  --
  -- Defaults to `'1.2'`.
  --
  swagger_version = '1.2',
  
  --- Your API's version number.
  --
  -- Defaults to `'1.0'`.
  --
  version = '1',
}

local registered_apis = {}

function api:constructor(id, connection_modules)

  if not id then id = 0 end
  
  if registered_apis[id] then return registered_apis[id] end
  registered_apis[id] = self
  
  if connection_modules then
    if type(connection_modules) == 'string' then
      self.connection_modules = { connection_modules }
    else
      self.connection_modules = connection_modules
    end
  end

  self.classes = {}
  self.info = {}
  self.models = {}
  self.operations = {}
end
  
--- Request handling functions. Call these from your controller.
-- Call `api:load_class` once for each `api.class` module, then call 
-- `api:handle_request`.
--
-- @section request
--
  
--- Create a `connection` base object suitable for the current
-- host environment.
--
-- @return A connection object that will be instantiated once per
-- request.
--
function api:create_connection()
  for _, path in ipairs(self.connection_modules) do
    local class = require(path)
    local hostname = class:detect_host()
    if hostname then 
      local conn = proto.extend(class, connection)
      conn.hostname = hostname
      conn.api = self
      return conn
    end
  end
  error 'could not detect host environment'
end

--- Instantiate a new `connection` object.
--
-- Creates an instance of the base object returned by `api:create_connection`.
-- @return The newly instantiated `connection` object.
function api:get_connection(hostdata)
  return self:create_connection()(hostdata)
end

--- handle the request.
function api:handle_request(hostdata)
  return self:create_connection()(hostdata):handle_request()
end

--- Load an API class.
--
-- Loads a module containing an `api.class` instance, and registers the class
-- with the API.
--
-- @usage local api = require "moonwalk"
-- api.load "transaction"
-- api.handle_request(...)
-- @param path The module path to the API class.
function api:load_class(path)

  if self.classes[path] then return end
  
  local source
  local class
  local file = io.open(path .. '.lua')
  
  if file then 
    source = file:read '*a'
    class = loadstring(source)()
  else
    class = require(path)
  end
  
  if not class.is_api_class then
    if not source then
      error(path .. " is not an api class")
    end
    
  end
  
  if not class.operations.hide_api_info then
    table.insert(self.info, {
      path = '/' .. path,
      description = class.title,
    })
  end
  
  self.classes[path] = class
end


return proto:extend(api)
