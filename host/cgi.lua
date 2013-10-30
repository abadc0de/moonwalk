return {

  -- http://www.ietf.org/rfc/rfc3875
  request_info = {
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
  },
  
  get_base_path = function()
    local domain = os.getenv 'SERVER_NAME'
    local proto = os.getenv 'SERVER_PROTOCOL'
    local scheme = proto:gsub('/.*', ''):gsub('.', string.lower)
    local port_number = os.getenv 'SERVER_PORT'
    local path = os.getenv 'SCRIPT_NAME':match '(.+)/' or ''
    local port = ''
    
    if (scheme == 'http' and port_number ~= '80') or
        (scheme == 'https' and port_number ~= '443') then
      port = ':' .. port_number
    end
    
    return scheme .. '://' .. domain .. port .. path
  end,
  
  get_header = function(name)
    local env_var = 'HTTP_' .. name:gsub('.', string.upper):gsub('-', '_')
    
    return os.getenv(env_var)
  end,
  
  send = function(s) print(s) end,
  
  receive = function() return io.stdin:read() end,

}

