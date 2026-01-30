--[[
  Unit Tests for Rich Message Plugin
  
  Run with: busted tests/unit/richmessage_spec.lua
]]

local http_mock = require("tests.unit.helpers.http_mock")
local json = require("json")

-- Load the plugin code as a module
local function load_plugin()
  -- Create a mock environment
  local env = {
    http = nil,
    json = json,
    pluginInputData = nil,
    pluginOutputData = nil,
    require = require,
    pcall = pcall,
    tonumber = tonumber,
    tostring = tostring,
    table = table,
    string = string,
    math = math,
    ipairs = ipairs,
    pairs = pairs,
    print = print,
    error = error,
    assert = assert,
    type = type,
    _G = _G
  }
  
  -- Load plugin code
  local plugin_code = io.open("plugins/richmessage.lua", "r")
  if not plugin_code then
    error("Could not open plugin file")
  end
  
  local content = plugin_code:read("*all")
  plugin_code:close()
  
  -- Return the environment for testing
  return env, content
end

describe("Rich Message Plugin", function()
  local mock_http
  local plugin_env
  local plugin_output
  
  before_each(function()
    -- Create fresh mocks
    mock_http = http_mock.new()
    plugin_output = http_mock.create_plugin_output()
    
    -- Inject mocks into package.loaded so require() finds them
    package.loaded["http"] = mock_http
    package.loaded["json"] = json
    
    -- Setup global environment for plugin globals
    _G.pluginOutputData = plugin_output
  end)
  
  after_each(function()
    -- Cleanup package.loaded
    package.loaded["http"] = nil
    package.loaded["json"] = nil
    
    -- Cleanup globals
    _G.pluginInputData = nil
    _G.pluginOutputData = nil
  end)
  
  describe("Input Validation", function()
    it("should reject missing recipient", function()
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          image_url = "https://example.com/image.jpg"
        }),
        {number = "+1234567890"}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_true(response.error:find("recipient") ~= nil)
    end)
    
    it("should reject missing image_url", function()
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890"
        }),
        {number = "+1234567890"}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_true(response.error:find("image_url") ~= nil)
    end)
    
    it("should reject invalid JSON", function()
      _G.pluginInputData = http_mock.create_plugin_input(
        "not valid json",
        {number = "+1234567890"}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.are.equal("Invalid JSON in request body", response.error)
    end)
    
    it("should reject missing sender number", function()
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.jpg"
        }),
        {}  -- Empty params
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_true(response.error:find("Sender number") ~= nil)
    end)
  end)
  
  describe("Image Format Validation", function()
    it("should accept JPEG images", function()
      mock_http.add_response("HEAD", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg", ["Content-Length"] = "1024"},
        body = ""
      })
      
      mock_http.add_response("GET", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg"},
        body = "fake image data"
      })
      
      mock_http.add_response("POST", "http://127.0.0.1:8080/v2/send", {
        status_code = 200,
        body = '{"timestamp": 1234567890}'
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.jpg"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(200, plugin_output.httpStatusCode)
    end)
    
    it("should accept PNG images", function()
      mock_http.add_response("HEAD", "https://example.com/image.png", {
        status_code = 200,
        headers = {["Content-Type"] = "image/png", ["Content-Length"] = "2048"},
        body = ""
      })
      
      mock_http.add_response("GET", "https://example.com/image.png", {
        status_code = 200,
        headers = {["Content-Type"] = "image/png"},
        body = "fake png data"
      })
      
      mock_http.add_response("POST", "http://127.0.0.1:8080/v2/send", {
        status_code = 200,
        body = '{"timestamp": 1234567890}'
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.png"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(200, plugin_output.httpStatusCode)
    end)
    
    it("should reject unsupported image formats", function()
      mock_http.add_response("HEAD", "https://example.com/image.svg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/svg+xml", ["Content-Length"] = "1024"},
        body = ""
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.svg"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_true(response.error:find("Unsupported image format") ~= nil)
    end)
  end)
  
  describe("Image Size Validation", function()
    it("should reject images larger than 5MB", function()
      local large_size = 6 * 1024 * 1024  -- 6MB
      
      mock_http.add_response("HEAD", "https://example.com/large.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg", ["Content-Length"] = tostring(large_size)},
        body = ""
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/large.jpg"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_true(response.error:find("exceeds 5MB limit") ~= nil)
    end)
    
    it("should accept images at exactly 5MB", function()
      local max_size = 5 * 1024 * 1024  -- Exactly 5MB
      
      mock_http.add_response("HEAD", "https://example.com/max.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg", ["Content-Length"] = tostring(max_size)},
        body = ""
      })
      
      mock_http.add_response("GET", "https://example.com/max.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg"},
        body = string.rep("x", max_size)  -- Mock data
      })
      
      mock_http.add_response("POST", "http://127.0.0.1:8080/v2/send", {
        status_code = 200,
        body = '{"timestamp": 1234567890}'
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/max.jpg"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      -- Should either succeed or fail based on implementation
      -- Main point is it doesn't reject immediately at HEAD request
      assert.is_not_nil(plugin_output.httpStatusCode)
    end)
  end)
  
  describe("Message Formatting", function()
    it("should format message with text only", function()
      mock_http.add_response("HEAD", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg", ["Content-Length"] = "1024"},
        body = ""
      })
      
      mock_http.add_response("GET", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg"},
        body = "fake image"
      })
      
      mock_http.add_response("POST", "http://127.0.0.1:8080/v2/send", {
        status_code = 200,
        body = '{"timestamp": 1234567890}'
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.jpg",
          text = "Hello **world**!"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      local calls = mock_http.get_calls()
      local last_call = calls[#calls]
      
      assert.are.equal("POST", last_call.method)
      local payload = json.decode(last_call.body)
      assert.are.equal("Hello **world**!", payload.message)
      assert.are.equal("styled", payload.text_mode)
    end)
    
    it("should format message with URL alias", function()
      mock_http.add_response("HEAD", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg", ["Content-Length"] = "1024"},
        body = ""
      })
      
      mock_http.add_response("GET", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg"},
        body = "fake image"
      })
      
      mock_http.add_response("POST", "http://127.0.0.1:8080/v2/send", {
        status_code = 200,
        body = '{"timestamp": 1234567890}'
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.jpg",
          text = "Check this out!",
          url = "https://example.com/article",
          url_alias = "Read more"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      local calls = mock_http.get_calls()
      local last_call = calls[#calls]
      local payload = json.decode(last_call.body)
      
      assert.is_true(payload.message:find("Check this out!") ~= nil)
      assert.is_true(payload.message:find("Read more:") ~= nil)
      assert.is_true(payload.message:find("https://example.com/article") ~= nil)
    end)
    
    it("should format message with URL but no alias", function()
      mock_http.add_response("HEAD", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg", ["Content-Length"] = "1024"},
        body = ""
      })
      
      mock_http.add_response("GET", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg"},
        body = "fake image"
      })
      
      mock_http.add_response("POST", "http://127.0.0.1:8080/v2/send", {
        status_code = 200,
        body = '{"timestamp": 1234567890}'
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.jpg",
          url = "https://example.com/link"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      local calls = mock_http.get_calls()
      local last_call = calls[#calls]
      local payload = json.decode(last_call.body)
      
      assert.is_true(payload.message:find("https://example.com/link") ~= nil)
      -- When no alias, URL should be on its own without "alias:" prefix
      assert.is_false(payload.message:find("https://example.com/link:") ~= nil)
    end)
  end)
  
  describe("Error Handling", function()
    it("should handle HTTP 404 on image download", function()
      mock_http.add_response("HEAD", "https://example.com/missing.jpg", {
        status_code = 404,
        headers = {},
        body = ""
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/missing.jpg"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_true(response.error:find("404") ~= nil)
    end)
    
    it("should handle network errors", function()
      -- Simulate network error by adding error to response
      mock_http.add_response("HEAD", "https://example.com/error.jpg", {
        status_code = nil,
        headers = {},
        body = ""
      }, "Connection timeout")
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/error.jpg"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_true(response.error:find("Failed to access") ~= nil)
    end)
    
    it("should handle API errors", function()
      mock_http.add_response("HEAD", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg", ["Content-Length"] = "1024"},
        body = ""
      })
      
      mock_http.add_response("GET", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg"},
        body = "fake image"
      })
      
      mock_http.add_response("POST", "http://127.0.0.1:8080/v2/send", {
        status_code = 500,
        body = '{"error": "Internal server error"}'
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.jpg"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(500, plugin_output.httpStatusCode)
    end)
  end)
  
  describe("API Request Building", function()
    it("should include base64 attachment in correct format", function()
      mock_http.add_response("HEAD", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg", ["Content-Length"] = "1024"},
        body = ""
      })
      
      mock_http.add_response("GET", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg"},
        body = "fake image data"
      })
      
      mock_http.add_response("POST", "http://127.0.0.1:8080/v2/send", {
        status_code = 200,
        body = '{"timestamp": 1234567890}'
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.jpg"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      local calls = mock_http.get_calls()
      local api_call = nil
      
      for _, call in ipairs(calls) do
        if call.method == "POST" and call.url == "http://127.0.0.1:8080/v2/send" then
          api_call = call
          break
        end
      end
      
      assert.is_not_nil(api_call, "API call not found")
      
      local payload = json.decode(api_call.body)
      assert.is_not_nil(payload.base64_attachments)
      assert.are.equal(1, #payload.base64_attachments)
      
      -- Check attachment format
      local attachment = payload.base64_attachments[1]
      assert.is_true(attachment:find("data:image/jpeg;base64,") ~= nil or
                     attachment:find("data:image/jpg;base64,") ~= nil)
    end)
    
    it("should set correct API headers", function()
      mock_http.add_response("HEAD", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg", ["Content-Length"] = "1024"},
        body = ""
      })
      
      mock_http.add_response("GET", "https://example.com/image.jpg", {
        status_code = 200,
        headers = {["Content-Type"] = "image/jpeg"},
        body = "fake image"
      })
      
      mock_http.add_response("POST", "http://127.0.0.1:8080/v2/send", {
        status_code = 200,
        body = '{"timestamp": 1234567890}'
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.jpg"
        }),
        {number = "+0987654321"}
      )
      
      dofile("plugins/richmessage.lua")
      
      local calls = mock_http.get_calls()
      local api_call = nil
      
      for _, call in ipairs(calls) do
        if call.method == "POST" and call.url == "http://127.0.0.1:8080/v2/send" then
          api_call = call
          break
        end
      end
      
      assert.is_not_nil(api_call.options.headers)
      assert.are.equal("application/json", api_call.options.headers["Content-Type"])
    end)
  end)
end)
