--- Not really a parser, just a bunch of pattern matching.
--

local config = require 'moonwalk/config'
local memoize = require 'moonwalk/lib/memoize'
local static = require 'moonwalk/static'

--- Finalize a model definition.
local function finalize_model(name)

  local m = static.models[name]
  local require_props = config.model_properties_required
  local required = {}
  local ref_models = {}
  
  if not m then return end
  
  -- allow model definitions to consist only of property definitions.
  if not m.properties then
    m = { properties = m }
    static.models[name] = m
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

end

--- Finalize a model definition and insert it into a table.
local function insert_model(name, t)
  if (not t) or t[name] then return end
  -- insert the model into the target table
  local model, related = finalize_model(name)
  -- find any related models and insert them too
  if model and related then
    t[name] = model
    for _, v in ipairs(related) do insert_model(v, t) end
  end
end

--- Parse doc block for function.
-- Returns [API declaration
-- ](https://github.com/wordnik/swagger-core/wiki/API-Declaration#apis) table.
--
-- @param name The name of the API operation function.
-- This becomes the Swagger `nickname`.
--
-- @param fn A function with an attached doc block to read,
-- as registered by `operation`. 
-- 
-- @return The resource path (as defined by the @path tag).
-- @return A table containing the resource listing.
-- @return A table containing any referenced models.
--
local function parse_doc(name, fn)

  local doc = static.operation_docs[fn]
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
  
  -- markdown the "notes" section
  if config.use_markdown and notes ~= '' then
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
    summary = format(config.summary_format),
    notes = format(config.notes_format),
    method = method,
    type = return_type,
    parameters = params,
    
  }, referenced_models
  
end

parse_doc = memoize(parse_doc)

--- @export
return {

  parse_doc = parse_doc,

}

