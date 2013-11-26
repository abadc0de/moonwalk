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
  -- @param id (integer, minimum 1): ID of the user to load.
  -- 
  -- @return (User): User details.
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
  -- @param email: The user's valid email address.
  -- @param password: The user's password.
  -- @param name (optional): The user's name.
  -- @param phone (integer, optional, minimum 1000000000): The user's phone number.
  --
  -- @return (User): The newly created user.
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
-- @param id (integer, minimum 1, maximum 20, multipleOf 3) - ID of the user to delete.
-- @param reason (optional, maxLength 20) - Reason the user is being deleted.
-- @param dryRun (boolean) - Don't really delete the user.
-- 
-- @return (User): Deleted user details.
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
