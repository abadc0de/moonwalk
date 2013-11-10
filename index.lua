#!/usr/bin/env lua

local moonwalk = require 'moonwalk/init'
local markdown = require 'moonwalk/lib/markdown'
local conn = moonwalk.get_connection(...)

conn:populate_request_table()

conn:send_head('200 OK', { ['Content-Type'] = 'text/html' })

conn:send [[<!doctype html>
<html>
<head><title>Moonwalk</title>
<style>
body { font: 14px "Droid Sans", sans-serif; color: #333; margin:0; padding: 0;
  line-height: 150%; }
#header { background: black; height: 100px; color: #ccc; z-index: 1; 
  box-shadow: 0 0 4px black; line-height: 48px; width: 100%;
  -webkit-transition: height 0.5s linear; }
#header .wrap { margin: auto; padding: 0; max-width: 960px; height:100%; 
  background: black url(explorer/images/moonrise.png) no-repeat 50% 100%; 
  background-size: auto 180%; box-shadow:0 0 20px black inset;
  position:relative; -webkit-transition: background 5s linear; }
#header .dummy { display: inline-block; vertical-align:middle; height:100%; }
#header h1 { margin: 0; padding: 0; position: absolute; left: 0%; top: 50%; 
  line-height: 1px; }
#header h1, #header h1 a { color: #eee; font-weight: normal;  }
#header h1, #header h1 a:hover { color: #fff; }
#header p { display: inline-block; margin: 0; padding: 0;  
position: absolute; right: 0%; top: 50%; line-height: 1px; }
#header.sticky { position: fixed; top: 0; height: 48px; }
#header.sticky h1 {   }
#header.sticky .wrap {
  background-size: auto 250%; background-position: 50% 97%; }
.content { margin: auto; padding: 30px 0; max-width: 960px; }
h1, h2, h3, h4, h5, h6 { color: #999; }
h2 { border-bottom: 1px solid #999; }
a { color: #69f; font-weight: bold; text-decoration: none; }
code { background: #f3f3f3; border: 1px solid #ddd; border-radius: 3px; 
  padding: 0 2px; display: inline-block; }
pre code { padding: 1em; display: block; }
</style>
<script>
var stuck;
function stickHead() {
  var header = document.getElementById('header');
  function stick() {
    if (!stuck) {
      stuck = true;
      header.style.position = 'fixed';
      header.nextSibling.style.position = 'relative'; 
      header.nextSibling.style.top = '100px'; 
    }
    if (document.body.scrollTop > 1) {
      if (!header.className) header.className = 'sticky';
    } else {
      if (header.className) header.className = null;
    }
  }
  stick();
  onscroll = null;
  setTimeout(function(){ stick(); onscroll = stickHead }, 1500)
}
onscroll = stickHead
</script>
</head><body>
<div id="header"><div class="wrap">
  <span class="dummy"></span>
  <h1><a href="#">Moonwalk</a></h1>
  <p>Zero-friction REST APIs for Lua</p>
</div></div><div class="content">
<h1> It works! </h1>
<p> Moonwalk appears to be working properly. You may want to try the
<a href="./explorer/">API Explorer</a> with the example API, or read
the documentation below.</p>
]]

conn:send("<dt> Host environment: </dt><dd>" .. conn.name .. "</dd>")

conn:send(markdown(io.open 'README.md':read '*a'))

conn:send '</div></body></html>'

