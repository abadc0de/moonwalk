--- API model.  Extends the `proto` object.
--

local proto = require 'moonwalk/proto'
local sugar = require 'moonwalk/sugar'

local model = proto:extend()

--- Whether model properties are required by default.
--
-- When this is true, it can be overriden by adding `optional = true`
-- to model property definitions.
-- When it's false, it can be overriden by adding `required = true`.
--
-- Defaults to `true`.
--
model.properties_required = true

function model:constructor(name, properties)
  self.name = name
  self.properties = properties
  self.final = nil
  self.refs = nil
  return self
end

model.constructor = sugar.sweeten(model.constructor, 3)

--- Finalize a model definition.
function model:finalize()

  local required = {}
  
  if self.final then return self.final, self.refs end
  
  if self.properties.properties then
    self.final = self.properties
    return self.final, self.refs
  end
  
  self.final = { properties = m.properties }
  
  -- ensure the model's id is the same as its key.
  self.final.id = name
  
  -- iterate through property definitions
  for k, v in pairs(m.properties) do
    -- default data type is string
    if not v.type then v.type = 'string' end
    -- allow optional/required in property definitions 
    if self.properties_required then
      if v.optional then
        v.optional = nil
      else
        table.insert(required, k)
      end
    else
      if v.required then
        v.required = nil
        table.insert(required, k)
      end
    end
    -- if this model references another, insert it into the table also.
    table.insert(self.refs, v.type)
    -- insert_model(v.type, finalize_model(v.type))
  end
  
  -- if model properties are required by default, or the "required" property
  -- is being used in property definitions, overwrite the "required" array 
  -- (if it exists) with our new values.
  if #required > 0 then self.final.required = required end

  return self.final, self.refs

end

--- Finalize a model definition and insert it into a table.
function model:insert_into(table, models)
  if (not table) or table[name] then return end
  -- insert the model into the target table
  local model, related = self:finalize()
  -- find any related models and insert them too
  if model and related then
    table[name] = model
    for _, v in ipairs(related) do models[v]:insert_into(table) end
  end
end


return model

