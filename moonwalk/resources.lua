--- Swagger API Declarations and Resource Listings.
--
-- This module is a Moonwalk API `class`, and it follows the same
-- rules as any other API class, except that it doesn't show up in
-- the Resource Listing (so it won't appear in the API Explorer or
-- generated client code).

local config = require 'moonwalk/config'
local api = require 'moonwalk/facade'
local parser = require 'moonwalk/parser'
local static = require 'moonwalk/static'
local util = require 'moonwalk/util'

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

local get_resource_listing = function()
  return {
    apiVersion = config.api_version,
    swaggerVersion = config.swagger_version,
    apis = static.api_info, -- process_api_info(),
  }
end

local get_api_declaration = function(connection)
  
  local base = get_base_path(connection)
  local path = util.trim_path(connection.request.path)
  local resource_path = path:gsub('^' .. resource_list_path, '')
  
  local class = static.api_classes[resource_path]
  
  if not class then
    return nil, 'Resource does not exist', '404 Not Found'
  end

  local ops_by_path = {}
  local declaration = {
    apiVersion = config.api_version,
    swaggerVersion = config.swagger_version,
    basePath = base,
    resourcePath = '/' .. resource_list_path .. util.trim_path(resource_path),
    apis = {},
    models = {},
  }
  
  local path, info, models
  
  for key, value in pairs(class) do 
    path, info, models = parser.parse_doc(key, value)
    if path and info then
      if not ops_by_path[path] then ops_by_path[path] = {} end
      table.insert(ops_by_path[path], info)
      for key, value in pairs(models) do 
        declaration.models[key] = value
      end
    end
  end
  
  for key, value in pairs(ops_by_path) do 
    table.insert(declaration.apis, {
      path = key, 
      operations = value,
      description = static.class_titles[class],
    })
  end

  return declaration
end

--- Operations. Each function is an API `operation`.
--
-- @section operations
--

return api.class "Swagger resources" {

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
  get_api_declaration = api.operation [[
    @path GET /resources/{name}/
    @param name: The name of the API class.
  ]] .. function(name, connection)
  
    return get_api_declaration(connection)
    
  end,

  --- Get a Swagger [Resource Listing
  -- ](https://github.com/wordnik/swagger-core/wiki/Resource-Listing).
  -- 
  -- **Path:**  
  -- `/resources/`
  --
  -- @class function
  -- @name get_resource_listing
  get_resource_listing = api.operation [[
    @path GET /resources/
  ]] .. function(name)
  
    return get_resource_listing()
  
  end,

}
