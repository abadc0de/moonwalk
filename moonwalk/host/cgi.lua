-- CGI support
-- http://www.ietf.org/rfc/rfc3875

local request_info = {
  -- auth_type = os.getenv 'AUTH_TYPE',
  -- content_length = os.getenv 'CONTENT_LENGTH',
  content_type = os.getenv 'CONTENT_TYPE',
  -- gateway_interface = os.getenv 'GATEWAY_INTERFACE',
  path_info = os.getenv 'PATH_INFO',
  -- path_translated = os.getenv 'PATH_TRANSLATED',
  query_string = os.getenv 'QUERY_STRING',
  -- remote_addr = os.getenv 'REMOTE_ADDR',
  -- remote_host = os.getenv 'REMOTE_HOST',
  -- remote_ident = os.getenv 'REMOTE_IDENT',
  -- remote_user = os.getenv 'REMOTE_USER',
  request_method = os.getenv 'REQUEST_METHOD',
  -- script_name = os.getenv 'SCRIPT_NAME',
  -- server_name = os.getenv 'SERVER_NAME',
  -- server_port = os.getenv 'SERVER_PORT',
  -- server_protocol = os.getenv 'SERVER_PROTOCOL',
  -- server_software = os.getenv 'SERVER_SOFTWARE',
}

local HostConnection = {}

function HostConnection:get_request_info()
  return request_info
end

function HostConnection:get_base_path()
  local domain = os.getenv 'SERVER_NAME'
  local scheme = os.getenv 'HTTPS' and 'https' or 'http'
  local port = os.getenv 'SERVER_PORT'
  local path = os.getenv 'SCRIPT_NAME':match '(.+)/' or ''
  local port_segment = ''
  
  if port == '443' then scheme = 'https' end
  
  if (scheme == 'http' and port ~= '80') or
      (scheme == 'https' and port ~= '443') then
    port_segment = ':' .. port
  end
  
  return scheme .. '://' .. domain .. port_segment .. path
end

function HostConnection:get_header(name)
    local env_var = 'HTTP_' .. name:gsub('.', string.upper):gsub('-', '_')
    
    return os.getenv(env_var)
end

function HostConnection:send_head(status, headers) 
  io.stdout:write('Status: ' .. status .. '\n')
  for k, v in pairs(headers) do
    io.stdout:write(k .. ': ' .. v .. '\n')
  end
  io.stdout:write('\n')
end

function HostConnection:send(s)
  io.stdout:write(s)
end

function HostConnection:receive()
  return io.stdin:read()
end
  
return HostConnection

