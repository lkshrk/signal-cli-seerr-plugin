--[[
  HTTP Mock Helper for Busted Testing
  Provides utilities to mock the HTTP module for testing
]]

local _M = {}

-- Create a new HTTP mock instance
function _M.new()
  local mock = {
    calls = {},
    responses = {},
    default_response = {
      status_code = 200,
      body = '{"timestamp": 1234567890}',
      headers = {}
    }
  }
  
  -- Mock request function
  function mock.request(method, url, options)
    local call = {
      method = method,
      url = url,
      options = options or {},
      body = options and options.body or nil
    }
    table.insert(mock.calls, call)
    
    -- Check for pre-configured response
    for _, resp in ipairs(mock.responses) do
      if resp.matches(method, url) then
        return resp.response, resp.error
      end
    end
    
    -- Return default response
    return mock.default_response, nil
  end
  
  -- Add a pre-configured response
  function mock.add_response(method_pattern, url_pattern, response, error_msg)
    table.insert(mock.responses, {
      matches = function(m, u)
        return (method_pattern == nil or m == method_pattern) and 
               (url_pattern == nil or string.match(u, url_pattern))
      end,
      response = response,
      error = error_msg
    })
  end
  
  -- Get all recorded calls
  function mock.get_calls()
    return mock.calls
  end
  
  -- Get last call
  function mock.get_last_call()
    return mock.calls[#mock.calls]
  end
  
  -- Reset mock state
  function mock.reset()
    mock.calls = {}
    mock.responses = {}
  end
  
  -- Set default response
  function mock.set_default_response(response)
    mock.default_response = response
  end
  
  -- Assertion helpers
  function mock.assert_called(times)
    local expected = times or 1
    local actual = #mock.calls
    if actual ~= expected then
      error(string.format("Expected HTTP to be called %d times, but was called %d times", expected, actual))
    end
  end
  
  function mock.assert_called_with(method, url_pattern)
    for _, call in ipairs(mock.calls) do
      if call.method == method and string.match(call.url, url_pattern) then
        return true
      end
    end
    error(string.format("Expected HTTP %s call to URL matching '%s' not found", method, url_pattern))
  end
  
  return mock
end

-- Create a mock plugin output data object
function _M.create_plugin_output()
  local output = {
    payload = nil,
    httpStatusCode = nil
  }
  
  function output:SetPayload(p)
    self.payload = p
  end
  
  function output:SetHttpStatusCode(c)
    self.httpStatusCode = c
  end
  
  return output
end

-- Create a mock plugin input data object
function _M.create_plugin_input(payload, params, query_params)
  return {
    payload = payload or '{}',
    Params = params or {},
    QueryParams = query_params or {}
  }
end

-- Decode base64 (for testing)
function _M.base64_decode(data)
  local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local decoded = {}
  local pad = 0
  
  -- Remove padding
  for i = #data, 1, -1 do
    if string.sub(data, i, i) == '=' then
      pad = pad + 1
    else
      break
    end
  end
  
  -- Process 4 chars at a time
  for i = 1, #data, 4 do
    local c1, c2, c3, c4 = string.sub(data, i, i), string.sub(data, i+1, i+1), 
                           string.sub(data, i+2, i+2), string.sub(data, i+3, i+3)
    
    local n1 = string.find(b64chars, c1, 1, true) - 1
    local n2 = string.find(b64chars, c2, 1, true) - 1
    local n3 = (c3 ~= '=') and (string.find(b64chars, c3, 1, true) - 1) or 0
    local n4 = (c4 ~= '=') and (string.find(b64chars, c4, 1, true) - 1) or 0
    
    local n = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
    
    table.insert(decoded, string.char(math.floor(n / 65536) % 256))
    if c3 ~= '=' then
      table.insert(decoded, string.char(math.floor(n / 256) % 256))
    end
    if c4 ~= '=' then
      table.insert(decoded, string.char(n % 256))
    end
  end
  
  return table.concat(decoded)
end

return _M
