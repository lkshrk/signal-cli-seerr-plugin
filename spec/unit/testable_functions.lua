local constants = require("src.seerr-notification.constants")
local templates = require("src.seerr-notification.templates")
local image_handler = require("src.seerr-notification.image_handler")
local testable_functions = {}

testable_functions.build_message = templates.build_message
testable_functions.replace_placeholders = templates.replace_placeholders
testable_functions.collect_unresolved = templates.collect_unresolved
testable_functions.get_template = templates.get_template
testable_functions.notification_templates = templates.notification_templates

testable_functions.get_mime_type = image_handler.get_mime_type
testable_functions.validate_image_format = image_handler.validate_image_format
testable_functions.base64_encode = image_handler.base64_encode

return testable_functions
