# Seerr Notification Plugin

[![Tests](https://github.com/lkshrk/signal-cli-seerr-plugin/actions/workflows/test.yml/badge.svg)](https://github.com/lkshrk/signal-cli-seerr-plugin/actions/workflows/test.yml)
[![Release](https://github.com/lkshrk/signal-cli-seerr-plugin/actions/workflows/release.yml/badge.svg)](https://github.com/lkshrk/signal-cli-seerr-plugin/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A [signal-cli-rest-api plugin](https://github.com/bbernhard/signal-cli-rest-api) that converts [Seerr webhook payloads](https://docs.seerr.dev/using-jellyseerr/notifications/webhook#template-variables) into rich, formatted Signal messages with images and structured data.

## Features

- Template-based formatting for different Seerr notification types
- Support image attachment
- Parses all Seerr variables (media, users, issues, comments)
- Signal native formatting

## Installation

Download the latest release and extract to your signal-cli-rest-api plugins directory:

```bash
# Download the latest release
curl -L -o plugin.tar.gz https://github.com/lkshrk/signal-cli-seerr-plugin/releases/latest/download/seerr-notification-plugin.tar.gz

# Extract to your plugins directory
tar -xzf plugin.tar.gz -C /path/to/your/plugins/ --strip-components=1 seerr-notification
```

Restart signal-cli-rest-api container to load the plugin.

**Requirements:**
- signal-cli-rest-api with plugin support enabled (`ENABLE_PLUGINS=true`)
- Plugins directory mounted in Docker container

## API Usage

**Endpoint**: `POST /v1/plugins/seerr-notification`

## Seerr Webhook Payload

Configure your Seerr instance to send webhooks to this plugin. The payload uses Seerr's [webhook template variables](https://docs.seerr.dev/using-jellyseerr/notifications/webhook#template-variables) as flat keys:

```json
{
  "recipient": "+1234567890",
  "sender": "+0987654321",
  "notification_type": "{{notification_type}}",
  "subject": "{{subject}}",
  "message": "{{message}}",
  "image": "{{image}}",
  "requestedBy_username": "{{requestedBy_username}}",
  "{{extra}}": []
}
```

You can include any Seerr template variable (e.g. `{{media_type}}`, `{{issue_id}}`, `{{reportedBy_username}}`) as a key in the payload. See the [full variable list](https://docs.seerr.dev/using-jellyseerr/notifications/webhook#template-variables) for all available options.

**Required Fields:**
- `recipient`: Signal phone number to receive the message
- `sender`: Signal phone number to send from (must be registered in signal-cli-rest-api)
- `notification_type`: Determines which template is used (e.g., `MEDIA_PENDING`, `MEDIA_APPROVED`)
- `subject`: Notification title
- `message`: Notification body

## Message Format

Messages are formatted with:
- **Subject**: Bold subject line from Seerr
- **Message**: Message text from Seerr
- **Additional Extras**: Template-defined fields (e.g., requested by, status)
- **Payload Extras**: Any fields from Seerr's `extra` array

**Example output (MEDIA_AVAILABLE):**
```
**The Matrix**
Your request is now available!
**Requested By:** john
**Request Status:** Available
```

All template placeholders must be resolvable from the payload. Missing variables return HTTP 400 with the unresolved variable names.

## Customization

### Message Content
Title and message come directly from your Seerr webhook payload - customize them in your Seerr notification settings.

### Template Customization

Ships with a default template and a `MEDIA_AVAILABLE` template. To add custom templates for other notification types, edit `src/seerr-notification/templates.lua`:

```lua
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
```

**Template fields:**
- `subject` - Message subject line (supports placeholders)
- `message` - Message body (supports placeholders)
- `additionalExtras` - List of extra fields to append, each with `name` and `value` (supports placeholders)

**Placeholders:** Any Seerr template variable can be used (e.g. `{{subject}}`, `{{media_type}}`, `{{requestedBy_username}}`). All placeholders in a template must be present in the payload — missing variables return an error. See the [full list](https://docs.seerr.dev/using-jellyseerr/notifications/webhook#template-variables).

### Image Handling
**Simple rule:** If Seerr sends an `image` URL in the payload, the plugin downloads and attaches it to the Signal message. If no image is provided, none is attached.

No configuration needed - it's automatic based on what Seerr sends!

#### Failure Behavior

**Image Download Failures:**
- If image URL returns 404 or network error → Returns HTTP 400 with error message
- If image exceeds 2MB limit → Returns HTTP 400 with size error
- If image format unsupported → Returns HTTP 400 with format error
- The message is NOT sent if image download fails

**Signal API Failures:**
- If Signal API is unreachable → Returns HTTP 500 with error message
- If Signal API returns non-200 status → Returns HTTP 500 with API status code
- Network timeouts default to 30 seconds

## Configuration

Environment variables:
- `SIGNAL_API_URL` - Signal API endpoint (default: http://127.0.0.1:8080)

## Testing

```bash
make test-unit    # Unit tests
make lint        # Syntax check
make test-integration  # Integration tests
```

## License

MIT
