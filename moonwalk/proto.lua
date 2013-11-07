-- simple prototype object for inheritance

local function new(this, ...)
  local that = this:extend()
  that:constructor(...)
  return that
end

return setmetatable({

  constructor = function() end,

  extend = function(this, that, meta)
    if not that then that = {} end
    if not meta then meta = { __index = this, __call = new } end
    return setmetatable(that, meta)
  end,

}, { __call = new })

