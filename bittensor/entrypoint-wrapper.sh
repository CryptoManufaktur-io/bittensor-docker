#!/bin/sh
set -e

DATA_DIR="${DATA_DIR:-/data}"

if [ ! -f "${DATA_DIR}/.initialized" ]; then
  if [ -n "${SNAPSHOT:-}" ]; then
    echo "entrypoint-wrapper: downloading snapshot from ${SNAPSHOT}"
    # Detect archive format and extract accordingly
    case "${SNAPSHOT}" in
      *.tar.lz4)
        curl -o - -L "${SNAPSHOT}" | lz4 -c -d - | tar -x -C "${DATA_DIR}"
        ;;
      *.tar.gz|*.tgz)
        curl -o - -L "${SNAPSHOT}" | tar -xz -C "${DATA_DIR}"
        ;;
      *.tar.zst|*.tar.zstd)
        curl -o - -L "${SNAPSHOT}" | zstd -d | tar -x -C "${DATA_DIR}"
        ;;
      *.tar)
        curl -o - -L "${SNAPSHOT}" | tar -x -C "${DATA_DIR}"
        ;;
      *)
        echo "entrypoint-wrapper: unknown snapshot format, attempting tar.gz"
        curl -o - -L "${SNAPSHOT}" | tar -xz -C "${DATA_DIR}"
        ;;
    esac
    echo "entrypoint-wrapper: snapshot restore complete"
  fi
  touch "${DATA_DIR}/.initialized"
fi

# Append EXTRA_FLAGS if set (word-splitting intentional)
# shellcheck disable=SC2086
exec /entrypoint.sh "$@" ${EXTRA_FLAGS:-}
