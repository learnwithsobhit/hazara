#!/usr/bin/env bash
# Production Flutter web build + cache-bust stamp.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_BASE="${API_BASE:-}"
PUBLIC_WEB_ORIGIN="${PUBLIC_WEB_ORIGIN:-https://hazara-lws-260731.web.app}"
PUBLIC_WEB_ORIGIN="${PUBLIC_WEB_ORIGIN%/}"
APP_VERSION="$(sed -n 's/^version:[[:space:]]*\([^+]*\).*/\1/p' pubspec.yaml | head -1)"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_ID="${BUILD_ID:-$(date -u +%Y%m%d%H%M%S)}"
if command -v git >/dev/null 2>&1 && git rev-parse --short HEAD >/dev/null 2>&1; then
  BUILD_ID="${BUILD_ID}-$(git rev-parse --short HEAD)"
fi

if [[ -z "$API_BASE" ]]; then
  echo "API_BASE is required (Railway HTTPS origin, no trailing slash)" >&2
  exit 1
fi

echo "Building web APP_VERSION=$APP_VERSION APP_BUILD_ID=$BUILD_ID API_BASE=$API_BASE PUBLIC_WEB_ORIGIN=$PUBLIC_WEB_ORIGIN"
flutter build web --release --pwa-strategy=none --no-web-resources-cdn \
  --dart-define=API_BASE="$API_BASE" \
  --dart-define=PUBLIC_WEB_ORIGIN="$PUBLIC_WEB_ORIGIN" \
  --dart-define=APP_VERSION="$APP_VERSION" \
  --dart-define=APP_BUILD_ID="$BUILD_ID"

chmod +x "$ROOT/tool/stamp_web_build.sh"
PUBLIC_WEB_ORIGIN="$PUBLIC_WEB_ORIGIN" "$ROOT/tool/stamp_web_build.sh" "$BUILD_ID" "$APP_VERSION"
