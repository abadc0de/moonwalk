-- LuaDoc config

package = 'moonwalk'
project = 'Moonwalk API'
title = 'Moonwalk API'
description = 'Moonwalk'
full_description = [[Zero-friction REST APIs for Lua.

For normal use, you'll only need to require the `api` module.
`README.md` covers most of what you need to know to create an API.

You may also want to use `drive` to help serve files, or `proto` for
simple OOP-style inheritance, or take advantage of the text processing
utilities in `util`.

To add support for a new host environment, see `connection.abstract`
(and for ideas on creating your own stand-alone server, take a look
at the `server.socket` and `server.luanode` source).

]]
file = {'moonwalk', 'example', exclude = {
  'example/moonwalk/', 
  'moonwalk/lib/', 
  'moonwalk/connection/cgi.lua',
  'moonwalk/connection/luanode.lua',
  'moonwalk/connection/mongoose.lua',
  'moonwalk/connection/socket.lua',
}}

examples = {'example', exclude = { 'example/moonwalk/' }}

readme = { 
  'README.md',
}

custom_tags = {
  { 'path', title = 'Resource path', format = function(v) return
    '<pre>' .. v:gsub('^%s-(%w+)', '<b>%1</b>') .. '</pre>' end }, 
} 


sort_modules = true
sort = false

dir = 'docs'
all = false
format = 'markdown'
style = 'explorer/css/'
not_luadoc=true
