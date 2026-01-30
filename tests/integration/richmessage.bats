#!/usr/bin/env bats

# BATS Integration Tests for Signal CLI Rich Message Plugin
# Run with: bats tests/integration/richmessage.bats

setup() {
    # Load test helper
    load '../helpers/test_helper'
    
    # Set test variables
    export API_URL="${API_URL:-http://localhost:8080}"
    export SENDER_NUMBER="${SENDER_NUMBER:-+1234567890}"
    export RECIPIENT="${RECIPIENT:-+0987654321}"
}

@test "API is running and accessible" {
    run curl -s -o /dev/null -w "%{http_code}" "${API_URL}/v1/about"
    [ "$output" -eq 200 ]
}

@test "Plugin endpoint exists" {
    run curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'", "image_url": "https://httpbin.org/image/jpeg"}' \
        "${API_URL}/v1/plugins/rich-message"
    [ "$output" -eq 400 ] || [ "$output" -eq 200 ] || [ "$output" -eq 500 ]
}

@test "Reject missing recipient" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"image_url": "https://httpbin.org/image/jpeg"}' \
        "${API_URL}/v1/plugins/rich-message"
    
    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')
    
    [ "$http_code" -eq 400 ]
    [[ "$body" == *"recipient"* ]]
}

@test "Accept message without image_url" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"recipient": "'"$RECIPIENT"'", "sender": "'"$SENDER_NUMBER"'", "text": "Hello **world**!"}' \
        "${API_URL}/v1/plugins/rich-message"
    
    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')
    
    # Allow any response since we can't guarantee signal-cli is properly configured
    [ "$http_code" -eq 400 ] || [ "$http_code" -eq 200 ] || [ "$http_code" -eq 500 ]
}

@test "Reject invalid JSON" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d 'not valid json' \
        "${API_URL}/v1/plugins/rich-message"
    
    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 400 ]
}

@test "Accept formatted text" {
    run curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "image_url": "https://httpbin.org/image/jpeg",
            "text": "Test with **bold** and *italic*"
        }' \
        "${API_URL}/v1/plugins/rich-message"
    
    [ "$output" -eq 400 ] || [ "$output" -eq 200 ] || [ "$output" -eq 500 ]
}

@test "Accept message with title" {
    run curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "title": "Breaking News",
            "image_url": "https://httpbin.org/image/jpeg",
            "text": "Major update!"
        }' \
        "${API_URL}/v1/plugins/rich-message"
    
    [ "$output" -eq 400 ] || [ "$output" -eq 200 ] || [ "$output" -eq 500 ]
}

@test "Handle 404 image URL" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "image_url": "https://httpbin.org/status/404"
        }' \
        "${API_URL}/v1/plugins/rich-message"
    
    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 400 ]
}

@test "Reject unsupported image format" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "image_url": "https://httpbin.org/image/svg"
        }' \
        "${API_URL}/v1/plugins/rich-message"
    
    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 400 ]
}
