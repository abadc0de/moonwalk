--- Syntax sugar.
--

return {
  --- Sweeten a function. This effectively allows functions taking multiple
  -- arguments to be "called without parentheses." You probably don't need
  -- to use this.
  --
  -- @param fn A function taking a fixed number of non-optional arguments.
  --
  -- @param argc The number of arguments `fn` takes. If `fn` is a table
  -- method, `argc` should include the hidden `self` argument.
  --
  -- @return A wrapper function for `fn`.
  -- If the wrapper is called with less than `argc` arguments, it will
  -- return a *continuation object* that can be called or concatenated
  -- with any remaining arguments. Otherwise, it will tail-call `fn`
  -- and return the result.
  --
  
  sweeten = function(fn, argc)
    local wrapper
    
    argc = tonumber(argc) or 2

    local function unpack_plus(t, i, ...)
      i = i or 1
      if i <= #t then
        return t[i], unpack_plus(t, i + 1, ...)
      else
        return ...
      end
    end
    
    local function resume(t, ...)
      return wrapper(unpack_plus(t, 1, ...))
    end
    
    local meta = { __call = resume, __concat = resume }

    wrapper = function(...)
      if select('#', ...) >= argc then
        return fn(...)
      else
        return setmetatable({...}, meta)
      end
    end
    
    return wrapper
  end,
}

