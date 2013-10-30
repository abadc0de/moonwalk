-- Moonwalk: Swagger server for Lua. 
--
-- See README.md for info and license.

-- override these config options as needed, after requiring moonwalk.
local config = {
  -- Your API's version
  api_version = '1.0',
  -- Swagger version
  swagger_version = '1.2',
  -- Path to Swagger resources.
  -- If you change this, also change it in the API explorer index.html.
  resource_listing_path = 'resources',
  -- Pretty-print JSON, for debugging.
  pretty_json = false,
  -- Content-Type string for JSON
  json_content_type = 'Content-Type: application/json',
  -- Use Markdown to format the "notes" section of the doc block.
  use_markdown = true,
  -- Are model properties required by default?
  -- If true, override with `optional = true` in parameter definitions.
  model_properties_required = true,
  -- Format the "summary" section of a doc block.
  -- Replacement tokens: {nickname}, {summary}, {notes}
  summary_format = '<code>{nickname}</code><span>{summary}</span>',
  -- Format the "notes" section of a doc block.
  -- Replacement tokens: {nickname}, {summary}, {notes}
  notes_format = [[<div class="notes">
<h2><code>{nickname}</code><span style="color:#999"> : {summary}</span></h2>
{notes}</div>]],
}

-- host adapter
local host

-- host adapter "interface"
local request_info
local get_header
local get_base_path
local send
local receive

-- various storage tables
local api_info = {}
local api_modules = {}
local operation_docs = {}
local module_docs = {}
local request = {}
local model = {}
local finalized_models = {}

-- if something fails, this is set to true
-- so we know not to send any more data
local is_finished = false

-- magical annotation concatenation
-- http://lua-users.org/wiki/DecoratorsAndDocstrings
local operation_meta = {
  __concat = function(t, fn)
    operation_docs[fn] = t[1]
    return fn
  end
}

-- detect supported host environment (cgi, mongoose)
local function detect_host()
  -- CGI
  if os.getenv 'GATEWAY_INTERFACE' then
    return require "host/cgi"
  -- mongoose
  elseif _G.mg and _G.mg.version then
    return require "host/mongoose"
  -- unknown
  else
    error "Moonwalk could not detect host environment"
  end
end

-- trim leading and trailing slashes from a path
local function trim_path(s)
  return s and s:match '^/*(.-)/*$' or ''
end

-- make path have exactly one leading and one trailing slash
local function normalize_path(s)
  return '/' .. trim_path(s) .. '/'
end

-- encode and decode JSON
-- http://regex.info/blog/lua/json
local function json_encode(t)
  local json = require "lib/json"
  return config.pretty_json and json:encode_pretty(t) or json:encode(t) 
end
  
local function json_decode(s)
  local json = require "lib/json"
  return json:decode(s)
end

-- encode and decode URIs
-- http://www.w3.org/TR/html4/interact/forms.html#h-17.13.4
-- http://www.ietf.org/rfc/rfc1738
local function uri_encode(s)
  return s:gsub("[^A-Za-z0-9$_.!*'(), -]", function(c)
    return string.format("%%%02x", string.byte(c))
  end):gsub(" ", "+")
end

local function uri_decode(s)
  return s:gsub("+", " "):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

-- encode a table as a query string (not currently used).
local function query_encode(t, query)
  local t = {}
  if not query then query = "" end
  for k, v in pairs(t) do
    if type(v) == "string" and v ~= "" then
      t[# t + 1] = ("%s=%s"):format(uri_encode(k), uri_encode(v))
    elseif type(v) == "table" and not v.file then
      for i = 1, # v do
        t[# t + 1] = ("%s=%s"):format(uri_encode(k), uri_encode(v[i]))
      end
    end
  end
  return '?' .. table.concat(t, '&')
end
  
-- decode a query string into a table.
local function query_decode(query)
  local parsed = {}
  local pos = 0
  if not query then return parsed end
  local function insert(s)
    local first, last = s:find("=")
    local k, v, cur
    if first then
      k = uri_decode(s:sub(0, first - 1))
      v = uri_decode(s:sub(first + 1))
      cur = parsed[k]
      if (cur) then
        if type(cur) == "table" then
          table.insert(cur, v)
        else
          parsed[k] = { cur, v }
          setmetatable(parsed[k], {})
        end
      else
        parsed[k] = v
      end
    end
  end
  while true do
    local first, last = query:find("&", pos)
    if first then
      insert(query:sub(pos, first - 1))
      pos = last + 1
    else
      insert(query:sub(pos))
      break
    end
  end
  return parsed
end

-- Send an error
local function fail(reason, status)
  if is_finished then return end
  if not status then status = '400 Bad Request' end
  send(config.json_content_type .. '\nStatus: ' .. status .. '\n\n' .. 
      json_encode({ error = reason }))
  is_finished = true
end

-- get http request method, honoring X-HTTP-Method-Override header
local function get_http_method()
  local override = get_header 'X-HTTP-Method-Override'
  
  return override or request_info.request_method
end

-- finalize a model definition and insert it into a table.
local function insert_model(name, t)
  if not t then return end
  
  local m = model[name]
  local require_props = config.model_properties_required
  local required = {}
  
  if not m then return end
  
  -- if the model is already finalized, insert it and return.
  if finalized_models[m] then
    t[name] = m
    return
  end
  
  -- allow model definitions to consist only of property definitions.
  if not m.properties then
    m = { properties = m }
    model[name] = m
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
    insert_model(v.type, t)
  end
  
  -- if model properties are required by default, or the "required" property
  -- is being used in property definitions, overwrite the "required" array 
  -- (if it exists) with our new values.
  if #required > 0 then m.required = required end
  
  -- mark this model as finalized
  finalized_models[m] = true
  
  -- insert the model into the target table
  t[name] = m
end

-- parse doc block for function into a Swagger-ready table.
-- returns the resource path (as defined by the @path tag) and the table.
-- http://json-schema.org/latest/json-schema-validation.html
local function parse_doc(name, fn, referenced_models)
  local doc = operation_docs[fn]
  
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
  
  if config.use_markdown and notes ~= '' then
    local markdown = require "lib/markdown"
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
    p.required = not v:match(patterns.optional)
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
    p.uniqueItems = not v:match(patterns.uniqueItems)
    
    if p.dataType and patterns[p.dataType] then p.dataType = nil end
    
    if not p.dataType then p.dataType = 'string' end
    
    if not p.paramType then
      if path:match('{' .. p.name .. '}') then
        p.paramType = 'path'
      elseif method == 'POST' then
        p.paramType = 'form'
      else
        p.paramType = 'query'
      end
    end
    insert_model(p.dataType, referenced_models)
    table.insert(params, p)
  end
  
  insert_model(return_type, referenced_models)
  
  return path, {
    nickname = name,
    summary = format(config.summary_format),
    notes = format(config.notes_format),
    method = method,
    type = return_type,
    parameters = params
  }
end

-- send resource listing
-- https://github.com/wordnik/swagger-core/wiki/Resource-Listing
local function send_resource_listing()
  local resources = {
    apiVersion = config.api_version,
    swaggerVersion = config.swagger_version,
    apis = api_info,
  }
  send(config.json_content_type .. '\n\n' .. json_encode(resources))
end

-- send api declaration
-- https://github.com/wordnik/swagger-core/wiki/API-Declaration
local function send_api_declaration(path, module)
  local resource_path = path:gsub('^' .. config.resource_listing_path, '')
  local api_name = resource_path:match('.*/(.*)') or resource_path
  local ops_by_path = {}
  local declaration = {
    apiVersion = config.api_version,
    swaggerVersion = config.swagger_version,
    basePath = get_base_path(),
    resourcePath = '/' .. trim_path(resource_path),
    apis = {},
    models = {},
  }
  
  for key, value in pairs(module) do 
    local path, info = parse_doc(key, value, declaration.models)
    if path and info then
      if not ops_by_path[path] then ops_by_path[path] = {} end
      table.insert(ops_by_path[path], info)
    end
  end
  
  for key, value in pairs(ops_by_path) do 
    table.insert(declaration.apis, {
      path = key, 
      operations = value,
      description = module_docs[module],
    })
  end
  
  send(config.json_content_type .. '\n\n' .. json_encode(declaration))
end


-- populate the "request" table; contains useful stuff for API operations.
local function populate_request_table(path)

  request.info = request_info
  request.path = path
  request.body = ''
  request.form = {}
  request.query = query_decode(request_info.query_string)
  request.header = setmetatable({}, {
    __index = function(t, key) return get_header(key) end,
  })
  request.args = {}
  request.path_args = {}
  request.body_args = {}
  request.form_args = {}
  request.query_args = {}
  request.header_args = {}
    
  for line in receive do
    request.body = request.body .. line
  end
  
  if request_info.content_type == 'application/x-www-form-urlencoded' then
    request.form = query_decode(request.body)
  end
  
end

-- Unpack a sparse numeric table with a "length" property
-- http://www.lua.org/pil/5.1.html
local function unpack_args(t, i)
  i = i or 1
  if i <= t.length then
    return t[i], unpack_args(t, i + 1)
  end
end

-- Type conversion and validation

local function check_object(value, info)
  local function fail_json()
    fail("Parameter '" .. info.name .. 
        "' must represent a valid JSON " .. info.dataType)
  end
  
  xpcall(function() value = json_decode(value) end, fail_json)
  
  if type(value) ~= 'table' then
    return fail_json()
  end
  if info.dataType == 'object' and #value > 0 then
    return fail_json()
  end
  if info.dataType == 'array' then
    local found_items = {}
    if info.minItems and info.minItems > #value then
      return fail("Parameter '" .. info.name .. "' must contain at least " .. 
          info.minLength .. " items")
    end
    if info.maxItems and info.maxItems < #value then
      return fail("Parameter '" .. info.name .. "' must not exceed " .. 
          info.minLength .. " items")
    end
    for k, v in pairs(value) do
      local json_value = json_encode(v)
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        return fail_json()
      end
      if info.uniqueItems and found_items[json_value] then
        return fail("Parameter '" .. info.name .. 
            "' must contain unique items")
      end
      if info.uniqueItems then found_items[json_value] = true end
    end
  end
  return value
end

local function check_string(value, info)
  if info.minLength and info.minLength > #value then
    return fail("Parameter '" .. info.name .. "' must be at least " .. 
        info.minLength .. " bytes in length")
  end
  if info.maxLength and info.maxLength < #value then
    return fail("Parameter '" .. info.name .. "' must not exceed " .. 
        info.maxLength .. " bytes in length")
  end
  return value
end

local function check_number(value, info)
  value = tonumber(value)
  if not value then
    return fail("Parameter '" .. info.name .. "' must be a number")
  end
  if info.dataType == 'integer' and value ~= math.floor(value) then
    return fail("Parameter '" .. info.name .. "' must be an integer")
  end
  if info.minimum and info.minimum > value then
    return fail("Parameter '" .. info.name .. "' must be at least " .. 
        info.minimum)
  end
  if info.maximum and info.maximum < value then
    return fail("Parameter '" .. info.name .. "' must not exceed " .. 
        info.maximum)
  end
  if info.multipleOf and value % info.multipleOf ~= 0 then
    return fail("Parameter '" .. info.name .. "' must be a multiple of " .. 
        info.multipleOf)
  end
  return value
end

-- Find the appropriate function based on the request path.
-- Extract all arguments, return the function and arguments.
local function resolve_operation_path(request_path)
  populate_request_table(request_path)
  for module_path, module in pairs(api_modules) do 
    for key, value in pairs(module) do 
      local path, info = parse_doc(key, value)
      if path and info then
        local path_pattern = normalize_path(path):gsub('{.-}', '(.-)')
        local args = {}
        local path_args = { 
          normalize_path(request_path):match(path_pattern)
        }
        if info.method == get_http_method() and #path_args > 0 then
          local named_path_args = {}
          local i = 0
          for k in path:gmatch '{(.-)}' do
            i = i + 1
            named_path_args[k] = path_args[i]
          end
          for k, v in ipairs(info.parameters) do
            local arg_value
            local success = false
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
            if arg_value then
              if v.dataType == 'array' or v.dataType == 'object' then
                arg_value = check_object(arg_value, v)
              elseif v.dataType == 'integer' or v.dataType == 'number' then
                arg_value = check_number(arg_value, v)
              elseif v.dataType == 'boolean' then
                arg_value = arg_value == 'true' and true or false
              elseif v.dataType == 'string' then
                arg_value = check_string(arg_value, v)
              end
              if is_finished then return end
            end
            -- TODO: enforce required
            if v.required and arg_value == nil then
              return fail("Parameter '" .. v.name .. "' is required")
            end
            request.args[v.name] = arg_value
            args[k] = arg_value
            args.length = k
          end
          return value, args
        end
      end -- if path and info
    end -- iterate module
  end -- iterate api_modules
end

-- adapt to host environment
host = detect_host()
request_info = host.request_info
get_header = host.get_header
get_base_path = host.get_base_path
send = host.send
receive = host.receive

-- moonwalk module
return {
  
  -- configuration options
  config = config,
  
  -- send raw data over the wire
  send = send,
  
  -- information about the request, for use in API operations
  request = request,
  
  -- put your models in this table
  model = model,
  
  -- register an API module
  register = function(name)
    local list = trim_path(config.resource_listing_path)
    local module = require(name)
    
    table.insert(api_info, {
      path = '/' .. name,
      description = module_docs[module],
    })
    api_modules[list .. '/' .. name] = module
  end,
  
  -- document a module
  module = function(docs)
    return function(obj)
      module_docs[obj] = docs
      return obj
    end
  end,
  
  -- document an operation
  operation = function(docs)
    return setmetatable({ docs }, operation_meta)
  end,
  
  -- handle the request
  handle_request = function()
    local path = trim_path(request_info.path_info)
    local list = trim_path(config.resource_listing_path)
    local module = api_modules[path]
    
    if path == list then
      return send_resource_listing()
    elseif module then
      return send_api_declaration(path, module)
    else
      local result
      local fn, args = resolve_operation_path(path)
      if is_finished then return end
      if fn and args then
        local _, err = pcall(function() result = fn(unpack_args(args)) end)
        if err then
          return fail(err:match '.-:%s(.*)', '500 Internal Server Error')
        end
        return send(config.json_content_type .. '\n\n' .. json_encode(result))
      end
    end
    fail('Resource does not exist', '404 Not Found')
  end,
  
}

