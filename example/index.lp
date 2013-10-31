<? xpcall(function()

  -- API loader for Mongoose
  package.path = "example/?.lua;" .. package.path
  require 'index'

end, print) ?>
