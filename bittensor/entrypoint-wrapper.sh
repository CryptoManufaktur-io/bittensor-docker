#!/bin/sh
set -e

DATA_DIR="${DATA_DIR:-/data}"

if [ ! -f "${DATA_DIR}/.initialized" ]; then
  if [ -n "${SNAPSHOT:-}" ]; then
    echo "entrypoint-wrapper: downloading snapshot from ${SNAPSHOT}"
    # Detect archive format and extract accordingly
    case "${SNAPSHOT}" in
      *.tar.lz4)
        if ! command -v lz4 >/dev/null 2>&1; then
          echo "entrypoint-wrapper: lz4 not found, cannot extract snapshot"; exit 1
        fi
        curl --fail -o - -L "${SNAPSHOT}" | lz4 -c -d - | tar -x -C "${DATA_DIR}"
        ;;
      *.tar.gz|*.tgz)
        curl --fail -o - -L "${SNAPSHOT}" | tar -xz -C "${DATA_DIR}"
        ;;
      *.tar.zst|*.tar.zstd)
        if ! command -v zstd >/dev/null 2>&1; then
          echo "entrypoint-wrapper: zstd not found, cannot extract snapshot"; exit 1
        fi
        curl --fail -o - -L "${SNAPSHOT}" | zstd -d | tar -x -C "${DATA_DIR}"
        ;;
      *.tar)
        curl --fail -o - -L "${SNAPSHOT}" | tar -x -C "${DATA_DIR}"
        ;;
      *)
        echo "entrypoint-wrapper: unknown snapshot format, attempting tar.gz"
        curl --fail -o - -L "${SNAPSHOT}" | tar -xz -C "${DATA_DIR}"
        ;;
    esac
    echo "entrypoint-wrapper: snapshot restore complete"
  fi
  touch "${DATA_DIR}/.initialized"
fi

# Append EXTRA_FLAGS if set (word-splitting intentional)
# shellcheck disable=SC2086
exec /entrypoint.sh "$@" ${EXTRA_FLAGS:-}
