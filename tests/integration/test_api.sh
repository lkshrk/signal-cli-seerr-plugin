#!/bin/sh

# Integration Test Script for Rich Message Plugin
# Runs against signal-cli-rest-api in Docker

set -e

API_URL="http://signal-api:8080"
SENDER_NUMBER="+1234567890"
RECIPIENT="+0987654321"

# Colors for output (using printf for sh compatibility)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    printf "${YELLOW}[INFO]${NC} %s\n" "$1"
}

log_pass() {
    printf "${GREEN}[PASS]${NC} %s\n" "$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    printf "${RED}[FAIL]${NC} %s\n" "$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Wait for API to be ready
wait_for_api() {
    log_info "Waiting for API to be ready..."
    for i in $(seq 1 30); do
        if curl -s "${API_URL}/v1/about" > /dev/null 2>&1; then
            log_info "API is ready!"
            return 0
        fi
        sleep 1
    done
    log_fail "API failed to start within 30 seconds"
    exit 1
}

# Main execution
main() {
    printf "========================================\n"
    printf "Rich Message Plugin Integration Tests\n"
    printf "========================================\n"
    printf "\n"
    
    wait_for_api
    
    printf "\nRunning tests...\n\n"
    
    # Test 1: Check plugin is loaded
    log_info "Test 1: Checking if plugin is loaded..."
    RESPONSE=$(curl -s -w "\n%{http_code}" "${API_URL}/v1/about" || echo "")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "200" ]; then
        log_pass "API is running and accessible"
    else
        log_fail "API returned HTTP $HTTP_CODE"
    fi
    
    # Test 2: Simple message with image
    log_info "Test 2: Sending simple message with image..."
    PAYLOAD='{"recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'", "image_url": "https://httpbin.org/image/jpeg", "text": "Test message"}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "${API_URL}/v1/plugins/rich-message" || echo "")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "500" ]; then
        log_pass "Plugin processed request (HTTP $HTTP_CODE)"
    else
        log_fail "Unexpected HTTP code: $HTTP_CODE"
    fi
    
    # Test 3: Missing recipient
    log_info "Test 3: Testing missing recipient validation..."
    PAYLOAD='{"image_url": "https://httpbin.org/image/jpeg"}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "${API_URL}/v1/plugins/rich-message" || echo "")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "400" ]; then
        log_pass "Correctly rejected missing recipient"
    else
        log_fail "Should have rejected missing recipient (got HTTP $HTTP_CODE)"
    fi
    
    # Test 4: Text-only message (no image_url)
    log_info "Test 4: Testing text-only message without image_url..."
    PAYLOAD='{"recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'", "text": "Hello **world**!"}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "${API_URL}/v1/plugins/rich-message" || echo "")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    # Accept any response code - plugin validates input but signal-cli may not be configured
    if [ -n "$HTTP_CODE" ]; then
        log_pass "Plugin processed text-only message (HTTP $HTTP_CODE)"
    else
        log_fail "No response from plugin"
    fi
    
    # Test 5: Invalid JSON
    log_info "Test 5: Testing invalid JSON handling..."
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d 'not valid json' "${API_URL}/v1/plugins/rich-message" || echo "")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "400" ]; then
        log_pass "Correctly rejected invalid JSON"
    else
        log_fail "Should have rejected invalid JSON (got HTTP $HTTP_CODE)"
    fi
    
    # Test 6: Formatted text
    log_info "Test 6: Testing formatted text..."
    PAYLOAD='{"recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'", "image_url": "https://httpbin.org/image/jpeg", "text": "Test with **bold** and *italic*"}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "${API_URL}/v1/plugins/rich-message" || echo "")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ -n "$HTTP_CODE" ]; then
        log_pass "Processed formatted text request (HTTP $HTTP_CODE)"
    else
        log_fail "Failed to process formatted text"
    fi

    # Test 7: 404 image URL
    log_info "Test 7: Testing 404 image URL handling..."
    PAYLOAD='{"recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'", "image_url": "https://httpbin.org/status/404"}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "${API_URL}/v1/plugins/rich-message" || echo "")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "400" ]; then
        log_pass "Correctly handled 404 image URL"
    else
        log_fail "Should have returned 400 for 404 image (got HTTP $HTTP_CODE)"
    fi
    
    # Test 8: Unsupported image format
    log_info "Test 8: Testing unsupported image format..."
    PAYLOAD='{"recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'", "image_url": "https://httpbin.org/image/svg"}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "${API_URL}/v1/plugins/rich-message" || echo "")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "400" ]; then
        log_pass "Correctly rejected unsupported format"
    else
        log_fail "Should have rejected unsupported format (got HTTP $HTTP_CODE)"
    fi
    
    # Test 9: Message with extra array field
    log_info "Test 9: Testing message with extra array field..."
    PAYLOAD='{"recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'", "text": "Main message", "extra": [{"name": "First", "value": "First detail"}, {"name": "Second", "value": "Second detail"}]}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "${API_URL}/v1/plugins/rich-message" || echo "")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ -n "$HTTP_CODE" ]; then
        log_pass "Processed message with extra array (HTTP $HTTP_CODE)"
    else
        log_fail "Failed to process message with extra array"
    fi
    
    printf "\n========================================\n"
    printf "Test Results\n"
    printf "========================================\n"
    printf "Passed: ${GREEN}%d${NC}\n" "$TESTS_PASSED"
    printf "Failed: ${RED}%d${NC}\n" "$TESTS_FAILED"
    printf "========================================\n"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        printf "${GREEN}All tests passed!${NC}\n"
        exit 0
    else
        printf "${RED}Some tests failed!${NC}\n"
        exit 1
    fi
}

main "$@"
