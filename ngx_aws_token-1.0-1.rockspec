package = "ngx_aws_token"
version = "1.0-1"
source = {
    url = "git://github.com/whitfin/ngx_aws_token.git",
    tag = "1.0"
}
description = {
    summary = "A Lua module for OpenResty to simplify proxying to AWS services",
    homepage = "https://github.com/whitfin/ngx_aws_token",
    maintainer = "Isaac Whitfield <iw@whitfin.io>",
    license = "MIT"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        ["ngx_aws_token"] = "lua/ngx_aws_token.lua"
    }
}
