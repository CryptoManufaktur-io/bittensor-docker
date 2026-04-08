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
- 40+ GB RAM
- 6 TB SSD/NVMe (current usage ~3.3 TB, growing ~300 GB/month)
- ~3 weeks for initial archive sync

## Configuration

Key variables in `.env`:

| Variable | Default | Description |
|---|---|---|
| `SUBTENSOR_DOCKER_TAG` | `latest` | Subtensor image tag |
| `NETWORK` | `finney` | `finney` (mainnet) or `test_finney` (testnet) |
| `PRUNING` | `archive` | `archive` for full history, `256` for pruned |
| `RPC_PORT` | `9944` | Primary RPC port (HTTP + WebSocket) |
| `P2P_PORT` | `30333` | P2P networking port |
| `EXTRA_FLAGS` | _(empty)_ | Additional flags for the subtensor binary |
| `LOG_LEVEL` | `info` | `info`, `debug`, `warn`, `error`, `trace` |

### Compose File Overlays

```bash
# Expose RPC ports locally
COMPOSE_FILE=bittensor.yml:rpc-shared.yml

# Connect to external Traefik network
COMPOSE_FILE=bittensor.yml:ext-network.yml

# Both
COMPOSE_FILE=bittensor.yml:rpc-shared.yml:ext-network.yml
```

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

Bittensor is a Substrate blockchain. EVM calls only work on blocks after
the EVM pallets were activated (~Oct 2025). See the
[Substrate JSON-RPC spec](https://polkadot.js.org/docs/substrate/rpc) for
available RPC methods.

## Links

- [Bittensor Documentation](https://docs.learnbittensor.org/)
- [Subtensor GitHub Repository](https://github.com/opentensor/subtensor)
- [Bittensor Block Explorer](https://taostats.io/blocks)
