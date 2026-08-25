#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ $# -eq 0 ]]; then
  echo "Usage: ./update.sh x.y.z [--publish]" >&2
  echo "Core: scripts/release_core.sh x.y.z /absolute/private/AIScan [--publish]" >&2
  exit 1
fi

exec "$ROOT/scripts/release_ui.sh" "$@"
