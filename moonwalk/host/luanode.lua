-- LuaNode support
-- https://github.com/ignacio/luanode

local unpack = table.unpack or unpack

local HostConnection = {}

function HostConnection:get_request_info()
  local request, response = unpack(self.hostdata)

  return {
    content_type = request.headers['content-type'],
    path_info = '/' .. (request.url:match('(.-)?') or request.url)
        :gsub('^' .. request.mw.api_root, ''),
    query_string = request.url:match('?(.*)'),
    request_method = request.method,
  }
end

function HostConnection:get_base_path()
  local request, response = unpack(self.hostdata)

  return 'http://' .. request.headers.host .. request.mw.api_root
end

function HostConnection:get_header(name)
  local request, response = unpack(self.hostdata)

  return request.headers[name:gsub('.', string.lower)]
  
end

function HostConnection:send_head(status, headers)
  local request, response = unpack(self.hostdata)
  
  -- local reason = status:match('^%d+%s(.*)$')
  status = tonumber(status:match('^%d+'))
  response:writeHead(status, --[[ reason, ]] headers)
end

function HostConnection:send(s)
  local request, response = unpack(self.hostdata)
  
  response:write(s)
end

function HostConnection:receive()
  local request, response = unpack(self.hostdata)
  if not request.mw.body then return end
  local out = table.concat(request.mw.body, '')
  
  request.mw.body = nil
  
  return out
end
  
return HostConnection
  
