--[[
  Seerr Notification Plugin for signal-cli-rest-api

  Transforms Seerr webhook payloads into formatted Signal messages.

  Usage:
    local seerr = require("seerr-notification")
    seerr.send_notification(payload_data)
]]

local json = require("json")
local constants = require("seerr-notification.constants")
local templates = require("seerr-notification.templates")
local image_handler = require("seerr-notification.image_handler")
local api_client = require("seerr-notification.api_client")
local response = require("seerr-notification.response")

local seerr_notification = {}

local function handle_error(status_code, message, payload)
  local ntype = (payload and payload.notification_type) or "unknown"
  print(string.format("[SeerrNotification] Error: %s | Status: %d | Type: %s", message, status_code, ntype))
  response.send_error(status_code, message, payload)
end

function seerr_notification.send_notification(payload_data)
  print("[SeerrNotification] Processing Seerr notification...")

  local success, payload = pcall(function()
    return json.decode(payload_data)
  end)

  if not success or not payload then
    handle_error(400, "Invalid JSON in request body", nil)
    return
  end

  local required_fields = { "recipient", "sender", "notification_type" }
  local missing = {}
  for _, field in ipairs(required_fields) do
    if not payload[field] or payload[field] == "" then
      table.insert(missing, field)
    end
  end
  if #missing > 0 then
    handle_error(400, "Missing required fields: " .. table.concat(missing, ", "), payload)
    return
  end

  local notification_type = payload.notification_type

  if not constants.is_valid_notification_type(notification_type) then
    handle_error(400, string.format("Unknown notification type '%s'", notification_type), payload)
    return
  end

  local message_text, build_err = templates.build_message(notification_type, payload)
  if build_err then
    handle_error(400, build_err, payload)
    return
  end

  local api_payload = {
    recipients = { payload.recipient },
    message = message_text,
    number = payload.sender,
    text_mode = "styled",
  }

  if payload.image and payload.image ~= "" then
    local image_base64, mime_type, image_err = image_handler.download_and_validate_image(payload.image)

    if image_err then
      handle_error(400, image_err, payload)
      return
    end

    api_payload.base64_attachments = {
      "data:" .. mime_type .. ";base64," .. image_base64,
    }
  end

  local send_success, send_err = api_client.send_message(api_payload)

  if not send_success then
    handle_error(500, send_err, payload)
    return
  end

  print(string.format("[SeerrNotification] Notification sent successfully | Type: %s | Recipient: %s", notification_type, payload.recipient))
  response.send_success(notification_type)
end

if pluginInputData and pluginOutputData then
  local ok, err = pcall(seerr_notification.send_notification, pluginInputData.payload)
  if not ok then
    print(string.format("[SeerrNotification] Unexpected error: %s", tostring(err)))
    local json = require("json")
    pluginOutputData:SetPayload(json.encode({ success = false, error = "Internal plugin error" }))
    pluginOutputData:SetHttpStatusCode(500)
  end
end

return seerr_notification
