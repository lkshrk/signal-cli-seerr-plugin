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
local MAX_IMAGE_SIZE = 5 * 1024 * 1024 -- 5MB in bytes
local SUPPORTED_FORMATS = {
	["image/jpeg"] = true,
	["image/jpg"] = true,
	["image/png"] = true,
	["image/gif"] = true,
	["image/webp"] = true,
}

-- Base64 encoding with pre-allocated buffer
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64_encode(data)
	local len = #data
	local result_parts = {}
	local result_count = 0
	local buffer = {}
	local buffer_size = 0
	local max_buffer = 100

	for i = 1, len, 3 do
		local b1 = string.byte(data, i)
		local b2 = string.byte(data, i + 1)
		local b3 = string.byte(data, i + 2)

		local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)

		buffer_size = buffer_size + 1
		buffer[buffer_size] = string.sub(b64chars, math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
			.. string.sub(b64chars, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
			.. (b2 and string.sub(b64chars, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "=")
			.. (b3 and string.sub(b64chars, n % 64 + 1, n % 64 + 1) or "=")

		if buffer_size >= max_buffer then
			result_count = result_count + 1
			result_parts[result_count] = table.concat(buffer, "", 1, buffer_size)
			buffer_size = 0
		end
	end

	if buffer_size > 0 then
		result_count = result_count + 1
		result_parts[result_count] = table.concat(buffer, "", 1, buffer_size)
	end

	return table.concat(result_parts, "", 1, result_count)
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

-- Format message text
local function format_message(title, text, extra)
	local parts = {}

	-- Add title if present (formatted as bold)
	if title and title ~= "" then
		table.insert(parts, "**" .. title .. "**")
	end

	-- Add main text if present
	if text and text ~= "" then
		table.insert(parts, text)
	end

	-- Add extra content if present (output after text)
	-- Extra must be an array of objects with 'name' and 'value' keys
	if extra and type(extra) == "table" then
		for _, item in ipairs(extra) do
			if type(item) == "table" and item.name and item.value then
				table.insert(parts, "**" .. tostring(item.name) .. ":** " .. tostring(item.value))
			end
		end
	end

	return table.concat(parts, "\n")
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
local function send_error(status_code, message, request_body)
	local error_data = {
		error = message,
		success = false,
	}
	-- Include request body in error for debugging
	if request_body then
		error_data.request_body = request_body
	end
	local error_response = json.encode(error_data)
	pluginOutputData:SetPayload(error_response)
	pluginOutputData:SetHttpStatusCode(status_code)
end

-- Main plugin logic
local function send_rich_message()
	-- Log request body for debugging
	print("[RichMessage] Request body: " .. tostring(pluginInputData.payload))

	-- Parse input JSON
	local success, input = pcall(function()
		return json.decode(pluginInputData.payload)
	end)

	if not success or not input then
		send_error(400, "Invalid JSON in request body", pluginInputData.payload)
		return
	end

	-- Validate required fields
	if not input.recipient or input.recipient == "" then
		send_error(400, "recipient is required", pluginInputData.payload)
		return
	end

	if not input.sender or input.sender == "" then
		send_error(400, "sender is required", pluginInputData.payload)
		return
	end

	local sender_number = input.sender

	local message_text = format_message(input.title, input.text, input.extra)

	local api_payload = {
		recipients = { input.recipient },
		message = message_text,
		number = sender_number,
		text_mode = "styled",
	}

	if input.image_url and input.image_url ~= "" then
		local head_response, head_err = http.request("HEAD", input.image_url, {
			timeout = "10s",
			headers = {
				["Accept"] = "image/*",
			},
		})

		if head_err then
			send_error(400, "Failed to access image URL: " .. tostring(head_err), pluginInputData.payload)
			return
		end

		if not head_response or head_response.status_code ~= 200 then
			local status = head_response and head_response.status_code or "unknown"
			send_error(400, "Image URL returned HTTP " .. status, pluginInputData.payload)
			return
		end

		local content_type = head_response.headers and head_response.headers["Content-Type"]
		local mime_type = get_mime_type(content_type)

		local format_valid, format_error = validate_image_format(mime_type)
		if not format_valid then
			send_error(400, format_error, pluginInputData.payload)
			return
		end

		local content_length = head_response.headers and head_response.headers["Content-Length"]
		local image_size = parse_content_length(content_length)

		if image_size then
			if image_size > MAX_IMAGE_SIZE then
				local size_mb = math.floor(image_size / (1024 * 1024) * 100) / 100
				send_error(400, "Image exceeds 5MB limit (size: " .. size_mb .. " MB)", pluginInputData.payload)
				return
			end
		end

		local image_response, image_err = http.request("GET", input.image_url, {
			timeout = "30s",
			headers = {
				["Accept"] = "image/*",
			},
		})

		if image_err then
			send_error(400, "Failed to download image: " .. tostring(image_err), pluginInputData.payload)
			return
		end

		if not image_response or image_response.status_code ~= 200 then
			local status = image_response and image_response.status_code or "unknown"
			send_error(400, "Image download failed with HTTP " .. status, pluginInputData.payload)
			return
		end

		if not image_response.body then
			send_error(400, "Image download returned empty body", pluginInputData.payload)
			return
		end

		local downloaded_size = #image_response.body
		if downloaded_size > MAX_IMAGE_SIZE then
			local size_mb = math.floor(downloaded_size / (1024 * 1024) * 100) / 100
			send_error(400, "Image exceeds 5MB limit (size: " .. size_mb .. " MB)", pluginInputData.payload)
			return
		end

		local image_base64 = base64_encode(image_response.body)

		if mime_type == "image/jpg" then
			mime_type = "image/jpeg"
		end

		api_payload.base64_attachments = {
			"data:" .. mime_type .. ";base64," .. image_base64,
		}
	end

	local api_response, api_err = http.request("POST", "http://127.0.0.1:8080/v2/send", {
		timeout = "30s",
		headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
		},
		body = json.encode(api_payload),
	})

	if api_err then
		send_error(500, "Failed to send message: " .. tostring(api_err), pluginInputData.payload)
		return
	end

	if not api_response then
		send_error(500, "No response from API", pluginInputData.payload)
		return
	end

	pluginOutputData:SetPayload(api_response.body or "{}")
	pluginOutputData:SetHttpStatusCode(api_response.status_code or 500)
end

send_rich_message()
