local _M = {}

-- Module-level interval reference
local _interval = 60 * 60 * 6

-- Set the management interval to use
function _M.set_interval(interval)
    _interval = interval
end

-- Module-level retry reference
local _retry = 30

-- Set the retry window to use
function _M.set_retry(retry)
    _retry = retry
end

-- Module-level storage reference
local _storage

-- Set the shared dict to use
function _M.set_storage(storage)
    _storage = storage
end

-- Create an AWS authentication token from a command
function _M.create(command, transformer)
    -- Execute the AWS commands
    local handle, err = io.popen(command)
    if not handle then
        return nil, err
    end

    -- Read the command output
    local output = handle:read("*all")
    local success, reason, code = handle:close()
    if not success then
        return nil, "command failed (" .. code .. "): " .. output
    end

    -- Optional transform
    if transformer then
        output = transformer(output)
    end

    -- Complete
    return output
end

-- Internal callback function used to delegate through to _M.manage
local function _manage_callback(premature, name, command, transformer)
    if not premature then
        _M.manage(name, command, transformer)
    end
end

-- Rotate a named token intoshared storage
function _M.manage(name, command, transformer)
    -- Create the token using default creation
    local token, err = _M.create(command, transformer)

    -- Retry window
    if not token then
        ngx.log(ngx.WARN, "Unable to refresh token (" .. name .. "): " .. err)
        ngx.log(ngx.WARN, "Retrying in " .. _retry .. " seconds...")

        ngx.timer.at(_retry, _manage_callback, name, command, transformer)

        return
    end

    -- Log that the token has been refreshed (by name)
    ngx.log(ngx.INFO, "Token refreshed (" .. name .. ")")

    -- Place in shared storage
    _storage:set(name, token)
end

-- Initialize a management loop for a token
function _M.rotate(name, command, transformer)
    _M.manage(name, command, transformer)
    ngx.timer.every(_interval, _manage_callback, name, command, transformer)
end

-- Retrieve managed token
function _M.token(name)
    return _storage:get(name)
end

return _M
