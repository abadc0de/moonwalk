-- LuaNode support
-- https://github.com/ignacio/luanode

local unpack = table.unpack or unpack

local HostConnection = {}

function HostConnection:get_request_info()
  local request, response = unpack(self.hostdata)

  return {
    content_type = request.headers['Content-Type'],
    path_info = request.path:gsub('^' .. request.api_root, ''),
    query_string = request.query,
    request_method = request.method,
  }
end

function HostConnection:get_base_path()
  local request, response = unpack(self.hostdata)

  return 'http://' .. request.headers.Host .. request.api_root
end

function HostConnection:get_header(name)
  local request, response = unpack(self.hostdata)

  return request.headers[name]
  
end

function HostConnection:send_head(status, headers)
  local request, response = unpack(self.hostdata)
  response:sendHead(status, headers)
end

function HostConnection:send(s)
  local request, response = unpack(self.hostdata)
  response:send(s)
end

function HostConnection:receive()
  local request, response = unpack(self.hostdata)
  local data = request.data
  
  request.data = nil
  
  return data
end
  
return HostConnection
  
