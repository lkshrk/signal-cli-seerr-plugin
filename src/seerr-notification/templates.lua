local constants = require("seerr-notification.constants")

local templates = {}

templates.notification_templates = {
  ["default"] = {
    subject = "**{{subject}}**",
    message = "{{message}}",
    additionalExtras = {}
  },
  [constants.NOTIFICATION_TYPES.MEDIA_AVAILABLE] = {
    subject = "**{{subject}}**",
    message = "{{message}}\n",
    additionalExtras = {
      { name = "Requested By",   value = "{{requestedBy_username}}" },
      { name = "Request Status", value = "Available" }
    }
  }
}

function templates.get_template(notification_type)
  return templates.notification_templates[notification_type]
      or templates.notification_templates["default"]
end

function templates.replace_placeholders(str, payload)
  if not str or str == "" then
    return ""
  end

  return str:gsub("{{([^}]+)}}", function(placeholder)
    local value = payload[placeholder]
    if value == nil or value == "" then
      return ""
    end
    return tostring(value)
  end)
end

function templates.collect_unresolved(str, payload)
  if not str or str == "" then
    return {}
  end

  local missing = {}
  str:gsub("{{([^}]+)}}", function(placeholder)
    local value = payload[placeholder]
    if value == nil or value == "" then
      table.insert(missing, placeholder)
    end
  end)
  return missing
end

function templates.build_message(notification_type, payload)
  local template = templates.get_template(notification_type)

  local parts = {}

  if template.subject and template.subject ~= "" then
    table.insert(parts, template.subject)
  end

  if template.message and template.message ~= "" then
    table.insert(parts, template.message)
  end

  for _, item in ipairs(template.additionalExtras or {}) do
    if type(item) == "table" and item.name and item.value then
      table.insert(parts, "**" .. tostring(item.name) .. ":** " .. tostring(item.value))
    end
  end

  local template_content = table.concat(parts, "\n")

  local missing = templates.collect_unresolved(template_content, payload)
  if #missing > 0 then
    table.sort(missing)
    return nil, "Missing required variables: " .. table.concat(missing, ", ")
  end

  for _, item in ipairs(payload.extra or {}) do
    if type(item) == "table" and item.name and item.value then
      table.insert(parts, "**" .. tostring(item.name) .. ":** " .. tostring(item.value))
    end
  end

  return templates.replace_placeholders(table.concat(parts, "\n"), payload), nil
end

return templates
