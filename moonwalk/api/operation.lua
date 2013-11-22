--- API operation. Extends the `proto` object.
--

local proto = require 'moonwalk/proto'
local sugar = require 'moonwalk/sugar'
local util = require 'moonwalk/util'
local validator = require 'moonwalk/validator'

--- @type module
local operation = proto:extend()

--- Use Markdown to format the "notes" section of the doc block.
-- 
-- Defaults to `true`.
--
operation.use_markdown = true

--- Format string for the "summary" section of a doc block.
--
-- Replacement tokens: `{nickname}`, `{summary}`, `{notes}`
--
operation.summary_format = '<code>{nickname}</code><span>{summary}</span>'

--- Format string for the "notes" section of a doc block.
--
-- Replacement tokens: `{nickname}`, `{summary}`, `{notes}`
--
operation.notes_format = [[<div class="notes">
<h3><code>{nickname}</code><span style="color:#999"> : {summary}</span></h3>
{notes}</div>]]

--- Create an operation. This function is not meant to be called directly
-- (see `proto.constructor`). 
--
-- @param docstring A string documenting the function, as described in the
-- readme.
--
-- @param fn A function to handle this operation.
--
function operation:constructor(docstring, fn)
  self.docstring = docstring
  self.fn = fn
  return self
end

operation.constructor = sugar.sweeten(operation.constructor, 3)

--- Decode docblock for function.
--
-- @param name The name of the API operation function.
-- This becomes the Swagger `nickname`.
--
-- @param api The `api` this operation belongs to.
-- 
-- @return The resource path (as defined by the @path tag).
-- @return A table containing the [API declaration
-- ](https://github.com/wordnik/swagger-core/wiki/API-Declaration#apis).
-- @return A table containing any referenced models.
--
function operation:decode_docblock(name, api)
  local fn = self.fn
  local doc = self.docstring
  local referenced_models = {}
  
  if not doc then return end
  
  -- remove indentation
  doc = doc:gsub('[\r\n]' .. (doc:match '[\r\n](%s+)%a' or ''), '\n')
  
  local summary = doc:match '%s+(.-)%s*[\r\n]%s*[\r\n]' or ''
  local notes = doc:match '%s+.-%s*[\r\n]%s*[\r\n](.-)%s*@' or ''
  local path = doc:match '@path%s+%a+%s+([^\r\n%s]+)'
  local method = doc:match '@path%s+(%a+)'
  local return_type = doc:match '@return%s+.-(%a+)'
  local params = {}
  
  local function format(s)
    return s:gsub('{nickname}', name)
        :gsub('{summary}', summary)
        :gsub('{notes}', notes)
  end
  
  local function insert_model(name, refs)
    local m = api.models[name]
    if not m then return end
    m:insert_into(refs, api.models)
  end
  
  -- markdown the "notes" section
  if self.use_markdown and notes ~= '' then
    local markdown = require "moonwalk/lib/markdown"
    notes = markdown(notes)
  end
  
  -- parse all @param tags
  for v in doc:gmatch '@param([^@]*)' do
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
    summary = format(self.summary_format),
    notes = format(self.notes_format),
    method = method,
    type = return_type,
    parameters = params,
    
  }, referenced_models
  
end

--- Finds an appropriate operation to handle a request.
--
-- Extracts arguments from the request, and validates them based
-- on the API author's validation rules. Modifies the request table
-- with information about the extracted arguments if validation succeeds.
--
-- @param connection A `connection` instance. 
--
-- @return A function to handle the operation, defined by the API author. 
-- @return A numeric table of arguments, with a `length` property to
-- accomodate sparseness.
-- @return A `validator.failure` instance if validation failed or
-- no operation was found.
--
function operation:prepare(connection)
  local api = connection.api
  local request = connection.request
  local request_path = request.path
  local http_method = request.method
    
  for module_path, class in pairs(api.classes) do
    for key, value in pairs(class.operations) do 
      if type(value) == 'table' and value.decode_docblock then
        local path, info, models = value:decode_docblock(key, api)
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
                  arg_value, failure = validator.check_object(arg_value, v)
                elseif v.dataType == 'integer' or v.dataType == 'number' then
                  arg_value, failure = validator.check_number(arg_value, v)
                elseif v.dataType == 'boolean' then
                  arg_value, failure = validator.arg_value == 'true' and true or false
                elseif v.dataType == 'string' then
                  arg_value, failure = validator.check_string(arg_value, v)
                end
                if failure then return nil, nil, failure end
              end
              -- enforce required params
              if v.required and arg_value == nil then
                return nil, nil, validator.failure("Parameter '"
                    .. v.name .. "' is required")
              end
              request.args[v.name] = arg_value
              args[k] = arg_value
              args.length = k
            end
            -- success
            return value.fn, args
          end -- iterate params
        end -- if path and info
      end -- if it's really an operation
    end -- iterate operations
  end -- iterate api classes
end

return operation

