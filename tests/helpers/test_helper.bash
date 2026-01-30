#!/usr/bin/env bash

# Test Helper Library for Signal CLI Rich Message Plugin
# Common functions and utilities for bash-based tests

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if required tools are available
check_prerequisites() {
    local tools=("$@")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo -e "${RED}Error: $tool is not installed${NC}"
            return 1
        fi
    done
    return 0
}

# Wait for API to be ready
wait_for_api() {
    local api_url=$1
    local max_attempts=${2:-30}
    local wait_time=${3:-1}
    
    log_info "Waiting for API at $api_url to be ready..."
    
    for i in $(seq 1 $max_attempts); do
        if curl -s "$api_url/v1/about" > /dev/null 2>&1; then
            log_info "API is ready!"
            return 0
        fi
        sleep $wait_time
    done
    
    log_fail "API failed to start within $max_attempts seconds"
    return 1
}

# Make HTTP request and capture response
http_request() {
    local method=$1
    local url=$2
    local payload=$3
    local content_type=${4:-"application/json"}
    
    local response
    local http_code
    
    if [ -n "$payload" ]; then
        response=$(curl -s -w "\n%{http_code}" \
            -X "$method" \
            -H "Content-Type: $content_type" \
            -d "$payload" \
            "$url" 2>&1 || echo "")
    else
        response=$(curl -s -w "\n%{http_code}" \
            -X "$method" \
            "$url" 2>&1 || echo "")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    echo "$http_code|$body"
}

# Extract HTTP code from response
get_http_code() {
    echo "$1" | cut -d'|' -f1
}

# Extract body from response
get_body() {
    echo "$1" | cut -d'|' -f2-
}

# Assert HTTP status code
assert_status() {
    local expected=$1
    local actual=$2
    local message=$3
    
    if [ "$actual" = "$expected" ]; then
        log_pass "$message (HTTP $actual)"
        return 0
    else
        log_fail "$message - Expected HTTP $expected, got $actual"
        return 1
    fi
}

# Assert string contains substring
assert_contains() {
    local haystack=$1
    local needle=$2
    local message=$3
    
    if echo "$haystack" | grep -q "$needle"; then
        log_pass "$message"
        return 0
    else
        log_fail "$message - Expected to find '$needle'"
        return 1
    fi
}

# Assert string does not contain substring
assert_not_contains() {
    local haystack=$1
    local needle=$2
    local message=$3
    
    if echo "$haystack" | grep -q "$needle"; then
        log_fail "$message - Found unexpected '$needle'"
        return 1
    else
        log_pass "$message"
        return 0
    fi
}

# Print test summary
print_summary() {
    echo ""
    log_section "Test Results"
    echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
    echo -e "Total:  ${TESTS_TOTAL}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Save test results to JSON file
save_results() {
    local output_file=$1
    mkdir -p "$(dirname "$output_file")"
    echo "{\"passed\": ${TESTS_PASSED}, \"failed\": ${TESTS_FAILED}, \"total\": ${TESTS_TOTAL}}" > "$output_file"
}
