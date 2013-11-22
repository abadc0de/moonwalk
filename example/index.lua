#!/usr/bin/env lua

local API = require 'moonwalk/api'
local api = API(1)

local connection = api:get_connection(...)
local send_head = connection.send_head

function connection:send_head(status, headers) 
  headers['Access-Control-Allow-Origin'] = '*'
  return send_head(self, status, headers)
end

api:load_class 'moonwalk/resources'
api:load_class 'user'

-- api.handle_request(...)
connection:handle_request()

