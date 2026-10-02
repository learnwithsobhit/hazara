#!/bin/sh
# Railway volumes are root-owned. Make HAZARA_STATE writable, then drop
# privileges when setpriv is available.
set -eu
STATE="${HAZARA_STATE:-/data}"
mkdir -p "$STATE"
if [ "$(id -u)" = "0" ]; then
  chown nobody:nogroup "$STATE" 2>/dev/null || chmod 777 "$STATE" || true
  if command -v setpriv >/dev/null 2>&1; then
    exec setpriv --reuid=nobody --regid=nogroup --init-groups -- "$@"
  fi
fi
exec "$@"
