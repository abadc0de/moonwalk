--- Mongoose/Civetweb support
--
-- https://github.com/cesanta/mongoose
-- https://github.com/sunsetbrew/civetweb
--

local headers
local connection = {}

-- TODO: This is a hack. We assume the first segment of the URI
-- is the script's directory, because there's not enough info in
-- mg.request_info to figure it out.
local function get_api_root()
  return mg.request_info.uri:match('^/[^/]*')
end

function connection:detect_host()
  local version = _G.mg and _G.mg.version
  if not version then return end
  
  -- TODO: in the future we should have better ways to
  -- tell Mongoose and Civetweb apart.
  local name = tonumber(version) > 3 and 'Mongoose' or 'Civetweb'
  
  headers = mg.request_info.http_headers
  
  return version and name .. ' ' .. version
end

function connection:get_method()
  return mg.request_info.request_method
end

function connection:get_path()
  return mg.request_info.uri:gsub('^' .. get_api_root(), '')
end

function connection:get_scheme()
  -- TODO: detect https
  return 'http'
end

function connection:get_script()
  return get_api_root() .. '/index.lua'
end

function connection:get_query()
  return mg.request_info.query_string
end

function connection:get_header(name)
  return headers[name]
end

function connection:send_head(status, headers)
  mg.write('HTTP/1.1 ' .. status .. '\n')
  for k, v in pairs(headers) do
    mg.write(k .. ': ' .. v .. '\n')
  end
  mg.write('\n')
end

function connection:send(s)
  mg.write(s)
end

function connection:receive()
  return mg.read()
end
  
return connection

