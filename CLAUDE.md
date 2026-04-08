# CLAUDE.md -- Claude Code instructions

See README.md for project overview, setup, and CLI usage.

## Project Structure
- `ethd` -- main CLI wrapper. `bittensord` is a symlink to `ethd`.
- `bittensor.yml` -- Docker Compose service definition. Volume `subtensor-data` at `/data`.
- `scripts/check_sync.sh` -- compares local vs public RPC block heights (Substrate JSON-RPC). Exit codes: 0=in_sync, 1=syncing, 3=local_error, 4=public_error.
- `default.env` -- environment template (source of truth for all variables).
- No custom Dockerfile -- uses pre-built `ghcr.io/opentensor/subtensor` image directly.

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
