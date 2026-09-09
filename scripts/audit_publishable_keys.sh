#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATTERN='tt_pk_(test|live)_[A-Za-z0-9_-]{16,}'
MATCHES="$(
  grep -R -I -n -E "$PATTERN" "$ROOT" \
    --exclude-dir=.git \
    --exclude-dir=.build \
    --exclude-dir=.swiftpm \
    --exclude-dir=tmp \
    --exclude='*.xcresult' || true
)"

violations=0
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  token="$(printf '%s\n' "$match" | grep -o -E "$PATTERN" | head -1)"
  suffix="${token#tt_pk_test_}"
  if [[ "$token" == tt_pk_live_* ]]; then
    suffix="${token#tt_pk_live_}"
  fi
  if [[ ! "$suffix" =~ ^[xX]+$ ]]; then
    printf 'Publishable key candidate must not be distributed: %s\n' "$match" >&2
    violations=1
  fi
done <<< "$MATCHES"

if [[ "$violations" -ne 0 ]]; then
  exit 1
fi

echo "Publishable-key audit passed."
