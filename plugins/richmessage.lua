--[[
  Rich Message Plugin for signal-cli-rest-api
  
  Features:
  - Downloads image from URL and attaches to Signal message
  - Supports text formatting (bold, italic, code, strikethrough, spoiler)
  - Optional URL with display alias
  - Image format validation (jpeg, png, gif, webp)
  - 5MB size limit enforcement
]]

local http = require("http")
local json = require("json")

-- Configuration
local MAX_IMAGE_SIZE = 5 * 1024 * 1024  -- 5MB in bytes
local SUPPORTED_FORMATS = {
  ["image/jpeg"] = true,
  ["image/jpg"] = true,
  ["image/png"] = true,
  ["image/gif"] = true,
  ["image/webp"] = true
}

-- Base64 encoding function (Lua implementation)
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64_encode(data)
    local bytes = {}
    local result = {}
    
    -- Convert string to byte array
    for i = 1, #data do
        bytes[i] = string.byte(data, i)
    end
    
    -- Process 3 bytes at a time
    for i = 1, #bytes, 3 do
        local b1, b2, b3 = bytes[i], bytes[i+1], bytes[i+2]
        local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
        
        -- 4 base64 characters per 3 bytes
        table.insert(result, string.sub(b64chars, math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1))
        table.insert(result, string.sub(b64chars, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1))
        table.insert(result, b2 and string.sub(b64chars, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or '=')
        table.insert(result, b3 and string.sub(b64chars, n % 64 + 1, n % 64 + 1) or '=')
    end
    
    return table.concat(result)
end

-- Extract MIME type from Content-Type header
local function get_mime_type(content_type)
    if not content_type then
        return nil
    end
    -- Remove charset and other parameters
    return string.match(content_type, "^([^;]+)")
end

-- Validate image format
local function validate_image_format(mime_type)
    if not mime_type then
        return false, "Could not determine image format"
    end
    
    mime_type = string.lower(mime_type)
    
    if SUPPORTED_FORMATS[mime_type] then
        return true, nil
    end
    
    local supported = {}
    for format, _ in pairs(SUPPORTED_FORMATS) do
        table.insert(supported, format)
    end
    
    return false, "Unsupported image format: " .. mime_type .. ". Supported: " .. table.concat(supported, ", ")
end

-- Format message text with optional URL
local function format_message(text, url, url_alias)
    local parts = {}
    
    -- Add main text if present
    if text and text ~= "" then
        table.insert(parts, text)
    end
    
    -- Add URL with alias if present
    if url and url ~= "" then
        if url_alias and url_alias ~= "" then
            -- Format: alias on one line, URL on next
            table.insert(parts, url_alias .. ":")
            table.insert(parts, url)
        else
            -- Just the URL
            table.insert(parts, url)
        end
    end
    
    return table.concat(parts, "\n\n")
end

-- Parse size from Content-Length header
local function parse_content_length(content_length)
    if not content_length then
        return nil
    end
    local size = tonumber(content_length)
    return size
end

-- Error response helper
local function send_error(status_code, message)
    local error_response = json.encode({
        error = message,
        success = false
    })
    pluginOutputData:SetPayload(error_response)
    pluginOutputData:SetHttpStatusCode(status_code)
end

-- Main plugin logic
local function send_rich_message()
    -- Parse input JSON
    local success, input = pcall(function()
        return json.decode(pluginInputData.payload)
    end)
    
    if not success or not input then
        send_error(400, "Invalid JSON in request body")
        return
    end
    
    -- Validate required fields
    if not input.recipient or input.recipient == "" then
        send_error(400, "recipient is required")
        return
    end
    
    if not input.image_url or input.image_url == "" then
        send_error(400, "image_url is required")
        return
    end
    
    -- Get sender number from URL parameters
    local sender_number = pluginInputData.Params.number
    if not sender_number or sender_number == "" then
        send_error(400, "Sender number not provided in URL")
        return
    end
    
    -- Step 1: Validate image URL with HEAD request
    local head_response, head_err = http.request("HEAD", input.image_url, {
        timeout = "10s",
        headers = {
            ["Accept"] = "image/*"
        }
    })
    
    if head_err then
        send_error(400, "Failed to access image URL: " .. tostring(head_err))
        return
    end
    
    if not head_response or head_response.status_code ~= 200 then
        local status = head_response and head_response.status_code or "unknown"
        send_error(400, "Image URL returned HTTP " .. status)
        return
    end
    
    -- Step 2: Validate image format
    local content_type = head_response.headers and head_response.headers["Content-Type"]
    local mime_type = get_mime_type(content_type)
    
    local format_valid, format_error = validate_image_format(mime_type)
    if not format_valid then
        send_error(400, format_error)
        return
    end
    
    -- Step 3: Check image size
    local content_length = head_response.headers and head_response.headers["Content-Length"]
    local image_size = parse_content_length(content_length)
    
    if image_size then
        if image_size > MAX_IMAGE_SIZE then
            local size_mb = math.floor(image_size / (1024 * 1024) * 100) / 100
            send_error(400, "Image exceeds 5MB limit (size: " .. size_mb .. " MB)")
            return
        end
    end
    
    -- Step 4: Download image
    local image_response, image_err = http.request("GET", input.image_url, {
        timeout = "30s",
        headers = {
            ["Accept"] = "image/*"
        }
    })
    
    if image_err then
        send_error(400, "Failed to download image: " .. tostring(image_err))
        return
    end
    
    if not image_response or image_response.status_code ~= 200 then
        local status = image_response and image_response.status_code or "unknown"
        send_error(400, "Image download failed with HTTP " .. status)
        return
    end
    
    if not image_response.body then
        send_error(400, "Image download returned empty body")
        return
    end
    
    -- Check actual downloaded size
    local downloaded_size = #image_response.body
    if downloaded_size > MAX_IMAGE_SIZE then
        local size_mb = math.floor(downloaded_size / (1024 * 1024) * 100) / 100
        send_error(400, "Image exceeds 5MB limit (size: " .. size_mb .. " MB)")
        return
    end
    
    -- Step 5: Base64 encode image
    local image_base64 = base64_encode(image_response.body)
    
    -- Step 6: Format message text
    local message_text = format_message(input.text, input.url, input.url_alias)
    
    -- Step 7: Build API payload
    local api_payload = {
        recipients = {input.recipient},
        message = message_text,
        number = sender_number,
        text_mode = "styled"
    }
    
    -- Add base64 attachment
    if mime_type == "image/jpg" then
        mime_type = "image/jpeg"  -- Normalize
    end
    
    api_payload.base64_attachments = {
        "data:" .. mime_type .. ";base64," .. image_base64
    }
    
    -- Step 8: Call internal signal-cli-rest-api
    local api_response, api_err = http.request("POST", "http://127.0.0.1:8080/v2/send", {
        timeout = "30s",
        headers = {
            ["Content-Type"] = "application/json",
            ["Accept"] = "application/json"
        },
        body = json.encode(api_payload)
    })
    
    -- Step 9: Handle API response
    if api_err then
        send_error(500, "Failed to send message: " .. tostring(api_err))
        return
    end
    
    if not api_response then
        send_error(500, "No response from API")
        return
    end
    
    -- Return API response to caller
    pluginOutputData:SetPayload(api_response.body or "{}")
    pluginOutputData:SetHttpStatusCode(api_response.status_code or 500)
end

-- Execute
send_rich_message()
