#!/usr/bin/env lua

local api = require 'moonwalk/api'

api:load_class 'moonwalk/resources'
api:load_class 'user'

api:handle_request(...)

