# Contributing

Contributions are welcome: bug reports, new notification types, message format
improvements and docs.

## Reporting issues

Open an issue with your signal-cli-rest-api and Seerr versions, the webhook
payload (with personal data removed), and the message you expected versus the
one you got.

## Development

Requires Lua. See [INSTALL.md](INSTALL.md) for installing the plugin into
signal-cli-rest-api.

```sh
make help              # list targets
make lint              # syntax check
make test-unit         # unit tests
make test-integration  # integration tests
make build             # package the plugin
```

CI runs `lint`, `test-unit`, `build` and `test-integration`; run them locally
before opening a PR.

## Pull requests

- Fork, branch from `main`, and keep each PR focused on one change.
- Add specs under `spec/` for new behaviour.
- Update the README when you change the payload handling or message format.
- Use [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `chore:`).

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
