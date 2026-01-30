# Signal CLI Rich Message Plugin

A powerful plugin for [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api) that enables sending rich messages with images, formatted text, and clickable URLs.

## Features

- 📸 **Image Attachments** - Automatically downloads and attaches images from URLs
- 📝 **Text Formatting** - Supports bold, italic, code, strikethrough, and spoiler formatting
- 🔗 **URL Support** - Optional URLs with custom display text
- 🛡️ **Validation** - Image format validation (JPEG, PNG, GIF, WebP) and 5MB size limit
- ⚡ **Signal Native** - Uses `text_mode: "styled"` for native Signal formatting
- 🧪 **Well Tested** - Comprehensive unit and integration tests

## Quick Start

### Prerequisites

- Docker and Docker Compose
- signal-cli-rest-api running with plugins enabled

### Installation

#### Option 1: Download from GitHub Releases (Recommended)

1. **Download the latest release:**
```bash
curl -L -o richmessage-plugin.tar.gz \
  https://github.com/lkshrk/signal-cli-rich-message-plugin/releases/latest/download/signal-richmessage-plugin-v1.0.0.tar.gz
```

2. **Extract to your plugins directory:**
```bash
tar -xzf richmessage-plugin.tar.gz -C /path/to/your/plugins/
# Or manually copy the two files:
# cp signal-richmessage-plugin/richmessage.def /path/to/your/plugins/
# cp signal-richmessage-plugin/richmessage.lua /path/to/your/plugins/
```

#### Option 2: Clone from GitHub

```bash
git clone https://github.com/lkshrk/signal-cli-rich-message-plugin.git
cp signal-cli-rich-message-plugin/plugins/richmessage.* /path/to/your/plugins/
```

#### Option 3: Docker Compose with Volume Mount

**Update your docker-compose.yml:**
```yaml
services:
  signal-cli-rest-api:
    image: bbernhard/signal-cli-rest-api:latest
    environment:
      - MODE=json-rpc
      - ENABLE_PLUGINS=true  # Enable plugins!
    ports:
      - "8080:8080"
    volumes:
      - "./signal-cli-config:/home/.local/share/signal-cli"
      - "./plugins:/plugins"  # Mount plugins directory
```

**Restart the container:**
```bash
docker-compose up -d
```

## Usage

### API Endpoint

```
POST /v1/plugins/rich-message/:number
```

Where `:number` is your registered Signal phone number.

### Request Format

```json
{
  "recipient": "+0987654321",
  "image_url": "https://example.com/image.jpg",
  "text": "Check out this **amazing** photo!",
  "url": "https://example.com/article",
  "url_alias": "Read full story"
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `recipient` | string | Yes | Phone number of recipient (with country code) |
| `image_url` | string | Yes | Public URL of image to attach |
| `text` | string | No | Message text with formatting support |
| `url` | string | No | Optional URL to append to message |
| `url_alias` | string | No | Display text for the URL |

### Text Formatting

Use markdown-style syntax in your text:

- `**bold**` - Bold text
- `*italic*` - Italic text
- `` `code` `` - Monospace text
- `~strikethrough~` - Strikethrough text
- `||spoiler||` - Spoiler text

### Example Requests

**Simple image message:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "+0987654321",
    "image_url": "https://example.com/photo.jpg"
  }' \
  http://localhost:8080/v1/plugins/rich-message/+1234567890
```

**Formatted text with image:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "+0987654321",
    "image_url": "https://example.com/promo.jpg",
    "text": "New **sale** starts *today*! Don't miss out!"
  }' \
  http://localhost:8080/v1/plugins/rich-message/+1234567890
```

**Complete rich message with URL:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "+0987654321",
    "image_url": "https://example.com/article.jpg",
    "text": "Check out this **breaking news**!",
    "url": "https://news.example.com/story",
    "url_alias": "Read full story"
  }' \
  http://localhost:8080/v1/plugins/rich-message/+1234567890
```

This produces:
```
Check out this breaking news!

Read full story:
https://news.example.com/story
```

## Image Requirements

### Supported Formats
- ✅ JPEG / JPG
- ✅ PNG
- ✅ GIF
- ✅ WebP

### Size Limits
- **Maximum**: 5 MB per image
- **Recommended**: Under 2 MB for fast sending

Images exceeding the size limit will be rejected with a clear error message.

## Testing

### Unit Tests (Busted)

Run unit tests using [Busted](https://lunarmodules.github.io/busted/):

```bash
# Install Busted
luarocks install busted
luarocks install lua-cjson

# Run tests
busted tests/unit/

# Run with coverage
busted tests/unit/ --coverage
```

### Integration Tests (BATS)

Run integration tests using [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System):

```bash
# Install BATS
# macOS:
brew install bats-core

# Linux:
sudo apt-get install bats

# Run integration tests against running API
export API_URL=http://localhost:8080
export SENDER_NUMBER=+1234567890
export RECIPIENT=+0987654321
bats tests/integration/richmessage.bats
```

**Docker Integration Tests:**

```bash
cd tests/integration

# Start test environment
docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit

# Or run in background and check logs
docker-compose -f docker-compose.test.yml up -d
docker-compose -f docker-compose.test.yml logs -f test-runner
```

### Manual Testing

Use the provided test script:

```bash
./scripts/manual_test.sh http://localhost:8080 +1234567890
```

### Test Structure

```
tests/
├── unit/                      # Lua unit tests (Busted)
│   ├── helpers/
│   │   ├── http_mock.lua     # HTTP mocking utilities
│   │   └── json.lua          # JSON implementation for tests
│   └── richmessage_spec.lua  # 17 unit tests
├── integration/               # Bash integration tests (BATS)
│   ├── richmessage.bats      # 9 integration tests
│   ├── docker-compose.test.yml
│   └── test_api.sh           # Legacy shell script (deprecated)
└── helpers/
    └── test_helper.sh        # Shared bash test utilities
```

## Architecture

```
┌─────────────┐     POST /v1/plugins/rich-message/+NUMBER     ┌─────────────┐
│   Client    │ ────────────────────────────────────────────────→ │   Plugin    │
│  (Sender)   │    {                                              │   (Lua)     │
│             │      image_url: "https://.../img.jpg",            │             │
│             │      text: "Hello **bold** _italic_",             │             │
│             │      url: "https://example.com",                  │             │
│             │      url_alias: "Read more"                       │             │
│             │    }                                              │             │
└─────────────┘                                                   └──────┬──────┘
                                                                          │
                                                                          ↓
                                                                 ┌────────────────┐
                                                                 │ 1. Validate    │
                                                                 │    input       │
                                                                 │ 2. Check image │
                                                                 │    format/size │
                                                                 │ 3. Download    │
                                                                 │    image       │
                                                                 │ 4. Base64      │
                                                                 │    encode      │
                                                                 │ 5. Format msg  │
                                                                 │ 6. Call /send  │
                                                                 └───────┬────────┘
                                                                         │
                                                                         ↓ POST /v2/send
                                                                 ┌────────────────┐
                                                                 │ signal-cli-rest│
                                                                 │    -api        │
                                                                 └───────┬────────┘
                                                                         │
                                                                         ↓
                                                                 ┌────────────────┐
                                                                 │ Signal Network │
                                                                 └────────────────┘
```

## Error Handling

The plugin returns appropriate HTTP status codes:

| Scenario | HTTP Code | Message |
|----------|-----------|---------|
| Missing `recipient` | 400 | "recipient is required" |
| Missing `image_url` | 400 | "image_url is required" |
| Invalid JSON | 400 | "Invalid JSON in request body" |
| Unsupported format | 400 | "Unsupported image format: X. Supported: image/jpeg, image/png..." |
| Image > 5MB | 400 | "Image exceeds 5MB limit (size: X MB)" |
| Image 404 | 400 | "Image URL returned HTTP 404" |
| API failure | 500 | "Failed to send message: [details]" |

## Development

### Project Structure

```
signal-cli-rich-message-plugin/
├── plugins/
│   ├── richmessage.def          # Plugin definition (endpoint, method)
│   └── richmessage.lua          # Main plugin implementation
├── tests/
│   ├── unit/
│   │   ├── helpers/
│   │   │   └── http_mock.lua   # HTTP mocking for tests
│   │   ├── fixtures/           # Test data
│   │   └── richmessage_spec.lua # Unit tests
│   └── integration/
│       ├── docker-compose.test.yml
│       ├── test_api.sh         # Integration test script
│       └── test-data/          # Test signal-cli config
├── .busted                      # Busted test config
├── .github/
│   └── workflows/
│       └── test.yml            # CI/CD pipeline
└── README.md                    # This file
```

### Writing Tests

Add new test cases to `tests/unit/richmessage_spec.lua`:

```lua
describe("My Feature", function()
  it("should do something", function()
    -- Setup mocks
    _G.pluginInputData = http_mock.create_plugin_input(
      json.encode({recipient = "+123", image_url = "https://..."}),
      {number = "+456"}
    )
    
    -- Run plugin
    dofile("plugins/richmessage.lua")
    
    -- Assert results
    assert.are.equal(200, plugin_output.httpStatusCode)
  end)
end)
```

## Troubleshooting

### Plugin Not Loading

1. Check `ENABLE_PLUGINS=true` is set in environment
2. Verify plugins directory is mounted to `/plugins` in container
3. Check both `.def` and `.lua` files exist with matching names
4. Check container logs: `docker-compose logs signal-cli-rest-api`

### Image Download Fails

1. Verify image URL is publicly accessible (no authentication required)
2. Check image format is supported
3. Verify image size is under 5MB
4. Check network connectivity from container

### Formatting Not Working

1. Verify `text_mode: "styled"` is set in request (plugin does this automatically)
2. Check Signal client version supports formatting (Android 6.24+, iOS 6.36+, Desktop 6.22+)
3. Verify syntax: `**bold**`, `*italic*`, not markdown links

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Write tests for your changes
4. Run tests: `busted tests/unit/`
5. Commit: `git commit -am 'Add new feature'`
6. Push: `git push origin feature/my-feature`
7. Submit a pull request

## Versioning

This project follows [Semantic Versioning](https://semver.org/) (SemVer):

- **MAJOR** version (X.y.z) - Breaking changes to the API
- **MINOR** version (x.Y.z) - New features, backwards compatible
- **PATCH** version (x.y.Z) - Bug fixes, backwards compatible

### Current Version

Check the latest release on [GitHub Releases](https://github.com/lkshrk/signal-cli-rich-message-plugin/releases).

### Creating a Release

We use **git tags** for versioning with an automated release script:

```bash
# Make the script executable (first time only)
chmod +x scripts/release.sh

# Create a release (automatically generates changelog from commits)
./scripts/release.sh patch   # 1.0.0 → 1.0.1 (bug fixes)
./scripts/release.sh minor   # 1.0.0 → 1.1.0 (new features)
./scripts/release.sh major   # 1.0.0 → 2.0.0 (breaking changes)
```

**What the script does:**
1. ✅ Reads current version from latest git tag
2. ✅ Calculates new version based on SemVer
3. ✅ Generates changelog from commit messages since last tag
4. ✅ Creates annotated git tag with changelog
5. ✅ Pushes to trigger GitHub Actions release

**Manual release (if needed):**
```bash
# 1. Commit your changes
git add .
git commit -m "Your changes"

# 2. Create and push tag
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin main
git push origin v1.1.0

# 3. GitHub Actions automatically creates the release!
```

## License

MIT License - see LICENSE file for details

## Acknowledgments

- [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api) - The awesome REST API that makes this possible
- [signal-cli](https://github.com/AsamK/signal-cli) - Command-line interface for Signal
- [Busted](https://lunarmodules.github.io/busted/) - Elegant Lua unit testing

## Support

- 🐛 **Bug Reports**: Open an issue on GitHub
- 💡 **Feature Requests**: Open an issue with the "feature request" label
- 📖 **Documentation**: Check the [Wiki](../../wiki) for more examples
