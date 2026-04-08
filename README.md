# Bittensor Docker

This is Bittensor Docker v0.1.0

Docker deployment for a Bittensor Subtensor archive node using the official
`ghcr.io/opentensor/subtensor` image.

## Quick Start

```bash
cp default.env .env
# Edit .env if needed (defaults work for mainnet archive)
./bittensord up
```

## Prerequisites

- Docker Engine 23+ with Compose V2
- 4+ CPU cores
- 16+ GB RAM (40 GB recommended)
- 6 TB SSD/NVMe recommended (current usage ~3.3 TB, growing ~300 GB/month)
- ~3 weeks for initial archive sync

## Configuration

Key variables in `.env` (see `default.env` for full reference):

| Variable | Default | Description |
|---|---|---|
| `SUBTENSOR_DOCKER_REPO` | `ghcr.io/opentensor/subtensor` | Subtensor image repository |
| `SUBTENSOR_DOCKER_TAG` | `v3.3.13-393` | Subtensor image tag |
| `NETWORK` | `finney` | Metrics label only; chain spec is set in compose |
| `PRUNING` | `archive` | `archive` for full history, `256` for pruned |
| `RPC_PORT` | `9944` | Primary RPC port (HTTP + WebSocket) |
| `P2P_PORT` | `30333` | P2P networking port |
| `SNAPSHOT` | _(empty)_ | Snapshot URL for initial sync (`.tar.lz4`, `.tar.gz`, `.tar.zst`, `.tar`) |
| `EXTRA_FLAGS` | _(empty)_ | Additional flags for the subtensor binary |
| `LOG_LEVEL` | `info` | `info`, `debug`, `warn`, `error`, `trace` |
| `DOMAIN` | `example.com` | Domain for Traefik reverse proxy |
| `RPC_HOST` | `subtensor` | Hostname for RPC Traefik router |
| `WS_HOST` | `subtensorws` | Hostname for WebSocket Traefik router |
| `DOCKER_EXT_NETWORK` | `traefik_default` | External Docker network for Traefik |

### Compose File Overlays

```bash
# Expose RPC ports locally
COMPOSE_FILE=bittensor.yml:rpc-shared.yml

# Connect to external Traefik network
COMPOSE_FILE=bittensor.yml:ext-network.yml

# Both
COMPOSE_FILE=bittensor.yml:rpc-shared.yml:ext-network.yml
```

### Snapshot Restore

Set `SNAPSHOT` in `.env` to a URL before first start. Supported formats:
`.tar.lz4`, `.tar.gz`, `.tar.zst`, `.tar`. The snapshot is downloaded and
extracted on first run only (tracked by `/data/.initialized` sentinel).

## Commands

| Command | Description |
|---|---|
| `./bittensord up` | Start the node |
| `./bittensord down` | Stop the node |
| `./bittensord restart` | Restart the node |
| `./bittensord logs [-f]` | View logs |
| `./bittensord version` | Show client version |
| `./bittensord check-sync` | Check sync status |
| `./bittensord update` | Update images and config |
| `./bittensord space` | Show disk usage |
| `./bittensord terminate` | Stop and delete all data |

## Sync Check

```bash
./bittensord check-sync
# Uses https://entrypoint-finney.opentensor.ai as default public RPC
./bittensord check-sync --public-rpc https://other-rpc.example.com
```

## Traefik Integration

Add `:ext-network.yml` to `COMPOSE_FILE` in `.env` and configure `DOMAIN`,
`RPC_HOST`, `WS_HOST` for reverse proxy access.

## Notes

- Bittensor is a Substrate blockchain. EVM calls only work on blocks after
  the EVM pallets were activated (~Oct 2025).
- The `NETWORK` variable only sets metrics labels. The chain spec is
  hardcoded to finney (mainnet) in `bittensor.yml`. To run testnet, override
  `--chain` and `--bootnodes` via `EXTRA_FLAGS`.
- Prometheus metrics are exposed on port 9615 inside the container
  (`--prometheus-external`).

## Links

- [Bittensor Documentation](https://docs.learnbittensor.org/)
- [Subtensor GitHub Repository](https://github.com/opentensor/subtensor)
- [Bittensor Block Explorer](https://taostats.io/blocks)
