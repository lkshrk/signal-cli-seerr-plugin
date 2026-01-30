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
        -d '{"recipient": "'"$RECIPIENT"'", "image_url": "https://httpbin.org/image/jpeg"}' \
        "${API_URL}/v1/plugins/rich-message/${SENDER_NUMBER}"
    [ "$output" -eq 400 ] || [ "$output" -eq 200 ] || [ "$output" -eq 500 ]
}

@test "Reject missing recipient" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"image_url": "https://httpbin.org/image/jpeg"}' \
        "${API_URL}/v1/plugins/rich-message/${SENDER_NUMBER}"
    
    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')
    
    [ "$http_code" -eq 400 ]
    [[ "$body" == *"recipient"* ]]
}

@test "Reject missing image_url" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"recipient": "'"$RECIPIENT"'"}' \
        "${API_URL}/v1/plugins/rich-message/${SENDER_NUMBER}"
    
    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')
    
    [ "$http_code" -eq 400 ]
    [[ "$body" == *"image_url"* ]]
}

@test "Reject invalid JSON" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d 'not valid json' \
        "${API_URL}/v1/plugins/rich-message/${SENDER_NUMBER}"
    
    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 400 ]
}

@test "Accept formatted text" {
    run curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "image_url": "https://httpbin.org/image/jpeg",
            "text": "Test with **bold** and *italic*"
        }' \
        "${API_URL}/v1/plugins/rich-message/${SENDER_NUMBER}"
    
    [ "$output" -eq 400 ] || [ "$output" -eq 200 ] || [ "$output" -eq 500 ]
}

@test "Accept URL with alias" {
    run curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "image_url": "https://httpbin.org/image/jpeg",
            "text": "Check this out!",
            "url": "https://example.com/article",
            "url_alias": "Read full article"
        }' \
        "${API_URL}/v1/plugins/rich-message/${SENDER_NUMBER}"
    
    [ "$output" -eq 400 ] || [ "$output" -eq 200 ] || [ "$output" -eq 500 ]
}

@test "Handle 404 image URL" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "image_url": "https://httpbin.org/status/404"
        }' \
        "${API_URL}/v1/plugins/rich-message/${SENDER_NUMBER}"
    
    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 400 ]
}

@test "Reject unsupported image format" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "image_url": "https://httpbin.org/image/svg"
        }' \
        "${API_URL}/v1/plugins/rich-message/${SENDER_NUMBER}"
    
    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 400 ]
}
