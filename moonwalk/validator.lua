--- Type conversion and validation
--

--- Creates an object representing failure.
--
-- @param reason Human-readable reason why the request failed. 
-- @param status Optional HTTP status code and reason, like `400 Bad Request`
--
-- @return An object with a `.fail` method taking one argument, 
-- a `connection` instance.
--
local function failure(reason, status)
  return { fail = function(conn) conn:fail(reason, status) end }
end

--- Validation functions. For each of these functions, `value` is a 
-- string passed in by the API consumer containing JSON data. The
-- `info` argument should be a table of parameter or property
-- validation rules extracted from a doc block or model definition.
--
-- @section validation
--

--- Validate a string containing a JSON object or array. 
--
-- @param value String value to check.  
-- @param info Validation info.
--
-- @return A table representing `value`, or `nil` on failure.
-- @return A `failure` object if validation failed, else `nil`.
--
local function check_object(value, info)
  
  local function ParamFailure(message)
    return failure("Parameter '" .. info.name .. "' " .. message)
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

--- Validate a string.
--
-- @param value String value to check.  
-- @param info Validation info.
--
-- @return The `value`, or `nil` on failure.
-- @return A `failure` object if validation failed, else `nil`.
--
local function check_string(value, info)
  
  local function ParamFailure(message)
    return failure("Parameter '" .. info.name .. "' " .. message)
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

--- Validate a number.
--
-- @param value String value to check.  
-- @param info Validation info.
--
-- @return A number representing `value`, or `nil` on failure.
-- @return A `failure` object if validation failed, else `nil`.
--
local function check_number(value, info)
  value = tonumber(value)
  
  local function ParamFailure(message)
    return failure("Parameter '" .. info.name .. "' " .. message)
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

--- @export
return {
  failure = failure,
  check_object = check_object, 
  check_string = check_string, 
  check_number = check_number, 
}

