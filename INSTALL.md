# Installation Guide

This guide explains how to install the Seerr Notification Plugin for signal-cli-rest-api.

## Requirements

- signal-cli-rest-api with plugin support enabled (`ENABLE_PLUGINS=true`)
- Plugins directory mounted into the container
- A registered Signal sender number in signal-cli-rest-api

## Download and Extract

Download the latest release and extract it into your plugins directory:

```/dev/null/commands.sh#L1-8
# Download the latest release
curl -L -o plugin.tar.gz https://github.com/lkshrk/signal-cli-seerr-plugin/releases/latest/download/seerr-notification-plugin.tar.gz

# Extract to your plugins directory
tar -xzf plugin.tar.gz -C /path/to/your/plugins/ --strip-components=1 seerr-notification
```

After extraction, your plugins directory should contain:

- `seerr-notification.def`
- `seerr-notification.lua`
- `README.md`
- `LICENSE`

## Enable Plugins

Ensure plugins are enabled and the plugins directory is mounted. Example `docker-compose.yml` snippet:

```/dev/null/docker-compose.yml#L1-9
services:
  signal-cli-rest-api:
    image: bbernhard/signal-cli-rest-api:latest
    environment:
      - MODE=json-rpc
      - ENABLE_PLUGINS=true
    volumes:
      - ./plugins:/plugins
```

## Restart the Container

Restart signal-cli-rest-api so it loads the new plugin.

## Configure Seerr Webhook

Point your Seerr webhook to:

```
http://your-server:8080/v1/plugins/seerr-notification
```

## Optional Configuration

You can set a custom Signal API URL if needed:

- `SIGNAL_API_URL` (default: `http://127.0.0.1:8080`)

## Next Steps

See `README.md` for:
- Payload structure
- Template customization
- Supported notification types
- Image handling behavior