-- Moonwalk: Swagger server for Lua. 
--
-- See README.md for info and license.

local config = require 'moonwalk/config'
local util = require 'moonwalk/util'
local proto = require 'moonwalk/proto'

local memoize = require 'moonwalk/lib/memoize'

local unpack = table.unpack or unpack

-- various storage tables
local API_INFO = {}
local API_MODULES = {}
local OPERATION_DOCS = {}
local MODULE_TITLES = {}
local MODELS = {}
local KNOWN_HOSTS = {}

-- magical annotation concatenation
-- http://lua-users.org/wiki/DecoratorsAndDocstrings

local OPERATION_META = {
  __concat = function(t, fn)
    if not OPERATION_DOCS[fn] then OPERATION_DOCS[fn] = t[1] end
    return fn
  end
}

local function abstract() error 'this function is not implemented' end

-- Connection pseudoclass

-- To add support for a new host environment, create a
-- new script returning a table of methods overriding
-- those listed below.

-- Add a function to KNOWN_HOSTS (moonwalk.known_hosts)
-- keyed by your script's module name. This function
-- should return a truthy value if it detects your host.

-- Uses an OOP style to suit environments like LuaNode,
-- where hostdata must be passed around everywhere.

local Connection = proto {

  get_request_info = abstract,
  get_header = abstract,
  get_base_path = abstract,
  send_head = abstract,
  send = abstract,
  receive = abstract,
  
}

KNOWN_HOSTS['moonwalk/host/cgi'] = function()
  local version = os.getenv 'GATEWAY_INTERFACE'
  return version
end

KNOWN_HOSTS['moonwalk/host/mongoose'] = function()
  local version = tonumber(_G.mg and _G.mg.version)
  if not version then return end
  -- TODO: in the future we should have better ways to
  -- tell Mongoose and Civetweb apart.
  local name = version > 3 and 'Mongoose' or 'Civetweb'
  return version and name .. ' ' .. version
end

KNOWN_HOSTS['moonwalk/host/luanode'] = function()
  local version = _G.process and _G.process.version
  local loaded = package.loaded['luanode.http']
  return version and loaded and 'LuaNode ' .. version
end

KNOWN_HOSTS['moonwalk/host/socket'] = function()
  local version = _G.MOONWALK_SOCKETSERVER_VERSION
  return version and 'Moonwalk SocketServer ' .. version
end

-- detect supported host environment (cgi, mongoose)

local detect_host = memoize(function()
  for path, fn in pairs(KNOWN_HOSTS) do
    local name = fn()
    if name then 
      local HostConnection = Connection:extend(require(path))
      HostConnection.name = name
      return HostConnection
    end
  end
  error 'Moonwalk could not detect host environment'
end)

-- finalize a model definition and insert it into a table.
local finalize_model = memoize(function(name)

  local m = MODELS[name]
  local require_props = config.model_properties_required
  local required = {}
  local ref_models = {}
  
  if not m then return end
  
  -- allow model definitions to consist only of property definitions.
  if not m.properties then
    m = { properties = m }
    MODELS[name] = m
  end
  
  -- ensure the model's id is the same as its key.
  m.id = name
  
  -- iterate through property definitions
  for k, v in pairs(m.properties) do
    -- default data type is string
    if not v.type then v.type = 'string' end
    -- allow optional/required in property definitions 
    if require_props then
      if v.optional then
        v.optional = nil
      else
        table.insert(required, k)
      end
    else
      if v.required then
        v.required = nil
        table.insert(required, k)
      end
    end
    -- if this model references another, insert it into the table also.
    table.insert(ref_models, v.type)
    -- insert_model(v.type, finalize_model(v.type))
  end
  
  -- if model properties are required by default, or the "required" property
  -- is being used in property definitions, overwrite the "required" array 
  -- (if it exists) with our new values.
  if #required > 0 then m.required = required end

  return m, ref_models

end)

-- finalize a model definition and insert it into a table.
local function insert_model(name, t)
  if (not t) or t[name] then return end
  -- insert the model into the target table
  local model, related = finalize_model(name)
  if model and related then
    t[name] = model
    for _, v in ipairs(related) do insert_model(v, t) end
  end
end

-- parse doc block for function into a Swagger-ready table.
-- returns the resource path (as defined by the @path tag) and the table.
-- http://json-schema.org/latest/json-schema-validation.html
local parse_doc = memoize(function(name, fn)

  local doc = OPERATION_DOCS[fn]
  local referenced_models = {}
  
  if not doc then return end
  
  -- remove indentation
  doc = doc:gsub('\n' .. (doc:match '\n(%s+)%a' or ''), '\n')
  
  local summary = doc:match '%s+(.-)%s*\n%s*\n' or ''
  local notes = doc:match '%s+.-%s*\n%s*\n(.-)%s*@' or ''
  local path = doc:match '@path%s+%a+%s+([^\n%s]+)'
  local method = doc:match '@path%s+(%a+)'
  local return_type = doc:match '@return%s+.-(%a+)'
  local params = {}
  
  local function format(s)
    return s:gsub('{nickname}', name)
        :gsub('{summary}', summary)
        :gsub('{notes}', notes)
  end
  
  -- markdown the "notes" section
  if config.use_markdown and notes ~= '' then
    local markdown = require "moonwalk/lib/markdown"
    notes = markdown(notes)
  end
  
  -- parse all @param tags
  for v in doc:gmatch '@param(.-)%f[@$]' do
    local _, name_end, paren_end
    local p = {}
    local patterns = {
      default = '[(].-default%s+`([^`]+)`.-[)]',
      from = '[(].-from%s+(%a+).-[)]',
      format = '[(].-format%s+(%w_-).-[)]',
      optional = '[(].-(optional).-[)]',
      -- numbers
      maximum = '[(].-maximum%s+([%d.-]+).-[)]',
      minimum = '[(].-minimum%s+([%d.-]+).-[)]',
      multipleOf = '[(].-multipleOf%s+(%d+).-[)]',
      -- strings
      maxLength = '[(].-maxLength%s+(%d+).-[)]',
      minLength = '[(].-minLength%s+(%d+).-[)]',
      pattern = '[(].-pattern%s+`([^`]+)`.-[)]',
      -- arrays
      maxItems = '[(].-maxItems%s+(%d+).-[)]',
      minItems = '[(].-minItems%s+(%d+).-[)]',
      uniqueItems = '[(].-(uniqueItems).-[)]',
    }
    
    _, name_end, p.name = v:find '.-([%w_-]+)'
    _, paren_end = v:find '[)]'
    p.description = v:match('([^%p%s].-)\n*$', (paren_end or name_end) + 1)
    p.dataType = v:match '[(]([%w_-]+).-[)]'
    p.default = v:match(patterns.default)
    p.paramType = v:match(patterns.from)
    p.format = v:match(patterns.format)
    p.required = not v:match(patterns.optional) and true or nil
    -- numbers
    p.maximum = tonumber(v:match(patterns.maximum))
    p.minimum = tonumber(v:match(patterns.minimum))
    p.multipleOf = tonumber(v:match(patterns.multipleOf))
    -- strings
    p.maxLength = tonumber(v:match(patterns.maxLength))
    p.minLength = tonumber(v:match(patterns.minLength))
    p.pattern = v:match(patterns.pattern)
    -- arrays
    p.maxItems = tonumber(v:match(patterns.maxItems))
    p.minItems = tonumber(v:match(patterns.minItems))
    p.uniqueItems = v:match(patterns.uniqueItems) and true
    
    -- if we have a data type matching one of our validation keywords,
    -- it's not really a data type, so unset it
    if p.dataType and patterns[p.dataType] then p.dataType = nil end
    
    -- default data type is string
    if not p.dataType then p.dataType = 'string' end
    
    -- default param type is "path" if there's a matching token in the path,
    -- or "form" if the operation wants a POST, or "query" otherwise. 
    if not p.paramType then
      if path:match('{' .. p.name .. '}') then
        p.paramType = 'path'
      elseif method == 'POST' then
        p.paramType = 'form'
      else
        p.paramType = 'query'
      end
    end
    -- if the data type is a model, put the model in our resource listing
    insert_model(p.dataType, referenced_models)
    table.insert(params, p)
  end
  
  -- if the return type is a model, put the model in our resource listing
  insert_model(return_type, referenced_models)
  
  return path, {
    nickname = name,
    summary = format(config.summary_format),
    notes = format(config.notes_format),
    method = method,
    type = return_type,
    parameters = params 
    
  }, referenced_models
  
end)


local function Failure(reason, status)
  return {
    fail = function(connection) connection:fail(reason, status) end,
  }
end

-- Type conversion and validation

local function check_object(value, info)
  
  local function ParamFailure(message)
    return Failure("Parameter '" .. info.name .. "' " .. message)
  end
  
  local function JsonFailure()
    return ParamFailure("must represent a valid JSON " .. info.dataType)
  end
  
  xpcall(function() value = util.json_decode(value) end, fail_json)
  
  if type(value) ~= 'table' then
    return nil, JsonFailure()
  end
  if info.dataType == 'object' and #value > 0 then
    return nil, JsonFailure()
  end
  if info.dataType == 'array' then
    local found_items = {}
    if info.minItems and info.minItems > #value then
      return nil, ParamFailure("must contain at least " .. 
          info.minItems .." items")
    end
    if info.maxItems and info.maxItems < #value then
      return nil, ParamFailure("must not exceed " .. 
          info.maxItems .. " items")
    end
    for k, v in pairs(value) do
      local json_value = util.json_encode(v)
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        return JsonFailure()
      end
      if info.uniqueItems and found_items[json_value] then
        return nil, ParamFailure("must contain unique items")
      end
      if info.uniqueItems then found_items[json_value] = true end
    end
  end
  return value
end

local function check_string(value, info)
  
  local function ParamFailure(message)
    return Failure("Parameter '" .. info.name .. "' " .. message)
  end
  
  if info.minLength and info.minLength > #value then
    return nil, ParamFailure("must be at least "
        .. info.minLength .. " bytes in length")
  end
  if info.maxLength and info.maxLength < #value then
    return nil, ParamFailure("must not exceed " ..
        info.maxLength .. " bytes in length")
  end
  return value
end

local function check_number(value, info)
  value = tonumber(value)
  
  local function ParamFailure(message)
    return Failure("Parameter '" .. info.name .. "' " .. message)
  end
  
  if not value then
    return nil, ParamFailure("must be a number")
  end
  if info.dataType == 'integer' and value ~= math.floor(value) then
    return nil, ParamFailure("must be an integer")
  end
  if info.minimum and info.minimum > value then
    return nil, ParamFailure("must be at least " .. info.minimum)
  end
  if info.maximum and info.maximum < value then
    return nil, ParamFailure("must not exceed " .. info.maximum)
  end
  if info.multipleOf and value % info.multipleOf ~= 0 then
    return nil, ParamFailure("must be a multiple of " .. info.multipleOf)
  end
  return value
end

-- get resource listing
-- https://github.com/wordnik/swagger-core/wiki/Resource-Listing
local get_resource_listing = memoize(function()
  return util.json_encode {
    apiVersion = config.api_version,
    swaggerVersion = config.swagger_version,
    apis = API_INFO,
  }
end)

-- get api declaration
-- https://github.com/wordnik/swagger-core/wiki/API-Declaration
local get_api_declaration = memoize(function(base, path, module)
  local resource_path = path:gsub('^' .. config.resource_listing_path, '')
  local api_name = resource_path:match('.*/(.*)') or resource_path
  local ops_by_path = {}
  local declaration = {
    apiVersion = config.api_version,
    swaggerVersion = config.swagger_version,
    basePath = base,
    resourcePath = '/' .. util.trim_path(resource_path),
    apis = {},
    models = {},
  }
  
  local path, info, models
  
  for key, value in pairs(module) do 
    path, info, models = parse_doc(key, value)
    if path and info then
      if not ops_by_path[path] then ops_by_path[path] = {} end
      table.insert(ops_by_path[path], info)
    end
  end
  
  for key, value in pairs(ops_by_path) do 
    table.insert(declaration.apis, {
      path = key, 
      operations = value,
      description = MODULE_TITLES[module],
    })
  end
  
  for key, value in pairs(models) do 
    declaration.models[key] = value
  end
  
  return util.json_encode(declaration)
end)

-- Unpack a sparse numeric table with a "length" property
-- http://www.lua.org/pil/5.1.html
local function unpack_args(t, i)
  i = i or 1
  if i <= t.length then
    return t[i], unpack_args(t, i + 1)
  end
end

-- Connection pseudoclass definition

-- set up connection 
function Connection:constructor(hostdata)
  self.hostdata = hostdata
  self:populate_request_table()
end

-- send a failure reason and error code/status 
function Connection:fail(reason, status)
  if not status then status = '400 Bad Request' end
  self:send_head(status, { ['Content-Type'] = 'application/json' })
  self:send(util.json_encode({ error = reason }))
end

-- send resource listing
function Connection:send_resource_listing()
  local resources = get_resource_listing()
  self:send_head('200 OK', { ['Content-Type'] = 'application/json' })
  self:send(resources)
end

-- send api declaration
function Connection:send_api_declaration(module)
  local base = self:get_base_path()
  local path = util.trim_path(self.request.path)
  local declaration = get_api_declaration(base, path, module)
  self:send_head('200 OK', { ['Content-Type'] = 'application/json' })
  self:send(declaration)
end


-- populate the "request" table; contains useful stuff for API operations.
function Connection:populate_request_table()
  local request = {}
  local request_info = self:get_request_info()
  local path = util.normalize_path(request_info.path_info)
  local method_override = self:get_header 'X-HTTP-Method-Override'
  local content_type = request_info.content_type
  
  request.info = request_info
  request.method = method_override or request_info.request_method
  request.path = path
  request.body = ''
  request.form = {}
  request.query = util.query_decode(request_info.query_string)
  request.header = setmetatable({}, {
    __index = function(t, key) return self:get_header(key) end,
  })
  request.args = {}
  request.path_args = {}
  request.body_args = {}
  request.form_args = {}
  request.query_args = {}
  request.header_args = {}
  
  if content_type then
    for line in function() return self:receive() end do
      request.body = request.body .. line
    end
    if content_type == 'application/x-www-form-urlencoded' then
      request.form = util.query_decode(request.body)
    end
  end
  
  self.request = request
  
  return request
end


-- Find the appropriate function based on the request path.
-- Extract all arguments; return function, arguments, and failure flag.
function Connection:resolve_operation_path()
local request = self.request
local request_path = request.path
local http_method = request.method
  for module_path, module in pairs(API_MODULES) do 
    for key, value in pairs(module) do 
      local path, info, models = parse_doc(key, value)
      if path and info then
        local path_pattern = util.normalize_path(path):gsub('{.-}', '(.-)')
        local args = {}
        local path_args = { 
          util.normalize_path(request_path):match('^' .. path_pattern .. '$')
        }
  
        if info.method == http_method
          and #path_args > 0 then
          local named_path_args = {}
          local i = 0
          for k in path:gmatch '{(.-)}' do
            i = i + 1
            named_path_args[k] = path_args[i]
          end
          for k, v in ipairs(info.parameters) do
            local arg_value
            local failure
            -- figure out where to get the argument from, and get it
            if v.paramType == 'path' then
              arg_value = named_path_args[v.name]
              request.path_args[v.name] = arg_value
            elseif v.paramType == 'query' then
              arg_value = request.query[v.name]
              request.query_args[v.name] = arg_value
            elseif v.paramType == 'form' then
              arg_value = request.form[v.name]
              request.form_args[v.name] = arg_value
            elseif v.paramType == 'header' then
              arg_value = get_header(v.name)
              request.header_args[v.name] = arg_value
            elseif v.paramType == 'body' then
              arg_value = get_body()
              request.body_args[v.name] = arg_value
            else
              arg_value = nil
            end
            -- type conversion and validation
            if arg_value then
              if v.dataType == 'array' or v.dataType == 'object' then
                arg_value, failure = check_object(arg_value, v)
              elseif v.dataType == 'integer' or v.dataType == 'number' then
                arg_value, failure = check_number(arg_value, v)
              elseif v.dataType == 'boolean' then
                arg_value, failure = arg_value == 'true' and true or false
              elseif v.dataType == 'string' then
                arg_value, failure = check_string(arg_value, v)
              end
              if failure then return nil, nil, failure end
            end
            -- enforce required params
            if v.required and arg_value == nil then
              failure = Failure("Parameter '" .. v.name .. "' is required")
              return nil, nil, failure
            end
            request.args[v.name] = arg_value
            args[k] = arg_value
            args.length = k
          end
          -- success
          return value, args
        end -- iterate params
      end -- if path and info
    end -- iterate module
  end -- iterate API_MODULES
end

function Connection:handle_request()
  local request = self.request
  local path = util.trim_path(request.path)
  local list = util.trim_path(config.resource_listing_path)
  local module = API_MODULES[path]
  
  if path == list then
    return self:send_resource_listing()
  elseif module then
    return self:send_api_declaration(module)
  else
    local result
    local fn, args, failure = self:resolve_operation_path()
    if failure then return failure.fail(self) end
    if fn and args then
      args.length = args.length + 1
      args[args.length] = self
      local _, err = pcall(function() result = fn(unpack_args(args)) end)
      if err then
        return self:fail(err:match '.-:%s(.*)', '500 Internal Server Error')
      end
      self:send_head('200 OK', { ['Content-Type'] = 'application/json' })
      return self:send(util.json_encode(result))
    end
  end
  self:fail('Resource does not exist', '404 Not Found')
end

-- moonwalk module

return {
  
  -- configuration options
  config = config,
  
  -- functions to check host environment, keyed by module name.
  known_hosts = KNOWN_HOSTS,
  
  -- api overview, as in resource listing. numeric keys. 
  api_info = API_INFO,
  
  -- operation docs, keyed by operation function
  operation_docs = OPERATION_DOCS,
  
  -- module titles, keyed by module table
  module_titles = MODULE_TITLES,
  
  -- models, keyed by model name
  models = MODELS,
  
  -- modules, keyed by resource path
  modules = API_MODULES,
  
  -- register an API module
  register = function(name)
    local list = util.trim_path(config.resource_listing_path)
    local key = list .. '/' .. name
    
    if API_MODULES[key] then return end
    
    local module = require(name)
    
    table.insert(API_INFO, {
      path = '/' .. name,
      description = MODULE_TITLES[module],
    })
    API_MODULES[key] = module
  end,
  
  -- document a module
  module = function(docs)
    return function(obj) 
      if not MODULE_TITLES[obj] then MODULE_TITLES[obj] = docs end 
      return obj
    end
  end,
  
  -- register a model
  model = function(key)
    if MODELS[key] then return function() end end
    return function(m) MODELS[key] = m end
  end,
  
  -- document an operation
  operation = function(docstring)
    return setmetatable({ docstring }, OPERATION_META)
  end,
  
  -- get the current connection.
  get_connection = function(hostdata)
    return detect_host()(hostdata)
  end,
  
  -- handle the request.
  handle_request = function(hostdata)
    detect_host()(hostdata):handle_request()
  end,
  
}

