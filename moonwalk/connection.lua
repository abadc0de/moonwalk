--- Connection between host and client. 
-- Extends a base object implementing the interface described in
-- `connection.abstract`. 
--
-- The base object is determined at run time. It could be a built-in
-- connection type, or a new type defined by the API author.
--
--
local util = require 'moonwalk/util'

local connection = {}

-- Unpack a sparse numeric table with a "length" property
-- http://www.lua.org/pil/5.1.html
local function unpack_args(t, i)
  i = i or 1
  if i <= t.length then
    return t[i], unpack_args(t, i + 1)
  end
end

--- Set up connection.
--
-- Sets `self.hostdata` and populates `self.request`.
-- 
-- @param hostdata Information the host environments may need to
-- deal with the connection.
-- 
function connection:constructor(hostdata)
  self.hostdata = hostdata
  
  local request = {}
  local path = self:get_path()
  local method_override = self:get_header 'X-HTTP-Method-Override'
  local content_type = self:get_header 'Content-Type'
  local content_length = self:get_header 'Content-Length'
  
  request.method = method_override or self:get_method()
  request.path = path
  request.body = ''
  request.form = {}
  request.query = util.query_decode(self:get_query())
  request.header = setmetatable({}, {
    __index = function(t, key) return self:get_header(key) end,
  })
  request.args = {}
  request.path_args = {}
  request.body_args = {}
  request.form_args = {}
  request.query_args = {}
  request.header_args = {}
  
  if content_length then
    for line in function() return self:receive() end do
      request.body = request.body .. line
    end
    if content_type == 'application/x-www-form-urlencoded' then
      request.form = util.query_decode(request.body)
    end
  end
  
  self.request = request

end

--- Send a failure message.
--  
-- @param reason Human-readable reason why the request failed. 
-- @param status HTTP status code and reason; defaults to `400 Bad Request`
--
function connection:fail(reason, status)
  if not status then status = '400 Bad Request' end
  self:send_head(status, { ['Content-Type'] = 'application/json' })
  self:send(util.json_encode({ error = reason }))
end

--- Handle the request.
--
function connection:handle_request()
  local api = self.api
  local request = self.request
  local path = util.trim_path(request.path)
  local result, op_err, op_status
  local fn, args, failure = api.operation:prepare(self)
  
  if failure then return failure.fail(self) end
  if fn and args then
    args.length = args.length and args.length + 1 or 1
    args[args.length] = self
    local _, err = pcall(function() 
      result, op_err, op_status = fn(unpack_args(args)) 
    end)
    if op_err then
      return self:fail(op_err, op_status or '400 Bad Request')
    end
    if err then
      return self:fail(err, '500 Internal Server Error')
    end
    self:send_head('200 OK', { ['Content-Type'] = 'application/json' })
    return self:send(util.json_encode(result))
  end
  self:fail('Resource does not exist', '404 Not Found')
  
end

return connection
