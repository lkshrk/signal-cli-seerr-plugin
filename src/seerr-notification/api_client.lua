local constants = require("seerr-notification.constants")

local api_client = {}

function api_client.send_message(api_payload)
	local http = require("http")
	local json = require("json")
	local api_response, api_err = http.request("POST", constants.SIGNAL_API_URL .. "/v2/send", {
		timeout = constants.API_TIMEOUT,
		headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
		},
		body = json.encode(api_payload),
	})

	if api_err then
		return false, "Failed to send message: " .. tostring(api_err)
	end

	if not api_response or (api_response.status_code ~= 200 and api_response.status_code ~= 201) then
		return false, "Unexpected response from Signal API: " .. (api_response.status_code or "unknown")
	end

	return true, nil
end

return api_client
