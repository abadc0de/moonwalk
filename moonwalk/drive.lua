--- Filesystem utilities.
--
-- Used by the standalone servers `server.socket` and `server.luanode`.
-- Might also be useful within an `operation`. The `mimetypes` and `lfs`
-- modules are highly recommended, although this may work without them.
--

--- Include (but don't require) a module
local function include(module)
  local out
  pcall(function() out = require(module) end)
  return out
end

-- install these with luarocks (recommended, optional)
local mimetypes = include 'mimetypes'
local lfs = include 'lfs'

-- Loaded Lua scripts.
local lua_scripts = {}

-- MIME types for the API explorer.
local mime_types = {
  html = "text/html",
  css =  "text/css",
  js =   "text/javascript",
  png =  "image/png",
}

--- Guess a file's MIME type.
--
-- @param path Absolute or relative file path.
-- @return The MIME type string, or `nil` if unable to guess a type.
--
local function guess_mime_type(path)
  -- use mimetypes package if available.
  if mimetypes then return mimetypes.guess(path) end
  -- use built-in mime type associations.
  return mime_types[filename:match '.*%.(.*)$']
end

--- Determine if path is a directory.
--
-- @param path Absolute or relative file path.
-- @return `true` if the path is a directory, else `false`.
--
local function is_directory(path)
  -- use luafilesystem if available.
  if lfs then return lfs.attributes(path, 'mode') == 'directory' end
  -- hack: if we can cd into it, it must be a directory.
  -- caveat: not every OS has a cd command.
  return os.execute("cd " .. path) == 0
end

--- Get file's last modified date.
--
-- @param path Absolute or relative file path.
-- @return Timestamp representing the last modification time.
-- May return `nil` if unable to get a timestamp.
--
local function last_modified(path)
  return lfs and lfs.attributes(path ,'modified')
end

--- Determine if path (file or directory) exists.
--
-- @param path Absolute or relative file path.
-- @return `true` if the path exists, else `false`
--.
local function path_exists(path)
  -- use luafilesystem if available.
  if lfs then return not not lfs.attributes(path, 'mode') end
  -- hack: if we can rename it, it must exist.
  -- caveat: rename could fail if we have read access but no write access.
  local _, fail = os.rename(path, path)
  return not fail
end

--- Run a Lua script given a filename.
--
-- This is used to pass arbitrary data (`hostdata`) to the file
-- so that it is available to the `connection`.
--
-- @param path Absolute or relative file path.
-- @param hostdata Data the host can use later, sent through varargs.
-- @return The result of running the file.
--
local function run_script(path, hostdata)
  local script = lua_scripts[path]
  if not script then
    script = assert(loadfile(path))
    lua_scripts[path] = script
  end
  return script(hostdata)
end


--- @export
--
return {
  mime_types = mime_types,
  lua_scripts = lua_scripts,
  run_script = run_script,
  path_exists = path_exists,
  is_directory = is_directory,
  last_modified = last_modified,
  guess_mime_type = guess_mime_type,
}
