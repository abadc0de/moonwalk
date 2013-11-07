package = "moonwalk"
version = "1.0-1"
source = { url = "../moonwalk", dir = "moonwalk" }
description = {
   summary = "Zero-friction REST APIs for Lua.",
   
   detailed = [[Moonwalk is a Swagger server implementation for Lua.

Moonwalk is designed to work under various host environments. 
Currently includes support for CGI, Mongoose/Civetweb, LuaNode.
Support can easily be added for other host environments.]],

   homepage = "https://github.com/abadc0de/moonwalk",
   
   license = "MIT"
}
dependencies = {
   "lua >= 5.1"
   -- If you depend on other rocks, add them here
}
build = {
   type = "builtin",
   modules = {
      ["moonwalk"] = "init.lua",
      
      ["moonwalk.init"] = "init.lua",
      ["moonwalk.config"] = "config.lua",
      ["moonwalk.proto"] = "proto.lua",
      ["moonwalk.util"] = "util.lua",
      
      ["moonwalk.host.cgi"] = "host/cgi.lua",
      ["moonwalk.host.luanode"] = "host/luanode.lua",
      ["moonwalk.host.mongoose"] = "host/mongoose.lua",
      
      ["moonwalk.lib.json"] = "lib/json.lua",
      ["moonwalk.lib.markdown"] = "lib/markdown.lua",
      ["moonwalk.lib.memoize"] = "lib/memoize.lua",
      
      ["moonwalk.server.luanode"] = "server/luanode.lua",
   }
}
