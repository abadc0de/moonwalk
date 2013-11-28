--- User stuff
--

local api = require 'moonwalk/api'

api.model "User" {
  id = {
    type = "integer",
    minimum = 1,
    description = "The user's ID number"
  },
  email = {
    description = "The user's email address"
  },
  name = {
    optional = true,
    description = "The user's full name"
  },
  phone = {
    type = "integer",
    optional = true,
    description = "The user's phone number",
  },
}

local fake_db = {}
local next_id = 1

local user = {
  
  --- Get a user
  --  
  -- @path GET /user/{id}/  
  --  
  -- @param[type=integer,minimum=1] id ID of the user to load.
  -- 
  -- @return[type=User] User details.
  --

  read = function(id, connection)
    local target = fake_db[id]
    if target then
      return target
    else
      return nil, "user does not exist"
    end
  end,
  
  --- Create a user
  --
  -- @path POST /user/  
  --
  -- @param email The user's valid email address.
  -- @param password The user's password.
  -- @param[opt] name The user's name.
  -- @param[opt] phone The user's phone number.
  --
  -- @return[type=User] The newly created user.
  create = function(email, password, name, phone)
    fake_db[next_id] = { 
        id = next_id, email = email, name = name, phone = phone
    }
    next_id = next_id + 1
  end,
  
}

--- Delete a user
-- 
-- @path DELETE /user/{id}/  
-- 
-- @param[type=integer] id ID of the user to delete.
-- @param[opt] reason Reason the user is being deleted.
-- @param[type=boolean] dryRun Don't really delete the user.
-- 
-- @return[type=User] Deleted user details.
--
function user.delete(id, reason, dryRun, connection)
  local target = fake_db[id]
  if target then
    table.remove(fake_db, id)
    return target
  else
    return nil, "user does not exist"
  end
end

return user
