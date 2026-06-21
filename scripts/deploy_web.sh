#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.0.1}"
LOG_DIR="$HOME/climbapp-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Deploy v$VERSION  $(date) ==="

echo "=> Build"
dart run build_runner build
MSYS_NO_PATHCONV=1 flutter build web --base-href "/potential-octo-lamp/"

# Copy build to temp so it survives branch switch
TMP=$(mktemp -d)
cp -r build/web "$TMP/web"

echo "=> Push to gh-pages"
git checkout main --force
git branch -D gh-pages 2>/dev/null || true
git checkout --orphan gh-pages
git rm -rf --ignore-unmatch . 2>/dev/null || true
rm -rf assets canvaskit icons .dart_tool build windows lib test scripts docs 2>/dev/null || true

for f in index.html flutter.js flutter_bootstrap.js flutter_service_worker.js \
         main.dart.js sqlite3.wasm drift_worker.dart.js manifest.json favicon.png; do
  cp "$TMP/web/$f" . 2>/dev/null || true
done
cp -r "$TMP/web/assets" "$TMP/web/canvaskit" "$TMP/web/icons" . 2>/dev/null || true
cp index.html 404.html 2>/dev/null || true
rm -rf "$TMP"

git add .
git commit -m "v$VERSION ($(date +%Y-%m-%d))" || true
git push origin gh-pages --force

echo "=> Back to main"
git checkout main --force
dart run build_runner build 2>/dev/null || true

echo "=== Done. https://spranavc.github.io/potential-octo-lamp/ ==="
