-- Print anything - including nested tables
-- http://lua-users.org/wiki/TableSerialization
local function dump(tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    if indent == 0 then io.write("{\n") end
    for key, value in pairs (tt) do
      io.write(string.rep (" ", indent + 4)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        io.write(string.format("%s = {\n", tostring (key)));
        dump (value, indent + 4, done)
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
  local json = require "moonwalk/lib/json"
  return json:encode_pretty(t) -- json:encode(t) 
end
  
local function json_decode(s)
  local json = require "moonwalk/lib/json"
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
  
return {

  dump = function(...)
    local args = {...}
    for i, v in ipairs(args) do 
      dump(v)
    end
    dump('\n')
    return ...
  end,
  
  trim_path = trim_path,
  normalize_path = normalize_path,
  json_encode = json_encode,
  json_decode = json_decode,
  uri_encode = uri_encode,
  uri_decode = uri_decode,
  query_encode = query_encode,
  query_decode = query_decode,

}
