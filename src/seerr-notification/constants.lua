--[[
  Constants Module
  Centralized configuration and constants for Seerr Notification Plugin
  
  This module provides a single source of truth for all constants,
  preventing drift between the main plugin and test utilities.
]]

local constants = {}

-- =============================================================================
-- Environment Configuration
-- =============================================================================
constants.SIGNAL_API_URL = os.getenv("SIGNAL_API_URL") or "http://127.0.0.1:8080"

-- =============================================================================
-- Image Processing Configuration
-- =============================================================================
constants.MAX_IMAGE_SIZE = 2 * 1024 * 1024  -- 2MB in bytes
constants.IMAGE_TIMEOUT = "30s"
constants.API_TIMEOUT = "30s"

constants.SUPPORTED_FORMATS = {
	["image/jpeg"] = true,
	["image/jpg"] = true,
	["image/png"] = true,
	["image/gif"] = true,
	["image/webp"] = true,
}

-- =============================================================================
-- Notification Types
-- =============================================================================
constants.NOTIFICATION_TYPES = {
	MEDIA_PENDING = "MEDIA_PENDING",
	MEDIA_APPROVED = "MEDIA_APPROVED",
	MEDIA_AVAILABLE = "MEDIA_AVAILABLE",
	MEDIA_DECLINED = "MEDIA_DECLINED",
	MEDIA_PROCESSING_FAILED = "MEDIA_PROCESSING_FAILED",
	MEDIA_AUTO_APPROVED = "MEDIA_AUTO_APPROVED",
	ISSUE_CREATED = "ISSUE_CREATED",
	ISSUE_COMMENT = "ISSUE_COMMENT",
	ISSUE_RESOLVED = "ISSUE_RESOLVED",
	ISSUE_COMMENT_ADDED = "ISSUE_COMMENT_ADDED"
}

-- =============================================================================
-- Base64 Encoding Characters
-- =============================================================================
constants.B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- =============================================================================
-- Helper Functions
-- =============================================================================

function constants.is_valid_notification_type(notification_type)
	for _, valid_type in pairs(constants.NOTIFICATION_TYPES) do
		if notification_type == valid_type then
			return true
		end
	end
	return false
end

-- Get list of supported MIME types as array
function constants.get_supported_formats_list()
	local formats = {}
	for format, _ in pairs(constants.SUPPORTED_FORMATS) do
		table.insert(formats, format)
	end
	return formats
end

return constants
