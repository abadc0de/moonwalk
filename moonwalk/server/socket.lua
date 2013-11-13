#!/usr/bin/env lua

--- Moonwalk SocketServer
--
-- A simple server inspired by
-- [this post](http://lua-users.org/lists/lua-l/2002-04/msg00180.html).
--
-- @usage
-- lua moonwalk/server/socket.lua /example/ 8910
--

_G.MOONWALK_SOCKETSERVER_VERSION = 0.1

local socket = require 'socket'
local drive = require 'moonwalk/drive'

local tinsert = table.insert
local tremove = table.remove
local timeout = .001

local SocketServer = {
  file_root = '.', 
  api_root = nil,
  port = nil,
}

-- redirect request
function SocketServer:redirect(client, location)
  self:sendHead(client, '302 Redirect', { Location = location })
  self:send(client, '')
end

function SocketServer:run()
  self.server = socket.bind("localhost", self.port)
  self.server:settimeout(timeout)
  self.clients = {}
  print("SocketServer running on port "..self.port)
  self:mainLoop()
end

function SocketServer:sendHead(client, status, headers)
  local head = "HTTP/1.1 " .. status .. '\n'

  for k, v in pairs(headers) do
    head = head .. k .. ': ' .. v .. '\n'
  end

  client:send(head)
end

function SocketServer:send(client, body)
  client:send("Content-Length: " .. #body .. "\n\n" .. body)
end
  
local is_path_set = false

function SocketServer:handleRequest(client, request)

  local filename = self.file_root .. request.path
  local server = self
  local response = {
    data = {},
    sendHead = function(self, status, headers)
      server:sendHead(client, status, headers)
    end,
    send = function(self, data)
      tinsert(self.data, data) 
    end,
  }
  local hostdata = { request, response }

  if request.uri:match('^' .. self.api_root) then
    filename = self.file_root .. self.api_root .. 'index.lua'
    if not is_path_set then
      package.path = self.file_root .. self.api_root .. "?.lua;" .. package.path
      is_path_set = true
    end
  end
    
  if drive.path_exists(filename) then -- requested path exists

    -- client requested a directory?
    if drive.is_directory(filename) then
      -- make sure path is terminated by a slash,
      -- perform redirect if needed
      if not request.path:match '/$' then
        return self:redirect(client, request.uri .. '/')
      end
      -- use index.lua or index.html
      local index = filename .. '/index.lua' 
      if drive.path_exists(index) then 
        filename = index
      else
        filename = filename .. '/index.html'
      end
    end
    
    -- client requested a .lua file?
    if filename:match '.lua$' then
    
      drive.run_script(filename, hostdata)
      
      if response.data then
        self:send(client, table.concat(response.data, ''))
      else
        self:send(client, '')
      end
    
    else
    
      local inm = request.headers['If-None-Match']
      local etag = tostring(drive.last_modified(filename))
    
      if inm == etag then
        self:sendHead(client, '304 Not Modified', {})
        self:send(client, '')
        return
      end
    
      -- serve up static files (API explorer)
      local data
      
      xpcall(function() 
          data = io.open(filename):read '*a'
      end, function(err)
        self:sendHead(client, '500 Internal Server Error', 
            { ["Content-Type"] = "text/plain" })
        self:send(client, err .. "\n")
        return
      end)
      
      local headers = {
        ["Content-Type"] = drive.guess_mime_type(filename),
        ["Cache-Control"] = 'private',
        ["Etag"] = etag,
      }
      self:sendHead(client, '200 OK', headers)
      self:send(client, data)
      
    end
  
  else -- requested path does not exist, send 404
  
    self:sendHead(client, '404 Not Found',
        { ["Content-Type"] = "text/plain" })
    self:send(client, "404 Not Found\n")
    return
    
  end

end

function SocketServer:handleClient(client)
  
  local request = { headers = {}, api_root = self.api_root }
  local data, status, part = client:receive()
  
  if err then
    print('error getting data from client: ' .. err)
    return
  end
  
  request.method, request.uri, request.protocol = 
      data:match '^(%a+)%s+(.-)%s+(.*)$'
      
  request.path = request.uri:match '^[^?]+'
  request.query = request.uri:match '?(.+)$'
  
  while data ~= '' do
    data, status, part = client:receive()
    local k, v = data:match '^(.-):%s+(.*)$'
    if status then print ('error receiving headers: ' .. status) end
    if k and v then request.headers[k] = v end 
  end
  
  local len = tonumber(request.headers['Content-Length'])
  
  if len and len > 0 then
    data, status, part = client:receive(len)
    if status then print ('error receiving body: ' .. status) end
    request.data = data
  end
  
  self:handleRequest(client, request)

end

function SocketServer:lookForNewClients()
  local client = self.server:accept()
  if client then
    client:settimeout(timeout)
    tinsert(self.clients, client)
  end
end

function SocketServer:mainLoop()
  local clients = self.clients
  
  local success, status = pcall(function()
  
    while 1 do
    
      self:lookForNewClients()

      local receivingClients, _, err = socket.select(clients, nil, timeout)
      if err and err ~= "timeout" then
        print("error: " .. err)
      end

      for i, client in ipairs(receivingClients) do
        SocketServer:handleClient(client)
        client:close()
        tremove(clients, i)
      end
      
    end
    
  end)
  
  -- If there was an error, dump it and exit.
  if status and not status:match 'interrupted!$' then
    print('\n' .. status)
    os.exit(1, 1)
  end
  
  print('\nSocketServer terminating.')
  
end

if arg and arg[0]:find("socket%.lua$") then
  SocketServer.api_root = arg[1] or '/example/'
  SocketServer.port = tonumber(arg[2]) or 8910
  SocketServer:run()
else
  return SocketServer
end


