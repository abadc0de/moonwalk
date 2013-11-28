--- Swagger API Declarations and Resource Listings.
--
-- This module is a Moonwalk API `class`, and it follows the same
-- rules as any other API class, except that it doesn't show up in
-- the Resource Listing (so it won't appear in the API Explorer or
-- generated client code).

local api = require 'moonwalk/api'
local util = require 'moonwalk/util'
local memoize = require 'moonwalk/lib/memoize'

local resource_list_path = 'resources/'

--- Get the base path for requests.
--  
-- @return A fully-qualified URI.
--
local function get_base_path(connection)
  local host = connection:get_header 'Host'
  local scheme = connection:get_scheme()
  local path = connection:get_script():match '(.+)/' or ''
  
  return scheme .. '://' .. host .. path
end

local create_resource_listing = memoize(function(api)
  return {
    apiVersion = api.version,
    swaggerVersion = api.swagger_version,
    apis = api.info, -- process_api_info(),
  }
end)

local create_api_declaration = memoize(function(api, base, name)
  
  -- local api = connection.api
  -- local base = get_base_path(connection)
  -- local path = util.trim_path(connection.request.path)
  local resource_path = name
  
  local class = api.classes[resource_path]
  
  if not class then
    return nil, 'Resource does not exist', '404 Not Found'
  end

  local ops_by_path = {}
  local declaration = {
    apiVersion = api.version,
    swaggerVersion = api.swagger_version,
    basePath = base,
    resourcePath = '/' .. resource_list_path .. util.trim_path(resource_path),
    apis = {},
    models = {},
  }
  
  for key, op in pairs(class.operations) do 
    if type(op) == 'table' and op.decode_docblock then
      local path, info, models = op:decode_docblock(key, api)
      if path and info then
        if not ops_by_path[path] then ops_by_path[path] = {} end
        table.insert(ops_by_path[path], info)
        for k, v in pairs(models) do 
          declaration.models[k] = v
        end
      end
    end
  end
  
  for key, ops in pairs(ops_by_path) do 
    table.insert(declaration.apis, {
      path = key, 
      operations = ops,
      description = class.title,
    })
  end

  return declaration
end)

--- Operations. Each function is an API `operation`.
--
-- @section operations
--

return api.class("Swagger resources", {

  hide_api_info = true,

  --- Get a Swagger [API Declaration
  -- ](https://github.com/wordnik/swagger-core/wiki/API-Declaration).
  -- 
  -- **Path:**  
  -- `/resources/{name}/`
  --
  -- @param name The name of the API class.
  --
  -- @class function
  -- @name get_api_declaration
  get_api_declaration = api.operation([[
    @path GET /resources/{name}/
    @param name: The name of the API class.
  ]], function(name, connection)
    local api = connection.api
    local base = get_base_path(connection)
    local path = util.trim_path(connection.request.path)
    
    return create_api_declaration(api, base, name)
  end),

  --- Get a Swagger [Resource Listing
  -- ](https://github.com/wordnik/swagger-core/wiki/Resource-Listing).
  -- 
  -- **Path:**  
  -- `/resources/`
  --
  -- @class function
  -- @name get_resource_listing
  get_resource_listing = api.operation([[
    @path GET /resources/
  ]], function(connection)
    local api = connection.api
  
    return create_resource_listing(api)
  end),

})
