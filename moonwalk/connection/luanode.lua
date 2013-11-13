--- LuaNode support
--
-- https://github.com/ignacio/luanode
--

local unpack = table.unpack or unpack

local connection = {}

function connection:detect_host()
  local version = _G.process and _G.process.version
  local loaded = package.loaded['luanode.http']
  return version and loaded and 'LuaNode ' .. version
end

function connection:get_method()
  local request, response = unpack(self.hostdata)
  return request.method
end

function connection:get_path()
  local request, response = unpack(self.hostdata)
  return '/' .. (request.url:match('(.-)?') or request.url)
      :gsub('^' .. request.mw.api_root, '')
end

function connection:get_scheme()
  -- TODO: detect https
  return 'http'
end

function connection:get_script()
  local request, response = unpack(self.hostdata)
  return request.mw.api_root .. 'index.lua'
end

function connection:get_query()
  local request, response = unpack(self.hostdata)
  return request.url:match '?(.*)'
end

function connection:get_header(name)
  local request, response = unpack(self.hostdata)

  return request.headers[name:gsub('.', string.lower)]
  
end

function connection:send_head(status, headers)
  local request, response = unpack(self.hostdata)
  
  -- local reason = status:match('^%d+%s(.*)$')
  status = tonumber(status:match('^%d+'))
  response:writeHead(status, --[[ reason, ]] headers)
end

function connection:send(s)
  local request, response = unpack(self.hostdata)
  
  response:write(s)
end

function connection:receive()
  local request, response = unpack(self.hostdata)
  if not request.mw.body then return end
  local out = table.concat(request.mw.body, '')
  
  request.mw.body = nil
  
  return out
end
  
return connection
  
