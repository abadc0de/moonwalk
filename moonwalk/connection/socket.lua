--- SocketServer support
--

local unpack = table.unpack or unpack

local connection = {}

function connection:detect_host()
  local version = _G.MOONWALK_SOCKETSERVER_VERSION
  return version and 'Moonwalk SocketServer ' .. version
end

function connection:get_method()
  local request, response = unpack(self.hostdata)
  return request.method
end

function connection:get_path()
  local request, response = unpack(self.hostdata)
  return request.path:gsub('^' .. request.api_root, '')
end

function connection:get_scheme()
  -- TODO: detect https
  return 'http'
end

function connection:get_script()
  local request, response = unpack(self.hostdata)
  return request.api_root .. 'index.lua'
end

function connection:get_query()
  local request, response = unpack(self.hostdata)
  return request.query
end

function connection:get_header(name)
  local request, response = unpack(self.hostdata)
  return request.headers[name]
end

function connection:send_head(status, headers)
  local request, response = unpack(self.hostdata)
  response:sendHead(status, headers)
end

function connection:send(s)
  local request, response = unpack(self.hostdata)
  response:send(s)
end

function connection:receive()
  local request, response = unpack(self.hostdata)
  local data = request.data
  
  request.data = nil
  
  return data
end
  
return connection
  
