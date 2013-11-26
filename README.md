# Moonwalk #

Moonwalk is a [Swagger][1] server implementation for Lua.

**Warning:** This project is under heavy development. The 
Moonwalk API is not stable. Moonwalk itself is not stable.
Don't use this in production (yet).

Moonwalk is designed to work under various host environments.
Currently Moonwalk supports [CGI][2], [Mongoose][3], [Civetweb][4], and
[LuaNode][5], as well as a built-in testing server, "SocketServer".
Support can easily be added for other host environments.

This document should cover most of what you need to get started.
For more advanced topics, see the [generated documentation
](http://abadc0de.github.io/moonwalk/docs).

[1]: http://developers.helloreverb.com/swagger/
[2]: http://www.ietf.org/rfc/rfc3875
[3]: https://github.com/cesanta/mongoose
[4]: https://github.com/sunsetbrew/civetweb
[5]: https://github.com/ignacio/luanode
[6]: http://luasocket.luaforge.net

## Installing ##

To get started with Moonwalk, you can clone this git repository, which
includes Moonwalk, the API Explorer, example code, and documentation.

    git clone https://github.com/abadc0de/moonwalk.git
    luarocks install moonwalk --from=moonwalk/rocks

If you don't need the API Explorer or any examples, you can install Moonwalk
without cloning the repository:

    luarocks install moonwalk --from=http://abadc0de.github.io/moonwalk/rocks

## Overview ##

### Index page ###

Your API's index page should something like this:

    -- index.lua

    -- 1: Load Moonwalk
    local api = require 'moonwalk/api'

    -- 2: Register APIs
    api:load_class 'user'
    api:load_class 'widget'
    api:load_class 'gadget'
    
    -- 3: Handle request
    api:handle_request(...)

1.  Require Moonwalk and assign it to a local variable.

2.  Call `api:load_class` once for each API class (see below).

3.  Call `api:handle_request`.
    Make sure to pass the ellipses (varargs) as shown.

### Documenting your API ###

Functions in your API should be decorated with doc blocks.
Valid tags include `@path`, `@param`, and `@return`.

Here's a quick example of a complete API with a single operation:

**user.lua**

    --- User API

    return {

      --- Create a new user.
      --
      -- @path POST /user/
      --
      -- @param email: User's email address.
      -- @param password: User's new password.
      -- @param phone (optional): User's phone number.
      --
      -- @return (number): User's ID number. 
      --
      create = function(email, password, phone) 
        return 123
      end,

    }

Moonwalk parses the docstring to determine the request method, resource
path, and parameters for the function.

### The @path tag ###

The `@path` tag is used to provide the HTTP request method and resource 
path for the operation. "Path parameters" may be included as part of the 
path, by enclosing the parameter name in braces. For example:

    @path GET /widget/{id}/

### The @param tag ###

The `@param` tag may contain additional information, enclosed in
parentheses, after the parameter name. This can include the
**data type**, the word "from" followed by the **param type**,
optionally separated by punctuation. It may also include punctuation 
after the parentheses to visually separate the description. For example:

    @param id (integer, from path): The ID of the widget to fetch.

### The @return tag ###

The `@return` tag may contain a data type annotation, enclosed in
parentheses, before the description, optionally followed by
punctuation. For example:

    @return (integer): The ID of the newly-created widget.

## Validation ##

In `@param` and `@return` tags, any **data type** name may be used,
but built-in type checking is only provided for the following:

`integer`, `number`, `string`, `boolean`, `object`, `array`

In `@param` tags, the **param type** determines how information is
sent to the API. Valid values are:

`path`, `query`, `body`, `header`, `form`

If the **data type** annotation is present, it *must be listed first*.
All other parenthesized annotations may be listed in any order.
Any annotation may be omitted, in which case the default values will be used.
If all annotations within the parentheses are omitted, the parentheses may
also be omitted.

The default **data type** is `string`, and the default **param type**
is determined as follows:

*   If the parameter name appears in curly brackets in the `@path`,
    the default param type is `path`.

*   If the HTTP method is `POST`, the default param type is `form`.

*   In all other cases, the default param type is `query`.

In addition to a **data type** and **param type**, the `@param` tag may
include additional validation annotations within the parentheses following
the parameter name. Recognized annotations draw from the [JSON Schema][8]
validation specification.

[8]:http://json-schema.org/latest/json-schema-validation.html

### Validation for all types ###

These validation annotations are available for any parameter.

*   **optional**

    By default, all parameters are required. To make a parameter optional,
    use the `optional` annotation.

### Numeric validation ###

These validation annotations are available for
`number` and `integer` parameters.

*   **maximum** *(partly implemented)*

    Numeric parameters may enforce a maximum value using the
    annotation `maximum N [exclusive]`, where *N* is 
    any valid number, optionally followed by `exclusive` to
    indicate that the value must be less than (but not equal to) *N*.

*   **minimum** *(partly implemented)*

    Numeric parameters may enforce a minimum value using the
    annotation `minimum N [exclusive]`, where *N* is 
    any valid number, optionally followed by `exclusive` to
    indicate that the value must be greater than (but not equal to) *N*.

*   **multipleOf**

    Numeric parameters may limit a value to being evenly divisible
    by a number using the annotation `multipleOf N`,
    where *N* is any valid number greater than 0.

### String validation ###

These validation annotations are available for`string` parameters.

*   **maxLength**

    String parameters may enforce a maximum length using the
    annotation `maxLength N`, where *N* is any valid
    non-negative integer.

*   **minLength**

    String parameters may enforce a minimum length using the
    annotation `minLength N`, where *N* is any valid
    non-negative integer.
    
*   **pattern** *(not yet implemented)*

    String parameters may be checked against a regular expression
    using the annotation `pattern P`, where *P* is any 
    valid regular expression, enclosed in backticks.
    
### Array validation ###

These validation annotations are available for `array` parameters.

*   **maxItems**

    Array parameters may enforce a maximum length using the
    annotation `maxItems N`, where *N* is any valid 
    non-negative integer.
    
*   **minItems**

    Array parameters may enforce a minimum length using the
    annotation `minItems N`, where *N* is any valid 
    non-negative integer.
    
*   **uniqueItems**

    Array parameters may ensure that every item in the array
    is unique using the `uniqueItems` annotation.
    
## Models ##

Models are a useful way to document how an object should look.
Currently no built-in validation is provided for models, but
some Swagger clients may use this information to provide 
client side validation or documentation. They also show up
in the API Explorer.

You can define models like this:

    local api = require "moonwalk/api"

    api.model "User" {
      id = {
        type = "integer",
        minimum = 1,
        description = "The user's ID number"
      },
      email = {
        description = "The user's email address"
      },
      name = {
        optional = true,
        description = "The user's full name"
      },
      phone = {
        type = "integer",
        optional = true,
        description = "The user's phone number",
      },
    }
    

This is essentially the `properties` object in a Swagger `models`
section. You can use the model name as a **data type** in your
`@param` and `@return` tags, and in other models. You can also use 
full Swagger-style model definitions. Models defined using the short 
syntax above will be converted to full definitions by `.model`.
See Swagger's [Complex Types][9] for more information.

[9]:https://github.com/wordnik/swagger-core/wiki/Datatypes#complex-types

## Host environments ##

Some host environments (SocketServer, LuaNode) use one Lua state
across multiple requests, while others (CGI, Mongoose, Civetweb)
handle each request in a separate Lua state. We'll call the first
category "persistent hosts" and the second "traditional hosts."

### SocketServer ###

Invoke the built-in Lua server like this:

    lua moonwalk/server/socket.lua /example/ 8910
    
Where `/example/` is your API root and `8910` is the port to use.

### LuaNode ###

Experimental support for LuaNode is included. Invoke the server like this:

    /path/to/luanode moonwalk/server/luanode.lua /example/ 8910
    
Where `/example/` is your API root and `8910` is the port to use.

### Mongoose/Civetweb ###

Mongoose/Civetweb support is included. Invoke the server like this:

    /path/to/server/binary \
    -document_root /srv/www/moonwalk/ \
    -url_rewrite_patterns /example/**=example/index.lp

### Apache CGI Setup ###

Use this Apache vhost configuration and .htaccess file
as an example.

#### Apache vhost config ####

    <VirtualHost *:80>
        ServerName moonwalk.local
        DocumentRoot /srv/www/moonwalk
        <Directory /srv/www/moonwalk>
            Options +ExecCGI
            AddHandler cgi-script .lua
            DirectoryIndex index.lua index.html
            AllowOverride All
            Order allow,deny
            allow from all
        </Directory>
    </VirtualHost>

#### Apache .htaccess ####

    RewriteEngine On
    RewriteCond $1 !(^index\.lua)
    RewriteRule ^(.*)$ index.lua/$1 [L]

#### CGI troubleshooting ####

*   Make sure the shebang line has the correct path to the Lua executable.
    For example, `#! /usr/bin/lua` may need to become `#! /usr/local/bin/lua`.
  
*   Make sure any files with the shebang are executable (chmod +x).



## License ##

Copyright &copy; 2013 Moonwalk Authors

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

## References ##

Lua references:

*   [Lua 5.2 user manual](http://www.lua.org/manual/5.2/)

Swagger references:

*   [Swagger wiki](https://github.com/wordnik/swagger-core/wiki)

CGI references:

*   [CGI spec](http://www.ietf.org/rfc/rfc3875)

*   [Apache CGI docs](http://httpd.apache.org/docs/2.2/howto/cgi.html)

Mongoose and Civetweb references:

*   [Mongoose Lua server pages](https://github.com/cesanta/mongoose/blob/master/docs/LuaSqlite.md)

*   [Mongoose users group](http://groups.google.com/group/mongoose-users)

*   [Civetweb users group](http://groups.google.com/group/civetweb)

