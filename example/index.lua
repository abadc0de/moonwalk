#! /usr/bin/lua

package.path = "../?.lua;" .. package.path

local api = require 'moonwalk'

api.config.pretty_json = true

api.register 'user'

api.handle_request()
