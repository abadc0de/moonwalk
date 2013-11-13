-- LuaDoc config

package = 'moonwalk'
project = 'Moonwalk API'
title = 'Moonwalk API'
description = 'Moonwalk'
full_description = [[Zero-friction REST APIs for Lua.

For normal use, the only module you'll need to require is `moonwalk`.
The readme covers most of what you need to know to create an API,
but you may want to look at the docs for `moonwalk` and `moonwalk.config`.

You may also want to use `drive` to help serve files, or `proto` for
simple OOP-style inheritance, or take advantage of the text processing
utilities in `util`.

To add support for a new host environment, see `connection.abstract`.
For ideas on creating your own stand-alone server, take a look at the
`server.socket` and `server.luanode` source .

]]
file = {'moonwalk', exclude = {
  'moonwalk/lib/', 
  'moonwalk/init.lua',
  'moonwalk/connection/cgi.lua',
  'moonwalk/connection/luanode.lua',
  'moonwalk/connection/mongoose.lua',
  'moonwalk/connection/socket.lua',
}}
dir = 'docs'
all = false
format = 'markdown'
