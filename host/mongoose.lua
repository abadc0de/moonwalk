local headers = mg.request_info.http_headers

-- TODO: This is a hack. We assume the first segment of the URI
-- is the script's directory, because there's not enough info in
-- mg.request_info to figure it out.
local api_root = mg.request_info.uri:match('^/[^/]*')

local data_sent = false

return {

  request_info = {
    content_type = headers['Content-Type'],
    path_info = mg.request_info.uri:gsub('^' .. api_root, ''),
    query_string = mg.request_info.query_string,
    request_method = mg.request_info.request_method,
  },
  
  get_base_path = function()
    local scheme = 'http' -- TODO: detect https?
    
    return 'http://' .. headers['Host'] .. api_root
  end,
  
  get_header = function(name) return headers[name] end,
  
  send = function(s)
    if not data_sent then
      local status = s:match('Status: (.-)[\r\n]') or '200 OK'
      mg.write('HTTP/1.0 ' .. status .. '\n')
      data_sent = true
    end
    mg.write(s)
  end,
  
  receive = function() return mg.read() end,

}

