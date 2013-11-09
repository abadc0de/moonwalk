# Moonwalk #

Moonwalk is a [Swagger][1] server implementation for Lua.

Moonwalk is designed to work under various host environments.
Currently Moonwalk supports [CGI][2], [Mongoose][3], [Civetweb][4], and
[LuaNode][5], as well as a built-in testing server, "SocketServer".
Support can easily be added for other host environments. 

[1]: http://developers.helloreverb.com/swagger/
[2]: http://www.ietf.org/rfc/rfc3875
[3]: https://github.com/cesanta/mongoose
[4]: https://github.com/sunsetbrew/civetweb
[5]: https://github.com/ignacio/luanode
[6]: http://luasocket.luaforge.net

## Installing Moonwalk ##

To get started with Moonwalk, you can clone this git repository, which
includes Moonwalk, the API Explorer, example code, and documentation.

    git clone https://github.com/abadc0de/moonwalk.git
    luarocks install moonwalk --from=moonwalk/rocks

If you don't need the API Explorer or any examples, you can install Moonwalk
without cloning the repository:

    luarocks install moonwalk --from=http://abadc0de.github.io/moonwalk/rocks

## Usage ##

Basic usage looks something like this:

    -- index.lua

    -- 1: Load Moonwalk
    local api = require 'moonwalk'

    -- 2: Register APIs
    api.register 'user'
    api.register 'widget'
    api.register 'gadget'
    
    -- 3: Handle request
    api.handle_request(...)
    
1.  Require Moonwalk and assign it to a local variable.

2.  Call `.register` once for each documented API module (see below).
    Use `require`-style paths.

3.  Call `.handle_request(...)`. Make sure to pass the ellipses as
    shown, or LuaNode and SocketServer won't work.

## Documenting your API ##

Functions in your API should be decorated with doc blocks.
Valid tags include `@path`, `@param`, and `@return`.

Here's a quick example of a complete API with a single operation:

    -- user.lua

    local api = require "moonwalk"

    return api.module "User operations" {

      create = api.operation [[ 
        Create a new user.

        @path POST /user/

        @param email: User's email address.
        @param password: User's new password.
        @param phone (number, optional): User's phone number.
        
        @return (number): User's ID number. 
      ]] .. 
      function(email, password, phone) 
        return 123
      end,

    }

Instead of comments, the following construct is used to create a doc block:

*   The Moonwalk `operation` function 
*   The doc string, enclosed between `[[` and `]]` 
*   The concatenation operator, `..` 
*   A function definition (the "operation").

For some background on this technique, see the [DecoratorsAndDocstrings][7]
page in the Lua users wiki.

[7]: http://lua-users.org/wiki/DecoratorsAndDocstrings

### The @path tag ###

The `@path` tag is used to provide the HTTP request method and resource 
path for the operation. "Path parameters" may be included as part of the 
path, by enclosing the parameter name in braces. For example:

    @path GET /widget/{id}/

### The @param tag ###

The `@param` tag may contain additional information, enclosed in
parentheses, after the parameter name. This can include the
*data type*, the word "from" followed by the Swagger *param type*,
optionally separated by punctuation. It may also include punctuation 
after the parentheses to visually separate the description. For example:

    @param id (integer, from path): The ID of the widget to fetch.

Any *data type* name may be used, but built-in type checking is
only provided for the following:

`integer`, `number`, `string`, `boolean`, `object`, `array`

The *param type* determines how information is sent to the API.
Valid values are:

`path`, `query`, `body`, `header`, `form`

If the *data type* annotation is present, it **must be listed first**.
All other parenthesized annotations may be listed in any order.
Any annotation may be omitted, in which case the default values will be used.
If all annotations within the parentheses are omitted, the parentheses may
also be omitted.

The default *data type* is `string`, and the default *param type*
is determined as follows:

*   If the parameter name appears in curly brackets in the `@path`,
    the default param type is `path`.

*   If the HTTP method is `POST`, the default param type is `form`.

*   In all other cases, the default param type is `query`.

Other validation annotations may be also used within the parentheses.
See the "Validation" section below.

### The @return tag ###

The `@return` tag may contain a data type annotation, enclosed in
parentheses, before the description, optionally followed by
punctuation. For example:

    @return (integer): The ID of the newly-created widget.

## Validation ##

In addition to a *data type* and *param type*, the `@param` tag may
include additional validation annotations within the parentheses following
the parameter name. Recognized annotations draw from the [JSON Schema][8]
validation specification, in keeping with Swagger.

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
    annotation syntax `maximum N [exclusive]`, where *N* is 
    any valid number, optionally followed by `exclusive` to
    indicate that the value must be less than (but not equal to) *N*.

*   **minimum** *(partly implemented)*

    Numeric parameters may enforce a minimum value using the
    annotation syntax `minimum N [exclusive]`, where *N* is 
    any valid number, optionally followed by `exclusive` to
    indicate that the value must be greater than (but not equal to) *N*.

*   **multipleOf**

    Numeric parameters may limit a value to being evenly divisible
    by a number using the annotation syntax `multipleOf N`,
    where *N* is any valid number greater than 0.

### String validation ###

These validation annotations are available for`string` parameters.

*   **maxLength**

    String parameters may enforce a maximum length using the
    annotation syntax `maxLength N`, where *N* is any valid
    non-negative integer.

*   **minLength**

    String parameters may enforce a minimum length using the
    annotation syntax `minLength N`, where *N* is any valid
    non-negative integer.
    
*   **pattern** *(not yet implemented)*

    String parameters may be checked against a regular expression
    using the annotation syntax `pattern P`, where *P* is any 
    valid regular expression, enclosed in backticks.
    
### Array validation ###

These validation annotations are available for `array` parameters.

*   **maxItems**

    Array parameters may enforce a maximum length using the
    annotation syntax `maxItems N`, where *N* is any valid 
    non-negative integer.
    
*   **minItems**

    Array parameters may enforce a minimum length using the
    annotation syntax `minItems N`, where *N* is any valid 
    non-negative integer.
    
*   **uniqueItems**

    Array parameters may ensure that every item in the array
    is unique using the `uniqueItems` annotation.

## Apache CGI Setup ##

CGI may not be optimal for a production environment, but it
works nicely for development and testing. Use this Apache
vhost configuration and .htaccess file to get started
quickly.

### Example Apache vhost config ###

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

### Example Apache .htaccess ###

    RewriteEngine On
    RewriteCond $1 !(^index\.lua)
    RewriteRule ^(.*)$ index.lua/$1 [L]

### CGI troubleshooting ###

*   Make sure the shebang line has the correct path to the Lua executable.
    For example, `#! /usr/bin/lua` may need to become `#! /usr/local/bin/lua`.
  
*   Make sure any files with the shebang are executable (chmod +x).

## Mongoose/Civetweb setup ##

Mongoose/Civetweb support is currently a bit sketchy. Invoke the server
something like this to get things working the same as the CGI example.

    /path/to/server/binary \
    -document_root /srv/www/moonwalk/ \
    -url_rewrite_patterns /example/**=example/index.lp

There are a few fairly trivial features that could be added to Mongoose
and Civetweb to allow Moonwalk to better support those environments.
Some of these things are already being discussed, and will hopefully
be added in the somewhat near future.

## LuaNode setup ##

Experimental support for LuaNode is included. Invoke the sever like this:

    /path/to/luanode server/luanode.lua /example/ 8910
    
Where "/example/" is your API root and "8080" is the port to use.

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

