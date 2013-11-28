--- API class. Extends the `proto` object.
--

local proto = require 'moonwalk/proto'
local sugar = require 'moonwalk/sugar'

local class = proto:extend()

class.is_api_class = true

--- Instantiate an API class.
-- This function is not meant to be called directly (see `proto.constructor`). 
--
-- @usage local api = require "moonwalk/api"
-- api.class "Customer Transactions" {
--   post = api.operation [[ ...
--   ]] .. function(customer, amount) -- ...
--   end, 
-- }
-- @param title Short description of the module.
-- @param operations Table containing operations.
function class:constructor(title, operations)
  self.title = title or ""
  self.operations = operations or {}
  return self
end

class.constructor = sugar.sweeten(class.constructor, 3)

return class

