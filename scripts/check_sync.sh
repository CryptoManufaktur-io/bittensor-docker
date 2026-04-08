#!/usr/bin/env bash
# =============================================================================
# check_sync.sh - Bittensor Subtensor Sync Status Checker
# =============================================================================
# Substrate JSON-RPC variant: uses system_health and chain_getHeader.
#
# Exit codes:
#   0 - Node is synced
#   1 - Node is syncing (behind but catching up)
#   2 - Node is diverged (hash mismatch at same height)
#   3 - Local RPC error
#   4 - Public RPC error
#   5 - Configuration error
#   6 - Tool dependency error (curl/jq missing)
#   7 - Container error
# =============================================================================

set -euo pipefail

# =============================================================================
# USAGE
# =============================================================================

usage() {
  cat <<'USAGE'
Usage: check_sync.sh [options]

Options:
  --container NAME         Docker container name or ID to run curl/jq within
  --compose-service NAME   Docker Compose service name to resolve to a container
  --local-rpc URL          Local RPC URL (default: http://127.0.0.1:9944)
  --public-rpc URL         Public/reference RPC URL (default: https://entrypoint-finney.opentensor.ai)
  --block-lag N            Acceptable lag in blocks (default: 5)
  --no-install             Do not install curl/jq inside the container
  --env-file PATH          Path to env file to load
  -h, --help               Show this help

Exit Codes:
  0 - Synced (heights match within threshold)
  1 - Syncing (behind public RPC)
  2 - Diverged (hash mismatch)
  3 - Local RPC error
  4 - Public RPC error
  5 - Configuration error
  6 - Missing dependencies
  7 - Container error

Examples:
  ./scripts/check_sync.sh
  ./scripts/check_sync.sh --public-rpc https://entrypoint-finney.opentensor.ai
  ./scripts/check_sync.sh --compose-service subtensor
USAGE
}

# =============================================================================
# CONFIGURATION
# =============================================================================

ENV_FILE="${ENV_FILE:-}"
CONTAINER="${CONTAINER:-}"
DOCKER_SERVICE="${DOCKER_SERVICE:-}"
LOCAL_RPC="${LOCAL_RPC:-}"
PUBLIC_RPC="${PUBLIC_RPC:-}"
BLOCK_LAG_THRESHOLD="${BLOCK_LAG_THRESHOLD:-5}"
INSTALL_TOOLS="${INSTALL_TOOLS:-1}"

# =============================================================================
# HELPERS
# =============================================================================

load_env_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    line="${line#export }"
    if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      local key="${line%%=*}"
      local val="${line#*=}"
      val="${val#"${val%%[![:space:]]*}"}"
      if [[ "$val" =~ ^\".*\"$ ]]; then
        val="${val:1:-1}"
      elif [[ "$val" =~ ^\'.*\'$ ]]; then
        val="${val:1:-1}"
      fi
      export "${key}=${val}"
    fi
  done < "$file"
}

resolve_container() {
  if [[ -n "$CONTAINER" || -z "$DOCKER_SERVICE" ]]; then
    return 0
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found; cannot resolve --compose-service $DOCKER_SERVICE"
    exit 7
  fi
  if docker compose version >/dev/null 2>&1; then
    CONTAINER="$(docker compose ps -q "$DOCKER_SERVICE" | head -n 1)"
  elif command -v docker-compose >/dev/null 2>&1; then
    CONTAINER="$(docker-compose ps -q "$DOCKER_SERVICE" | head -n 1)"
  else
    echo "docker compose not available; cannot resolve --compose-service $DOCKER_SERVICE"
    exit 7
  fi
  if [[ -z "$CONTAINER" ]]; then
    echo "No running container found for service: $DOCKER_SERVICE"
    exit 7
  fi
}

http_post() {
  local url="$1"
  local data="$2"
  if [[ -n "$CONTAINER" ]]; then
    docker exec "$CONTAINER" curl -sS -X POST -H "Content-Type: application/json" -d "$data" "$url"
  else
    curl -sS -X POST -H "Content-Type: application/json" -d "$data" "$url"
  fi
}

jq_eval() {
  if [[ -n "$CONTAINER" ]]; then
    docker exec -i "$CONTAINER" jq -r "$1"
  else
    jq -r "$1"
  fi
}

install_tools_in_container() {
  if [[ -z "$CONTAINER" || "$INSTALL_TOOLS" != "1" ]]; then
    return 0
  fi
  echo "==> Ensuring curl and jq are installed inside container"
  docker exec -u root "$CONTAINER" sh -c '
    set -e
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
      exit 0
    fi
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update -y >/dev/null
      apt-get install -y curl jq ca-certificates >/dev/null
    elif command -v apk >/dev/null 2>&1; then
      apk add --no-cache curl jq ca-certificates >/dev/null
    else
      echo "Unsupported base image. No apt-get or apk found."
      exit 1
    fi
  '
}

# Convert Substrate hex block number (0x...) to decimal
hex_to_dec() {
  local hex="${1#0x}"
  printf "%d" "0x${hex}"
}

# =============================================================================
# SUBSTRATE SYNC CHECK
# =============================================================================

check_substrate_sync() {
  echo "==> Checking Substrate (Bittensor) sync status"

  # Check system_health for isSyncing flag and peer count
  local health_response
  health_response=$(http_post "$LOCAL_RPC" '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' 2>&1) || {
    echo "Failed to reach local RPC at $LOCAL_RPC"
    exit 3
  }

  local is_syncing peers
  is_syncing=$(echo "$health_response" | jq_eval '.result.isSyncing')
  peers=$(echo "$health_response" | jq_eval '.result.peers')

  if [[ -z "$is_syncing" || "$is_syncing" == "null" ]]; then
    echo "Failed to parse system_health response from local RPC"
    echo "Response: $health_response"
    exit 3
  fi

  echo "Peers:      $peers"
  echo "isSyncing:  $is_syncing"

  # Get local block height via chain_getHeader
  local local_header local_hex local_height
  local_header=$(http_post "$LOCAL_RPC" '{"jsonrpc":"2.0","method":"chain_getHeader","params":[],"id":1}' 2>&1) || {
    echo "Failed to get local block header"
    exit 3
  }

  local_hex=$(echo "$local_header" | jq_eval '.result.number')
  if [[ -z "$local_hex" || "$local_hex" == "null" ]]; then
    echo "Failed to parse local block number"
    echo "Response: $local_header"
    exit 3
  fi
  local_height=$(hex_to_dec "$local_hex")

  # Get public block height via chain_getHeader
  local public_header public_hex public_height
  public_header=$(http_post "$PUBLIC_RPC" '{"jsonrpc":"2.0","method":"chain_getHeader","params":[],"id":1}' 2>&1) || {
    echo "Failed to reach public RPC at $PUBLIC_RPC"
    exit 4
  }

  public_hex=$(echo "$public_header" | jq_eval '.result.number')
  if [[ -z "$public_hex" || "$public_hex" == "null" ]]; then
    echo "Failed to parse public block number"
    echo "Response: $public_header"
    exit 4
  fi
  public_height=$(hex_to_dec "$public_hex")

  local lag=$((public_height - local_height))

  echo "Local block:  $local_height"
  echo "Public block: $public_height"
  echo "Lag:          $lag blocks (threshold: $BLOCK_LAG_THRESHOLD)"

  if [[ "$is_syncing" == "true" ]]; then
    echo "Node is syncing (isSyncing=true, behind by $lag blocks)"
    exit 1
  fi

  if (( lag <= BLOCK_LAG_THRESHOLD && lag >= -BLOCK_LAG_THRESHOLD )); then
    echo "Node is synced"
    exit 0
  elif (( lag > BLOCK_LAG_THRESHOLD )); then
    echo "Node is syncing (behind by $lag blocks)"
    exit 1
  else
    echo "Node is ahead of public RPC (public may be lagging)"
    exit 0
  fi
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

# Pre-parse for --env-file
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  if [[ "${args[$i]}" == "--env-file" ]]; then
    ENV_FILE="${args[$((i+1))]:-}"
  fi
done

# Load env file
if [[ -n "${ENV_FILE:-}" ]]; then
  load_env_file "$ENV_FILE"
elif [[ -f ".env" ]]; then
  load_env_file ".env"
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --container) CONTAINER="$2"; shift 2 ;;
    --compose-service) DOCKER_SERVICE="$2"; shift 2 ;;
    --local-rpc) LOCAL_RPC="$2"; shift 2 ;;
    --public-rpc) PUBLIC_RPC="$2"; shift 2 ;;
    --block-lag) BLOCK_LAG_THRESHOLD="$2"; shift 2 ;;
    --no-install) INSTALL_TOOLS="0"; shift ;;
    --env-file) shift 2 ;;  # Already handled
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 5 ;;
  esac
done

# =============================================================================
# MAIN
# =============================================================================

# Set defaults
LOCAL_RPC="${LOCAL_RPC:-http://127.0.0.1:${RPC_PORT:-9944}}"
PUBLIC_RPC="${PUBLIC_RPC:-https://entrypoint-finney.opentensor.ai}"

# Resolve container from service name
resolve_container

# Check host dependencies (if not using container)
if [[ -z "$CONTAINER" ]]; then
  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo "curl and jq are required on the host when no --container is set."
    exit 6
  fi
else
  install_tools_in_container
fi

# Run sync check
check_substrate_sync
