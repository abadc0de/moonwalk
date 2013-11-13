--- Simple prototypal inheritance.
--

local proto

local function new(this, ...)
  local that = (this.extend or proto.extend)(this)
  that:constructor(...)
  return that
end

proto = {

  --- Set `this` as `that`'s metatable index. 
  --
  -- @param this The object being extended; the parent.
  -- @param that The object extending the parent (optional).
  -- @param meta Custom meta table (optional).
  --
  -- @return The child object (`that`).
  --
  extend = function(this, that, meta)
    if not that then that = {} end
    if not meta then meta = { __index = this, __call = new } end
    return setmetatable(that, meta)
  end,

  --- Constructor function.
  --
  -- Override this function as needed. Objects which extend `proto`
  -- can be invoked as functions to create new "instance" objects.
  -- This function will be invoked at that time.
  --
  -- Invoking a `proto` extension as a function always returns a
  -- newly-created object. The return value of `constructor` is 
  -- discarded.
  --
  -- @param self The newly-created "instance" object.
  --
  constructor = function() end,

}

return setmetatable(proto, { __call = new })

