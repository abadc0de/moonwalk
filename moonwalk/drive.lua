
-- Drive - Utility stuff for paths and files.

local function include(module)
  local out
  pcall(function() out = require(module) end)
  return out
end

-- install these with luarocks (recommended, optional)
local mimetypes = include 'mimetypes'
local lfs = include 'lfs'

-- mime types for the API explorer.
local mime_types = {
  ['.html'] = "text/html",
  ['.css'] =  "text/css",
  ['.js'] =   "text/javascript",
  ['.png'] =  "image/png",
}

-- loaded Lua scripts.
local lua_scripts = {}

-- run a Lua script given a filename.
local function run_script(filename, hostdata)
  local script = lua_scripts[filename]
  if not script then
    script = assert(loadfile(filename))
    lua_scripts[filename] = script
  end
  return script(hostdata)
end

-- determine if path (file or directory) exists
local path_exists = lfs and function(path)
  -- use luafilesystem if available.
  return not not lfs.attributes(path, 'mode')
end or function(path)
  -- hack: if we can rename it, it must exist.
  -- caveat: rename could fail if we have read access but no write access.
  local _, fail = os.rename(path, path)
  return not fail
end

-- determine if path is a directory
local is_directory = lfs and function(path)
  -- use luafilesystem if available.
  return lfs.attributes(path, 'mode') == 'directory'
end or function(path)
  -- hack: if we can cd into it, it must be a directory.
  -- caveat: not every OS has a cd command.
  return os.execute("cd " .. path) == 0
end

local last_modified = function(path)
  return lfs and lfs.attributes(path ,'modified')
end

-- guess mime type given a filename
local guess_mime_type = mimetypes and function(filename)
  -- use mimetypes package if available.
  return mimetypes.guess(filename)
end or function(filename)
  -- use built-in mime type associations.
  return mime_types[filename:match '.*(%..*)$']
end

return {
  mime_types = mime_types,
  lua_scripts = lua_scripts,
  run_script = run_script,
  path_exists = path_exists,
  is_directory = is_directory,
  last_modified = last_modified,
  guess_mime_type = guess_mime_type,
}
