# ngx_aws_token

This repository provides a small Lua module for OpenResty that simplifies proxying
traffic to AWS services in web requests. Authorization tokens are automatically
rotated in shared storage, making it easier to proxy requests to AWS APIs.

The primary use case for `ngx_aws_token` is integrating a proxy layer with Amazon
services requiring token based authentication for web requests, such as Amazon ECR
or CodeArtifact. This module handles token rotation in the background, reducing
boilerplace in your Nginx configuration.

Rather than programmatically retrieving tokens, `ngx_aws_token` opts to use the
AWS to retrieve tokens. Therefore, the AWS CLI must be installed and available on
your system to use this module.

# Installation

You can use LuaRocks to install directly from this repository:

```bash
luarocks install ngx_aws_token
```

Or, because it really is just a single file, you can place `ngx_aws_token.lua`
directly into your OpenResty installation at `/usr/local/openresty/lualib`.

For example if you're using a Docker build of OpenResty, you can add this
module via an `ADD` instruction:

```bash
ADD https://github.com/whitfin/gx_aws_token/blob/<ref>/lua/ngx_aws_token.lua \
    /usr/local/openresty/lualib/ngx_aws_token.lua
```

Make sure to replace `<ref>` with either the branch name or commit hash you want
to pin against. I'd recommend pinning a specific hash when fetching this way, as
Docker caches based on the URL rather than the content.

## Creating Tokens

Before you manage any tokens with `ngx_aws_token`, you need to configure a shared
storage dictionary. The size of this dictionary depends on how many tokens you're
going to be rotating, but in general `1m` should be enough for most people.

```nginx
# Create a shared memory between workers
lua_shared_dict my_aws_tokens 1m;

init_worker_by_lua_block {
    -- Import the ngx_aws_token module
    local ngx_aws_token = require("ngx_aws_token")

    -- Set the shared storage used by ngx_aws_token
    ngx_aws_token.set_storage(ngx.shared.my_aws_tokens)
}
```

You can then configure named tokens to rotate based on AWS CLI commands into the
shared storage. The below example uses Amazon ECR token generation:

```nginx
# Create a shared memory between workers
lua_shared_dict my_aws_tokens 1m;

init_worker_by_lua_block {
    -- Avoid running on many workers
    if ngx.worker.id() ~= 0 then
        return
    end

    -- Import the ngx_aws_token module
    local ngx_aws_token = require("ngx_aws_token")

    -- Set the shared storage used by ngx_aws_token
    ngx_aws_token.set_storage(ngx.shared.my_aws_tokens)

    -- Our token name and command to generate
    local token_name = "my_token_name"
    local token_command = "aws ecr get-authorization-token --query 'authorizationData[*].authorizationToken' --output text"

    -- Begin rotating a token inside our configured storage
    ngx_aws_token.rotate(token_name, token_command, function (token)
        return "Basic " .. token
    end)
}
```

Calling `rotate/3` requires a token name, an AWS CLI command, and an optional function
used to transform the result. In some cases the AWS CLI doesn't produce directly usable
tokens (such as above) and a small transformation is required.

It's important to note that the above example will only run on `worker 0` in order to
avoid many workers spawning AWS commands. The storage is shared between all workers, so
this is an effective pattern for token refresh.

## Routing Requests

Once your token is configured, you can implement a simple Lua authentication block to
read back your token for a request. You can read it back directly from your shared
storage, or use `ngx_aws_token` if you prefer:

```nginx
set_by_lua_block $ecr_token {
    local ngx_aws_token = require("ngx_aws_token")

    return ngx_aws_token.token("ecr")
}
```

With this block in place, you can use it alongside the `proxy_set_header` directive
inside a `location` block to add it as an `Authorization` header:

```nginx
proxy_set_header Authorization $ecr_token;
```

This will attach the latest token to the outgoing request, allowing you to route through
to AWS transparently behind your own authentication layers or routing rules.

## Contributing

This module is very small and I don't expect it'll grow or add many other things, but if
you have suggestions or feedback please feel free to file an issue!
