#!/usr/bin/env lua

--- LuaNode Server
--
-- A simple [LuaNode](https://github.com/ignacio/luanode) server.
--
-- @usage
-- luanode moonwalk/server/luanode.lua /example/ 8910
--
_G.MOONWALK_NODESERVER_VERSION = 0.1

local api_root = process.argv[1] or '/example/'
local port = tonumber(process.argv[2]) or 8124

local http = require "luanode.http"
local url = require "luanode.url"
local path = require "luanode.path"
local fs = require "luanode.fs"

local drive = require 'moonwalk/drive'

local is_path_set = false

-- mime types for the API explorer.
local mime_types = {
  ['.html'] = "text/html",
  ['.css'] =  "text/css",
  ['.js'] =   "text/javascript",
  ['.png'] =  "image/png",
}

-- redirect request
local function redirect(response, location)
  response:writeHead(302, { Location = location })
  response:finish()
end

-- create server
-- http://stackoverflow.com/questions/6084360
http.createServer(function(self, request, response)

  local uri = url.parse(request.url).pathname
  local filename = path.join(process:cwd(), uri)
  local hostdata = { request, response }
  
  request.mw = { api_root = api_root }
  
  if uri:match('^' .. api_root) then
    filename = path.join(process:cwd(), api_root .. 'index.lua')
    if not is_path_set then
      package.path = "." .. api_root .. "?.lua;" .. package.path
      is_path_set = true
    end
  end

  if drive.path_exists(filename) then -- requested path exists

    -- client requested a directory?
    if drive.is_directory(filename) then
      -- make sure path is terminated by a slash,
      -- perform redirect if needed
      if not request.url:match '/$' then
        return redirect(response, request.url .. '/')
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
      request.mw.body = {}
      request:on('data', function (self, data)
        if not data then return end
        table.insert(self.mw.body, data)
      end)
      request:on('end', function (self) 
        drive.run_script(filename, hostdata)
        response:finish()
      end)
      return
    end
    
    -- serve up static files (API explorer)
    fs.readFile(filename, "binary", function(err, file)
      if err then        
        response:writeHead(500, { ["Content-Type"] = "text/plain" })
        response:write(err .. "\n")
        response:finish()
        return
      end

      local headers = {}
      local contentType = drive.guess_mime_type(filename)
      if contentType then headers["Content-Type"] = contentType end
      response:writeHead(200, headers)
      response:write(file, "binary")
      response:finish()
    end)
  
  else -- requested path does not exist, send 404
  
    response:writeHead(404, { ["Content-Type"] = "text/plain" })
    response:write("404 Not Found\n")
    response:finish()
    return
    
  end
  
end):listen(port)

console.log("Moonwalk LuaNode server started on port "
    .. port .. " with web root [" .. process:cwd() .. "]")

process:loop()

console.log 'Server offline.'

