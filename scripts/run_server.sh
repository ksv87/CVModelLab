#!/usr/bin/env bash
# Run the CV Model Lab server (Linux/macOS).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/../server" && pwd)"

CONFIG="${1:-$SERVER_DIR/server.yaml}"

cd "$SERVER_DIR"
exec uv run python -m cvmlab_server.main --config "$CONFIG" "${@:2}"
