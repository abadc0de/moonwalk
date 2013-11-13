--- Moonwalk: Zero-friction REST APIs.
--
-- If you are using Moonwalk to create an API, the readme should cover
-- most of what you need to know. You may also want to have a look at
-- the docs for `moonwalk` and `config`.
--
-- @class module
-- @name moonwalk

local config = require 'moonwalk/config'
local connection = require 'moonwalk/connection'
local memoize = require 'moonwalk/lib/memoize'
local proto = require 'moonwalk/proto'
local static = require 'moonwalk/static'

table.insert(static.connection_classes, require 'moonwalk/connection/cgi')
table.insert(static.connection_classes, require 'moonwalk/connection/mongoose')
table.insert(static.connection_classes, require 'moonwalk/connection/luanode')
table.insert(static.connection_classes, require 'moonwalk/connection/socket')

-- detect supported host environment (cgi, mongoose)

local detect_host = memoize(function()
  for _, class in ipairs(static.connection_classes) do
    local name = class:detect_host()
    if name then 
      local host = proto.extend(class, connection)
      host.name = name
      return host
    end
  end
  error 'Moonwalk could not detect host environment'
end)



return {
  
  --- Load an API class.
  ---
  --- Mostly just a wrapper for `require`.
  --- 
  --- @usage local api = require "moonwalk"
  --- api.load "transaction"
  --- api.handle_request(...)
  --- @param name a `require`-style module name
  load = function(name)
  
    if static.api_classes[name] then return end
    
    local module = require(name)
    
    if not module.hide_api_info then
      table.insert(static.api_info, {
        path = '/' .. name,
        description = static.class_titles[module],
      })
    end
    
    static.api_classes[name] = module
  end,
  
  --- Describe an API class.
  ---
  --- Syntactic sugar to hook up short descriptions to funtion tables,
  --- and register them with moonwalk.
  ---
  --- @usage local api = require "moonwalk"
  --- api.class "Customer Transactions" {
  ---   post = api.operation [[ ...
  ---   ]] .. function(customer, amount) -- ...
  ---   end, 
  --- }
  --- @param docstring short description of the module
  --- @return function(obj)
  class = function(docstring)
    return function(obj) 
      if not static.class_titles[obj] then 
        static.class_titles[obj] = docstring
      end 
      return obj
    end
  end,
  
  --- Register a model definition.
  model = function(name, properties)
    local existing_model = static.models[name]
    local function insert(properties)
      static.models[name] = properties
      return properties
    end
    if properties then
      if existing_model then return existing_model end
      return insert(properties)
    else
      if existing_model then 
        return function() return existing_model end
      end
      return insert
    end
  end,
  
  --- Register an operation.
  operation = function(docstring, fn)
    local function insert(_, fn)
      if not static.operation_docs[fn] then 
        static.operation_docs[fn] = docstring
      end
      return fn
    end
    if fn then
      return insert(nil, fn)
    else
      return setmetatable({}, { __concat = insert })
    end
  end,
  
  --- get the current connection.
  get_connection = function(hostdata)
    return detect_host()(hostdata)
  end,
  
  --- handle the request.
  handle_request = function(hostdata)
    return detect_host()(hostdata):handle_request()
  end,
  
  --- Config options. See `moonwalk.config`.
  config = config,
  
}

