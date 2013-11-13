--- CGI support
--
-- http://www.ietf.org/rfc/rfc3875
--

local connection = {}

function connection:detect_host() 
  return os.getenv 'GATEWAY_INTERFACE'
end

function connection:get_method()
  return os.getenv 'REQUEST_METHOD'
end

function connection:get_path()
  return os.getenv 'PATH_INFO'
end

function connection:get_scheme()
  if os.getenv 'HTTPS' or os.getenv 'SERVER_PORT' == '443' then
    return 'https'
  else
    return 'http'
  end
end

function connection:get_script()
  return os.getenv 'SCRIPT_NAME'
end

function connection:get_query()
  return os.getenv 'QUERY_STRING'
end

function connection:get_header(name)
    local env_var = 'HTTP_' .. name:gsub('.', string.upper):gsub('-', '_')
    
    if env_var == 'HTTP_CONTENT_TYPE' then 
      return os.getenv 'CONTENT_TYPE'
    end
    
    if env_var == 'HTTP_CONTENT_LENGTH' then 
      return os.getenv 'CONTENT_LENGTH'
    end
    
    return os.getenv(env_var)
end

function connection:send_head(status, headers) 
  io.stdout:write('Status: ' .. status .. '\n')
  for k, v in pairs(headers) do
    io.stdout:write(k .. ': ' .. v .. '\n')
  end
  io.stdout:write('\n')
end

function connection:send(s)
  io.stdout:write(s)
end

function connection:receive()
  return io.stdin:read()
end
  
return connection

