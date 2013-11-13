--- Resource locator.
--

local parser = require 'moonwalk/parser'
local static = require 'moonwalk/static'
local util = require 'moonwalk/util'
local validator = require 'moonwalk/validator'

local locator = {}

--- Finds an appropriate `operation` to handle a request.
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
locator.find_operation = function(connection)
  local request = connection.request
  local request_path = request.path
  local http_method = request.method

  for module_path, module in pairs(static.api_classes) do
    for key, value in pairs(module) do 
      local path, info, models = parser.parse_doc(key, value)
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
          return value, args
        end -- iterate params
      end -- if path and info
    end -- iterate module
  end -- iterate static.api_classes
end

return locator
