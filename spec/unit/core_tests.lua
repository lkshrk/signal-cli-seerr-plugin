#!/usr/bin/env lua5.4

local testable_functions = require("spec.unit.testable_functions")

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
    local status, err = pcall(fn)
    if status then
        tests_passed = tests_passed + 1
        print(string.format("  ✓ %s", name))
    else
        tests_failed = tests_failed + 1
        print(string.format("  ✗ %s", name))
        print(string.format("    Error: %s", err))
    end
end

print("========================================")
print("  Core Plugin Tests")
print("========================================")

print("\nbuild_message (end-to-end):")
test("renders default template with subject, message, and payload extras", function()
    local payload = {
        subject = "The Matrix",
        message = "Please add this movie",
        extra = {
            {name = "Quality", value = "1080p"}
        }
    }
    local result = testable_functions.build_message("MEDIA_PENDING", payload)
    assert(result:find("**The Matrix**", 1, true), "Should have bold subject")
    assert(result:find("Please add this movie", 1, true), "Should have message text")
    assert(result:find("**Quality:** 1080p", 1, true), "Should include payload extra")
end)

test("renders MEDIA_AVAILABLE template with additionalExtras", function()
    local payload = {
        subject = "The Matrix",
        message = "Your request is now available!",
        requestedBy_username = "john"
    }
    local result = testable_functions.build_message("MEDIA_AVAILABLE", payload)
    assert(result:find("**The Matrix**", 1, true), "Should have bold subject")
    assert(result:find("Your request is now available!", 1, true), "Should have message text")
    assert(result:find("**Requested By:** john", 1, true), "Should have requested by from additionalExtras")
    assert(result:find("**Request Status:** Available", 1, true), "Should have request status from additionalExtras")
end)

test("falls back to default template for unknown type", function()
    local payload = { subject = "Foo", message = "Bar" }
    local result = testable_functions.build_message("UNKNOWN_TYPE", payload)
    assert(result:find("**Foo**", 1, true), "Should render using default template")
    assert(result:find("Bar", 1, true), "Should have message")
end)

test("returns error when subject is missing", function()
    local payload = { message = "Body only" }
    local result, err = testable_functions.build_message("MEDIA_PENDING", payload)
    assert(result == nil, "Should return nil on missing variable")
    assert(err:find("subject", 1, true), "Should report missing subject")
end)

test("returns error when message is missing", function()
    local payload = { subject = "Title Only" }
    local result, err = testable_functions.build_message("MEDIA_PENDING", payload)
    assert(result == nil, "Should return nil on missing variable")
    assert(err:find("message", 1, true), "Should report missing message")
end)

test("includes both additionalExtras and payload extras", function()
    local payload = {
        subject = "Test",
        message = "msg",
        requestedBy_username = "john",
        extra = {
            {name = "Quality", value = "1080p"},
            {name = "Season", value = "3"}
        }
    }
    local result = testable_functions.build_message("MEDIA_AVAILABLE", payload)
    assert(result:find("**Requested By:** john", 1, true), "Should include template additionalExtras")
    assert(result:find("**Quality:** 1080p", 1, true), "Should include first payload extra")
    assert(result:find("**Season:** 3", 1, true), "Should include second payload extra")
end)

test("replaces placeholders in additionalExtras", function()
    local payload = {
        subject = "Inception",
        message = "A movie request",
        requestedBy_username = "alice"
    }
    local result = testable_functions.build_message("MEDIA_AVAILABLE", payload)
    assert(result:find("**Inception**", 1, true), "Should replace subject placeholder in title")
    assert(result:find("**Requested By:** alice", 1, true), "Should replace placeholder in additionalExtras")
end)

test("returns error when additionalExtras placeholder is missing", function()
    local payload = {
        subject = "Test",
        message = "msg"
    }
    local result, err = testable_functions.build_message("MEDIA_AVAILABLE", payload)
    assert(result == nil, "Should return nil on missing variable")
    assert(err:find("requestedBy_username", 1, true), "Should report missing requestedBy_username")
end)

test("returns error listing all missing variables", function()
    local payload = {}
    local result, err = testable_functions.build_message("MEDIA_PENDING", payload)
    assert(result == nil, "Should return nil on missing variables")
    assert(err:find("subject", 1, true), "Should report missing subject")
    assert(err:find("message", 1, true), "Should report missing message")
end)

test("skips malformed extra items in payload", function()
    local payload = {
        subject = "Test",
        message = "msg",
        extra = {
            {name = "Good", value = "item"},
            "not a table",
            {name = "Missing value"},
            {value = "Missing name"},
            {name = "", value = "empty name"}
        }
    }
    local result = testable_functions.build_message("MEDIA_PENDING", payload)
    assert(result:find("**Good:** item", 1, true), "Should include valid extra")
    assert(not result:find("not a table", 1, true), "Should skip string items")
    assert(not result:find("Missing value", 1, true), "Should skip items without value")
    assert(not result:find("Missing name", 1, true), "Should skip items without name")
end)

test("returns no error when all placeholders are resolved", function()
    local payload = { subject = "Test", message = "Body" }
    local result, err = testable_functions.build_message("MEDIA_PENDING", payload)
    assert(err == nil, "Should not return error when all variables present")
    assert(result ~= nil, "Should return message content")
end)

print("\nreplace_placeholders:")
test("replaces present keys", function()
    local payload = {subject = "Hello", message = "World"}
    assert(testable_functions.replace_placeholders("{{subject}} {{message}}", payload) == "Hello World")
end)

test("replaces missing keys with empty string", function()
    local payload = {subject = "Test"}
    assert(testable_functions.replace_placeholders("{{subject}} {{missing}}", payload) == "Test ")
end)

test("handles empty input", function()
    assert(testable_functions.replace_placeholders("", {}) == "")
    assert(testable_functions.replace_placeholders(nil, {}) == "")
end)

print("\ncollect_unresolved:")
test("returns empty table when all placeholders resolve", function()
    local missing = testable_functions.collect_unresolved("{{subject}} {{message}}", {subject = "A", message = "B"})
    assert(#missing == 0)
end)

test("returns missing placeholder names", function()
    local missing = testable_functions.collect_unresolved("{{subject}} {{message}}", {subject = "A"})
    assert(#missing == 1)
    assert(missing[1] == "message")
end)

test("returns multiple missing placeholders", function()
    local missing = testable_functions.collect_unresolved("{{a}} {{b}} {{c}}", {})
    assert(#missing == 3)
end)

test("treats empty string values as unresolved", function()
    local missing = testable_functions.collect_unresolved("{{subject}}", {subject = ""})
    assert(#missing == 1)
    assert(missing[1] == "subject")
end)

test("returns empty table for nil input", function()
    assert(#testable_functions.collect_unresolved(nil, {}) == 0)
    assert(#testable_functions.collect_unresolved("", {}) == 0)
end)

test("returns empty table for string without placeholders", function()
    local missing = testable_functions.collect_unresolved("no placeholders here", {})
    assert(#missing == 0)
end)

print("\nget_template:")
test("uses custom template when defined", function()
    testable_functions.notification_templates["TEST_CUSTOM"] = {
        subject = "Custom {{subject}}",
        message = "{{message}}",
        additionalExtras = { {name = "Status", value = "Custom"} }
    }
    local template = testable_functions.get_template("TEST_CUSTOM")
    assert(template.subject == "Custom {{subject}}")
    assert(#template.additionalExtras == 1)
    assert(template.additionalExtras[1].name == "Status")
    testable_functions.notification_templates["TEST_CUSTOM"] = nil
end)

test("falls back to default template", function()
    local template = testable_functions.get_template("NONEXISTENT_TYPE")
    assert(template.subject == "**{{subject}}**")
    assert(#template.additionalExtras == 0)
end)

print("\nMIME Type Validation:")
test("accepts common image formats", function()
    local formats = {"image/jpeg", "image/png", "image/gif", "image/webp"}
    for _, mime in ipairs(formats) do
        local valid, _ = testable_functions.validate_image_format(mime)
        assert(valid == true, "Should accept " .. mime)
    end
end)

test("rejects unsupported formats", function()
    local formats = {"image/svg+xml", "image/bmp", "text/plain", "application/json"}
    for _, mime in ipairs(formats) do
        local valid, err = testable_functions.validate_image_format(mime)
        assert(valid == false, "Should reject " .. mime)
        assert(err:find("Unsupported") or err:find("format"))
    end
end)

test("handles nil MIME type", function()
    local valid, err = testable_functions.validate_image_format(nil)
    assert(valid == false)
    assert(err == "Could not determine image format")
end)

print("\nMIME Type Extraction:")
test("extracts MIME type from Content-Type header", function()
    assert(testable_functions.get_mime_type("image/jpeg; charset=utf-8") == "image/jpeg")
end)

test("handles plain MIME type", function()
    assert(testable_functions.get_mime_type("image/png") == "image/png")
end)

test("handles nil Content-Type", function()
    assert(testable_functions.get_mime_type(nil) == nil)
end)

print("\nBase64 Encoding:")
test("encodes empty string", function()
    assert(testable_functions.base64_encode("") == "")
end)

test("encodes simple ASCII text", function()
    assert(testable_functions.base64_encode("Hello") == "SGVsbG8=")
end)

test("encodes text with padding", function()
    assert(testable_functions.base64_encode("A") == "QQ==")
    assert(testable_functions.base64_encode("AB") == "QUI=")
    assert(testable_functions.base64_encode("ABC") == "QUJD")
end)

test("encodes binary data", function()
    local binary = string.char(0, 1, 2, 255, 254, 253)
    local result = testable_functions.base64_encode(binary)
    assert(type(result) == "string")
    assert(#result > 0, "Should produce non-empty output for binary input")
end)

print("\nNotification Type Validation:")
test("validates notification types correctly", function()
    local constants = require("src.seerr-notification.constants")
    assert(constants.is_valid_notification_type("MEDIA_PENDING") == true)
    assert(constants.is_valid_notification_type("MEDIA_APPROVED") == true)
    assert(constants.is_valid_notification_type("ISSUE_CREATED") == true)
    assert(constants.is_valid_notification_type("INVALID_TYPE") == false)
    assert(constants.is_valid_notification_type("") == false)
    assert(constants.is_valid_notification_type(nil) == false)
end)

print("\n========================================")
print(string.format("  Results: %d passed, %d failed", tests_passed, tests_failed))
print("========================================")

if tests_failed > 0 then
    os.exit(1)
end
