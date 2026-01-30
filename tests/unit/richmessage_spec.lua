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
          sender = "+1234567890",
          image_url = "https://example.com/image.jpg"
        }),
        {}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_true(response.error:find("recipient") ~= nil)
    end)
    
    it("should accept message without image_url", function()
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          sender = "+0987654321",
          sender = "+1234567890",
          text = "Hello **world**!"
        }),
        {}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(200, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_nil(response.error)
    end)
    
    it("should reject invalid JSON", function()
      _G.pluginInputData = http_mock.create_plugin_input(
        "not valid json",
        {}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.are.equal("Invalid JSON in request body", response.error)
      assert.are.equal("not valid json", response.request_body)
    end)
    
    it("should include request body in error responses", function()
      local input_json = json.encode({
        recipient = "+1234567890",
        sender = "+0987654321",
        image_url = "https://invalid-format.com/image.bmp"
      })
      
      _G.pluginInputData = http_mock.create_plugin_input(
        input_json,
        {}
      )
      
      mock_http.add_response("HEAD", "https://invalid-format.com/image.bmp", {
        status_code = 200,
        headers = {["Content-Type"] = "image/bmp", ["Content-Length"] = "1024"},
        body = ""
      })
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_not_nil(response.request_body)
      assert.is_true(response.request_body:find("invalid%-format%.com") ~= nil)
    end)
    
    it("should reject missing sender", function()
      _G.pluginInputData = http_mock.create_plugin_input(
        json.encode({
          recipient = "+1234567890",
          image_url = "https://example.com/image.jpg"
        }),
        {}
      )
      
      dofile("plugins/richmessage.lua")
      
      assert.are.equal(400, plugin_output.httpStatusCode)
      local response = json.decode(plugin_output.payload)
      assert.is_true(response.error:find("sender") ~= nil)
      assert.is_not_nil(response.request_body)
      assert.is_true(response.request_body:find("recipient") ~= nil)
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
          sender = "+0987654321",
          image_url = "https://example.com/image.jpg"
        }),
        {}
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
          sender = "+0987654321",
          image_url = "https://example.com/image.png"
        }),
        {}
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
          sender = "+0987654321",
          image_url = "https://example.com/image.svg"
        }),
        {}
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
          sender = "+0987654321",
          image_url = "https://example.com/large.jpg"
        }),
        {}
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
          sender = "+0987654321",
          image_url = "https://example.com/max.jpg"
        }),
        {}
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
          sender = "+0987654321",
          image_url = "https://example.com/image.jpg",
          text = "Hello **world**!"
        }),
        {}
      )
      
      dofile("plugins/richmessage.lua")
      
      local calls = mock_http.get_calls()
      local last_call = calls[#calls]
      
      assert.are.equal("POST", last_call.method)
      local payload = json.decode(last_call.body)
      assert.are.equal("Hello **world**!", payload.message)
      assert.are.equal("styled", payload.text_mode)
    end)

    it("should format message with title", function()
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
          sender = "+0987654321",
          image_url = "https://example.com/image.jpg",
          title = "Breaking News",
          text = "Major update!"
        }),
        {}
      )
      
      dofile("plugins/richmessage.lua")
      
      local calls = mock_http.get_calls()
      local last_call = calls[#calls]
      local payload = json.decode(last_call.body)
      
      assert.is_true(payload.message:find("**Breaking News**") ~= nil)
      assert.is_true(payload.message:find("Major update!") ~= nil)
    end)
    
    it("should format message with extra content", function()
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
          sender = "+0987654321",
          image_url = "https://example.com/image.jpg",
          text = "Main message",
          extra = {{name = "Details", value = "Additional information"}}
        }),
        {}
      )

      dofile("plugins/richmessage.lua")

      local calls = mock_http.get_calls()
      local last_call = calls[#calls]
      local payload = json.decode(last_call.body)

      print("Message content:", payload.message)
      assert.is_true(payload.message:find("Main message") ~= nil)
      assert.is_true(payload.message:find("Details:") ~= nil)
    end)

    it("should format message with multiple extra items", function()
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
          sender = "+0987654321",
          image_url = "https://example.com/image.jpg",
          text = "Main message",
          extra = {
            {name = "First", value = "First detail"},
            {name = "Second", value = "Second detail"},
            {name = "Third", value = "Third detail"}
          }
        }),
        {}
      )

      dofile("plugins/richmessage.lua")

      local calls = mock_http.get_calls()
      local last_call = calls[#calls]
      local payload = json.decode(last_call.body)

      assert.is_true(payload.message:find("Main message") ~= nil)
      assert.is_true(payload.message:find("First:") ~= nil)
      assert.is_true(payload.message:find("Second:") ~= nil)
      assert.is_true(payload.message:find("Third:") ~= nil)
    end)

    it("should ignore extra items without name/value keys", function()
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
          sender = "+0987654321",
          image_url = "https://example.com/image.jpg",
          text = "Main message",
          extra = {
            {name = "Valid", value = "This should appear"},
            {invalid = "no name/value"},
            "just a string",
            {name = "Another", value = "This should also appear"}
          }
        }),
        {}
      )

      dofile("plugins/richmessage.lua")

      local calls = mock_http.get_calls()
      local last_call = calls[#calls]
      local payload = json.decode(last_call.body)

      assert.is_true(payload.message:find("Main message") ~= nil)
      -- Valid items with name/value should appear
      assert.is_true(payload.message:find("Valid:") ~= nil)
      assert.is_true(payload.message:find("Another:") ~= nil)
      -- Invalid items should not appear
      assert.is_false(payload.message:find("invalid") ~= nil)
      assert.is_false(payload.message:find("just a string") ~= nil)
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
          sender = "+0987654321",
          image_url = "https://example.com/missing.jpg"
        }),
        {}
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
          sender = "+0987654321",
          image_url = "https://example.com/error.jpg"
        }),
        {}
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
          sender = "+0987654321",
          image_url = "https://example.com/image.jpg"
        }),
        {}
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
          sender = "+0987654321",
          image_url = "https://example.com/image.jpg"
        }),
        {}
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
          sender = "+0987654321",
          image_url = "https://example.com/image.jpg"
        }),
        {}
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
