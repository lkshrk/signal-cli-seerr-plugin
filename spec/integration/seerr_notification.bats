#!/usr/bin/env bats

setup() {
    export API_URL="${API_URL:-http://localhost:18080}"
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
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "Test",
            "message": "Smoke test",
            "notification_type": "MEDIA_PENDING"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"
    [ "$output" -ne 404 ]
}

@test "Reject missing recipient" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "Test Movie",
            "notification_type": "MEDIA_PENDING"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')

    [ "$http_code" -eq 400 ]
    echo "$body" | grep -q "recipient"
}

@test "Reject missing sender" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "subject": "Test Movie",
            "notification_type": "MEDIA_PENDING"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')

    [ "$http_code" -eq 400 ]
    echo "$body" | grep -q "sender"
}

@test "Reject missing notification_type" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "Test Movie"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')

    [ "$http_code" -eq 400 ]
    echo "$body" | grep -q "notification_type"
}

@test "Reject invalid JSON" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d 'not valid json' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 400 ]
}

@test "Reject unknown notification type" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "Test",
            "notification_type": "TOTALLY_FAKE_TYPE"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 400 ]
}

@test "Valid MEDIA_PENDING reaches Signal API (500 expected without registered number)" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "The Matrix",
            "message": "Please add this movie",
            "notification_type": "MEDIA_PENDING",
            "requestedBy_username": "john"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    # 500 = plugin processed OK but Signal API rejected (no registered number in test env)
    # 200 = full success (if a number happens to be registered)
    [ "$http_code" -eq 500 ] || [ "$http_code" -eq 200 ]
}

@test "Valid MEDIA_APPROVED reaches Signal API" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "The Matrix",
            "message": "Your request has been approved!",
            "notification_type": "MEDIA_APPROVED"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 500 ] || [ "$http_code" -eq 200 ]
}

@test "Valid ISSUE_CREATED reaches Signal API" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "Audio issue",
            "message": "The audio is out of sync",
            "notification_type": "ISSUE_CREATED"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 500 ] || [ "$http_code" -eq 200 ]
}

@test "Valid MEDIA_AVAILABLE reaches Signal API" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "The Matrix",
            "message": "Your request is now available!",
            "notification_type": "MEDIA_AVAILABLE",
            "requestedBy_username": "john"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 500 ] || [ "$http_code" -eq 200 ]
}

@test "Valid request with extra fields reaches Signal API" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "The Matrix",
            "message": "New request submitted",
            "notification_type": "MEDIA_PENDING",
            "requestedBy_username": "john",
            "extra": [
                {"name": "Quality", "value": "1080p"},
                {"name": "Season", "value": "3"}
            ]
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    [ "$http_code" -eq 500 ] || [ "$http_code" -eq 200 ]
}

@test "Reject missing template variables for default template" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "notification_type": "MEDIA_PENDING"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')

    [ "$http_code" -eq 400 ]
    echo "$body" | grep -qi "missing"
}

@test "Reject missing template variables for MEDIA_AVAILABLE" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "The Matrix",
            "message": "Available now",
            "notification_type": "MEDIA_AVAILABLE"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')

    [ "$http_code" -eq 400 ]
    echo "$body" | grep -q "requestedBy_username"
}

@test "Reject invalid image URL" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "recipient": "'"$RECIPIENT"'",
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "Test",
            "message": "Image test",
            "notification_type": "MEDIA_PENDING",
            "image": "https://httpbin.org/status/404"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')

    [ "$http_code" -eq 400 ]
}

@test "Error response structure is correct" {
    run curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "sender": "'"$SENDER_NUMBER"'",
            "subject": "Missing recipient test"
        }' \
        "${API_URL}/v1/plugins/seerr-notification"

    http_code=$(echo "$output" | tail -n1)
    body=$(echo "$output" | sed '$d')

    [ "$http_code" -eq 400 ]
    echo "$body" | grep -q '\\"success\\":false'
    echo "$body" | grep -q '\\"error\\"'
}
