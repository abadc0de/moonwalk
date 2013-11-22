--- Simple prototypal inheritance.
--

local proto

local function new(this, ...)
  local that = (this.extend or proto.extend)(this)
  return that:constructor(...) or that
end

proto = {

  --- Constructor function.
  --
  -- Override this function as needed. Objects which extend `proto`
  -- can be *invoked as functions* to create new "instance" objects.
  -- This function will be called at that time.
  --
  -- Invoking a `proto` extension object as a function will return the
  -- newly-created instance object, unless `constructor` returns a
  -- truthy value, in which case that value is returned instead.
  -- In particular, returning nothing is equivalent to returning `self`.
  --
  -- @param self The newly-created "instance" object.
  --
  constructor = function() end,

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
    if not meta then meta = {} end
    if not meta.__index then meta.__index = this end
    if not meta.__call then meta.__call = new end
    return setmetatable(that, meta)
  end,

}

return setmetatable(proto, { __call = new })

