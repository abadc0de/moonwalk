#! /usr/bin/lua

local mw = require('moonwalk')
local markdown = require('lib/markdown')

mw.send [[Content-Type: text/html

<doctype html>
<head><title>Moonwalk</title>
<style>
body { font: 13px "Droid Sans", sans-serif; color: #333; margin:0; padding: 0;
  line-height: 150%; }
#header { height: 100px; color: white;
  background: black url(explorer/images/moonrise.png) no-repeat 50% 100%; 
  box-shadow:0 0 20px black inset, 0 0 4px black; }
#header .wrap { margin: auto; padding: 0 30px; max-width: 900px; }
#header h1, .header p { line-height: 100%; margin: 0; color: #eee; } 
#header h1 { padding-top: 24px; font-weight: normal; }
.content { margin: auto; padding: 30px; max-width: 900px; }
h1, h2, h3, h4, h5, h6 { color: #999; }
h2 { border-bottom: 1px solid #999; }
a { color: #69f; font-weight: bold; text-decoration: none; }
code { background: #f3f3f3; border: 1px solid #ddd; border-radius: 3px; 
  padding: 0 2px; display: inline-block; }
pre code { padding: 1em; display: block; }
</style>
</head><body>
<div id="header"><div class="wrap">
  <h1>Moonwalk</h1>
  <p>Zero-friction REST APIs for Lua</p>
</div></div>
<div class="content">
]]

mw.send(markdown(io.open 'README.md':read '*a'))

mw.send '</div></body>'
