
--- Text processing utilities.
--

local function _dump(tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    if indent == 0 then io.write("{\n") end
    for key, value in pairs (tt) do
      io.write(string.rep (" ", indent + 4)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        io.write(string.format("%s = {\n", tostring (key)));
        _dump (value, indent + 4, done)
        io.write(string.rep (" ", indent + 4)) -- indent it
        io.write("}\n");
      else
        io.write(string.format("%s = %s\n",
            tostring (key), tostring(value)))
      end
    end
    if indent == 0 then io.write("}\n") end
  else
    io.write(tostring (tt))
  end
end

--- Print anything, including nested tables.
--
-- May be used for debugging. This dumps things to stdout, so it's
-- not appropriate for environments like CGI. See Lua 
-- [Table Serialization](http://lua-users.org/wiki/TableSerialization).
--
-- @param ... Anything
--
local function dump(...)
  local args = {...}
  for i, v in ipairs(args) do 
    _dump(v)
  end
  _dump('\n')
  return ...
end

--- Trim leading and trailing slashes from a path.
--
-- @param path Path
-- @return Trimmed path
-- @see normalize_path
--
local function trim_path(path)
  return path and path:match '^/*(.-)/*$' or ''
end

--- Make path have exactly one leading and one trailing slash.
--
-- @param path Path
-- @return Normalized path
-- @see trim_path
--
local function normalize_path(path)
  return '/' .. trim_path(path) .. '/'
end

--- Encode JSON.
--
-- @param data Lua value to encode
-- @return JSON string
-- @see json_decode
--
local function json_encode(data)
  local json = require "moonwalk/lib/json"
  return json:encode_pretty(data) -- json:encode(t) 
end
  
--- Decode JSON.
--
-- @param text JSON string
-- @return mixed
-- @see json_encode
--
local function json_decode(text)
  local json = require "moonwalk/lib/json"
  return json:decode(text)
end

--- Encode URI component.
--
-- See [HTML Forms](http://www.w3.org/TR/html4/interact/forms.html#h-17.13.4)
-- and [RFC 1738](http://www.ietf.org/rfc/rfc1738).
--
-- @param text Plain text string
-- @return URI-encoded text
-- @see uri_decode
--
local function uri_encode(text)
  return text:gsub("[^A-Za-z0-9$_.!*'(), -]", function(c)
    return string.format("%%%02x", string.byte(c))
  end):gsub(" ", "+")
end

--- Decode URI component.
--
-- @param text URI-encoded text
-- @return Plain text string
-- @see uri_encode
--
local function uri_decode(text)
  return text:gsub("+", " "):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

--- Encode a table as a query string.
--
-- This function is not used by Moonwalk, it is provided for the
-- API author's convenience.
--
-- @param data Table of key-value pairs
-- @return Plain text string
-- @see query_decode
--
local function query_encode(data)
  local t = {}
  for k, v in pairs(data) do
    if type(v) == "string" and v ~= "" then
      t[# t + 1] = ("%s=%s"):format(uri_encode(k), uri_encode(v))
    elseif type(v) == "table" and not v.file then
      for i = 1, # v do
        t[# t + 1] = ("%s=%s"):format(uri_encode(k), uri_encode(v[i]))
      end
    end
  end
  return table.concat(t, '&')
end
  
--- Decode a query string into a table.
--
-- @param text Query string
-- @return Table of query params
-- @see query_encode
--
local function query_decode(text)
  local parsed = {}
  local pos = 0
  if not text then return parsed end
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
    local first, last = text:find("&", pos)
    if first then
      insert(text:sub(pos, first - 1))
      pos = last + 1
    else
      insert(text:sub(pos))
      break
    end
  end
  return parsed
end

--- @export
--
return {

  dump = dump,
  trim_path = trim_path,
  normalize_path = normalize_path,
  json_encode = json_encode,
  json_decode = json_decode,
  uri_encode = uri_encode,
  uri_decode = uri_decode,
  query_encode = query_encode,
  query_decode = query_decode,

}

