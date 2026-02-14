local constants = require("seerr-notification.constants")

local image_handler = {}

-- Extract MIME type from Content-Type header
function image_handler.get_mime_type(content_type)
	if not content_type then
		return nil
	end
	return string.match(content_type, "^([^;]+)")
end

-- Validate image format against supported types
function image_handler.validate_image_format(mime_type)
	if not mime_type then
		return false, "Could not determine image format"
	end

	mime_type = string.lower(mime_type)

	if constants.SUPPORTED_FORMATS[mime_type] then
		return true, nil
	end

	local supported = constants.get_supported_formats_list()
	return false, "Unsupported image format: " .. mime_type .. ". Supported: " .. table.concat(supported, ", ")
end

-- Base64 encode binary data
function image_handler.base64_encode(data)
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
		buffer[buffer_size] = string.sub(constants.B64_CHARS, math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
			.. string.sub(constants.B64_CHARS, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
			.. (b2 and string.sub(constants.B64_CHARS, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "=")
			.. (b3 and string.sub(constants.B64_CHARS, n % 64 + 1, n % 64 + 1) or "=")

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

-- Download image from URL with validation
function image_handler.download_and_validate_image(image_url)
	local http = require("http")
	local image_response, image_err = http.request("GET", image_url, {
		timeout = constants.IMAGE_TIMEOUT,
		headers = {
			["Accept"] = "image/*",
		},
	})

	if image_err then
		return nil, nil, "Failed to download image: " .. tostring(image_err)
	end

	if not image_response or image_response.status_code ~= 200 then
		local status = image_response and image_response.status_code or "unknown"
		return nil, nil, "Image download failed with HTTP " .. status
	end

	if not image_response.body then
		return nil, nil, "Image download returned empty body"
	end

	local downloaded_size = #image_response.body
	if downloaded_size > constants.MAX_IMAGE_SIZE then
		local size_mb = math.floor(downloaded_size / (1024 * 1024) * 100) / 100
		return nil, nil, "Image exceeds 2MB limit (size: " .. size_mb .. " MB)"
	end

	local content_type = nil
	if image_response.headers then
		-- HTTP headers are case-insensitive; try common capitalizations
		content_type = image_response.headers["Content-Type"]
			or image_response.headers["content-type"]
			or image_response.headers["Content-type"]
	end
	local mime_type = image_handler.get_mime_type(content_type)

	local format_valid, format_error = image_handler.validate_image_format(mime_type)
	if not format_valid then
		return nil, nil, format_error
	end

	if mime_type == "image/jpg" then
		mime_type = "image/jpeg"
	end

	local image_base64 = image_handler.base64_encode(image_response.body)

	return image_base64, mime_type, nil
end

return image_handler
