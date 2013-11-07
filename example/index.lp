<? xpcall(function()

  -- API loader for Mongoose
  package.path = "example/?.lua;example/?/init.lua;" .. package.path
  require 'index'

end, print) ?>
