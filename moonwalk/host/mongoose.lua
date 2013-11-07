-- Mongoose/Civetweb support
-- https://github.com/cesanta/mongoose
-- https://github.com/sunsetbrew/civetweb

local headers = mg.request_info.http_headers

-- TODO: This is a hack. We assume the first segment of the URI
-- is the script's directory, because there's not enough info in
-- mg.request_info to figure it out.
local api_root = mg.request_info.uri:match('^/[^/]*')

local request_info = {
  content_type = headers['Content-Type'],
  path_info = mg.request_info.uri:gsub('^' .. api_root, ''),
  query_string = mg.request_info.query_string,
  request_method = mg.request_info.request_method,
}

local HostConnection = {}

function HostConnection:get_request_info()
  return request_info
end

function HostConnection:get_base_path()
  return 'http://' .. headers['Host'] .. api_root
end

function HostConnection:get_header(name)
  return headers[name]
end

function HostConnection:send_head(status, headers)
  mg.write('HTTP/1.1 ' .. status .. '\n')
  for k, v in pairs(headers) do
    mg.write(k .. ': ' .. v .. '\n')
  end
  mg.write('\n')
end

function HostConnection:send(s)
  mg.write(s)
end

function HostConnection:receive()
  return mg.read()
end
  
return HostConnection

