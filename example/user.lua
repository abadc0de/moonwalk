local api = require 'moonwalk/init'

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

return api.class "User stuff" {
  
  delete = api.operation [[
  
    Delete a user
    
    Permanantly delete a user from the database.
    Warning: this operation cannot be undone.
    
    @path DELETE /user/{id}/  
    
    @param id (integer, minimum 1, maximum 20, multipleOf 3) - ID of the user to delete.
    @param reason (optional, maxLength 20) - Reason the user is being deleted.
    @param dryRun (boolean) - Don't really delete the user.
    
    @return (boolean): Returns `true` if successful, else `false`.
  
  ]] .. 
  function(id, reason, dryRun, connection)
  
    return {status = "success", message = "user deleted", 
        request = connection.request }
  
  end,
  
  read = api.operation [[
  
    Get a user
    
    @path GET /user/{id}/  
    
    @param id (integer, minimum 1): ID of the user to load.
    
    @return (User): User details.
  
  ]] ..
  function(id, connection)
    
    return { id = id, name = "bob", request = connection.request }
  
  end,
  
  create = api.operation [[
  
    Create a user
    
    @path POST /user/  
    
    @param email: The user's valid email address.
    @param password: The user's password.
    @param name (optional): The user's name.
    @param phone (integer, optional, minimum 1000000000): The user's phone number.
    
    @return (User): The newly created user.
  
  ]] ..
  function(email, password, name, phone)
    
    return { id = 1, email = email, name = name, phone = phone }
  
  end,
  
}

