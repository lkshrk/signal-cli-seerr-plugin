#!/usr/bin/env bash

# Manual Test Script for Rich Message Plugin
# Usage: ./scripts/manual_test.sh <API_URL> <SENDER_NUMBER>
# Example: ./scripts/manual_test.sh http://localhost:8080 +1234567890

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load test helper
source "${SCRIPT_DIR}/../tests/helpers/test_helper.sh"

# Arguments
API_URL=${1:-"http://localhost:8080"}
SENDER_NUMBER=${2:-"+1234567890"}
RECIPIENT=${3:-"+0987654321"}

log_section "Rich Message Plugin - Manual Test"
echo -e "API URL:        ${YELLOW}$API_URL${NC}"
echo -e "Sender Number:  ${YELLOW}$SENDER_NUMBER${NC}"
echo -e "Recipient:      ${YELLOW}$RECIPIENT${NC}"
echo ""

# Check prerequisites
check_prerequisites curl || exit 1

# Wait for API
wait_for_api "$API_URL" || exit 1
echo ""

# Test function
run_test() {
    local test_name=$1
    local payload=$2
    local expected_error=$3
    
    log_info "Test: $test_name"
    
    response=$(http_request "POST" \
        "${API_URL}/v1/plugins/rich-message" \
        "$payload")
    
    http_code=$(get_http_code "$response")
    body=$(get_body "$response")
    
    if [ "$expected_error" = "true" ]; then
        if [ "$http_code" -ge 400 ]; then
            log_pass "Got expected error (HTTP $http_code)"
        else
            log_fail "Expected error but got HTTP $http_code"
        fi
    else
        if [ "$http_code" -lt 400 ]; then
            log_pass "Success (HTTP $http_code)"
        else
            log_fail "Failed (HTTP $http_code)"
        fi
    fi
}

echo "----------------------------------------"

# Test 1: Simple message
run_test "Simple message with image" '{
    "recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'",
    "image_url": "https://httpbin.org/image/jpeg"
}'

echo ""
echo "----------------------------------------"

# Test 2: Formatted text
run_test "Formatted text (bold, italic)" '{
    "recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'",
    "image_url": "https://httpbin.org/image/jpeg",
    "text": "This is **bold** and *italic* text"
}'

echo ""
echo "----------------------------------------"

# Test 3: URL with alias
run_test "URL with alias" '{
    "recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'",
    "image_url": "https://httpbin.org/image/jpeg",
    "text": "Check this out!",
    "url": "https://example.com",
    "url_alias": "Visit website"
}'

echo ""
echo "----------------------------------------"

# Test 4: Message with title
run_test "Message with title" '{
    "recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'",
    "title": "Breaking News",
    "image_url": "https://httpbin.org/image/jpeg",
    "text": "Major update just announced!",
    "url": "https://example.com/story"
}'

echo ""
echo "----------------------------------------"

# Test 5: Missing recipient (should fail)
run_test "Missing recipient (expect error)" '{
    "image_url": "https://httpbin.org/image/jpeg"
}' "true"

echo ""
echo "----------------------------------------"

# Test 6: Text-only message (no image - should succeed)
run_test "Text-only message (no image)" '{
    "recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'",
    "text": "Hello **world**!"
}' "false"

echo ""
echo "----------------------------------------"

# Test 8: Invalid JSON (should fail)
run_test "Invalid JSON (expect error)" 'not valid json' "true"

echo ""
echo "----------------------------------------"

# Test 9: 404 image (should fail)
run_test "404 image URL (expect error)" '{
    "recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'",
    "image_url": "https://httpbin.org/status/404"
}' "true"

echo ""
print_summary

echo ""
echo "Note: These tests use httpbin.org for sample images."
echo "For production use, ensure signal-cli is properly configured."
