# CLAUDE.md — Claude Code instructions

See README.md for project overview, setup, and CLI usage.
See CONTRIBUTING.md for PR workflow and linting setup.

## Project Structure
- `ethd` — main CLI wrapper. `bittensord` is a symlink to `ethd`.
- `bittensor.yml` — Docker Compose service definition. Volume `subtensor-data` at `/data`.
- `bittensor/entrypoint-wrapper.sh` — snapshot restore + EXTRA_FLAGS, then chains to upstream `/entrypoint.sh`.
- `scripts/check_sync.sh` — sync checker (Substrate JSON-RPC). Exit codes: 0=synced, 1=syncing, 2=diverged, 3=local_rpc_error, 4=public_rpc_error, 5=config_error, 6=tool_dep_error, 7=container_error.
- `default.env` — environment template (source of truth for all variables).
- No custom Dockerfile — uses pre-built `ghcr.io/opentensor/subtensor` image directly.

## Build & Validate
```bash
pre-commit run --all-files
./ethd update --debug --non-interactive
```

## Code Style
- Shebang: `#!/usr/bin/env bash`. Strict mode: `set -Eeuo pipefail` (ethd), `set -euo pipefail` (check_sync.sh).
- Double-quoted strings (enforced by pre-commit). Shellcheck-clean.
- Private functions: double-underscore prefix (`__env_migrate`, `__docompose`).
- Environment variables: `SCREAMING_SNAKE_CASE`. No dashes in variable names.

## Critical Rules
- **ENV_VERSION migration:** When adding/renaming/removing variables in `default.env`, increment `ENV_VERSION` (currently `1`).
- **Pre-commit hooks:** Run before committing.
- **NETWORK variable:** Only sets metrics labels. Chain spec is hardcoded to finney in `bittensor.yml`.
