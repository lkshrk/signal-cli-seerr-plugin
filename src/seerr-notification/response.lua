local response = {}

function response.build_error(status_code, message, request_body)
	local json = require("json")

	local error_data = {
		success = false,
		error = message
	}

	if request_body and request_body.notification_type then
		error_data.notification_type = request_body.notification_type
	end

	return {
		payload = json.encode(error_data),
		status_code = status_code
	}
end

function response.send_error(status_code, message, request_body)
	local response_data = response.build_error(status_code, message, request_body)
	pluginOutputData:SetPayload(response_data.payload)
	pluginOutputData:SetHttpStatusCode(response_data.status_code)
end

function response.send_success(notification_type)
	local json = require("json")
	local success_response = {
		success = true,
		message = "Seerr notification sent successfully",
		notification_type = notification_type
	}

	pluginOutputData:SetPayload(json.encode(success_response))
	pluginOutputData:SetHttpStatusCode(200)
end

return response
