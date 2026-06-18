#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HOME/climbapp-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================="
echo "Deploy started: $(date)"
echo "Log: $LOG_FILE"
echo "========================================="

TEMP_DIR="$(mktemp -d)"

echo ""
echo "=> Running setup"
bash "$SCRIPT_DIR/setup.sh"

echo ""
echo "=> Building web"
MSYS_NO_PATHCONV=1 flutter build web --base-href "/potential-octo-lamp/"

echo ""
echo "=> Verifying base href"
grep "base href" build/web/index.html

echo ""
echo "=> Copying build to temp dir"
cp -r build/web "$TEMP_DIR/web"

echo ""
echo "=> Switching to gh-pages branch"
git checkout --orphan gh-pages 2>/dev/null || true
git checkout gh-pages 2>/dev/null || git checkout --orphan gh-pages

echo ""
echo "=> Cleaning gh-pages"
git rm -rf --ignore-unmatch . 2>/dev/null || true
rm -rf assets canvaskit icons .dart_tool build windows lib test docs 2>/dev/null || true

echo ""
echo "=> Copying web files from temp"
cp "$TEMP_DIR/web/index.html" .
cp "$TEMP_DIR/web/flutter.js" .
cp "$TEMP_DIR/web/flutter_bootstrap.js" .
cp "$TEMP_DIR/web/flutter_service_worker.js" . 2>/dev/null || true
cp "$TEMP_DIR/web/main.dart.js" .
cp "$TEMP_DIR/web/sqlite3.wasm" . 2>/dev/null || true
cp "$TEMP_DIR/web/drift_worker.dart.js" . 2>/dev/null || true
cp "$TEMP_DIR/web/manifest.json" . 2>/dev/null || true
cp "$TEMP_DIR/web/favicon.png" . 2>/dev/null || true
cp -r "$TEMP_DIR/web/assets" .
cp -r "$TEMP_DIR/web/canvaskit" .
cp -r "$TEMP_DIR/web/icons" .
cp index.html 404.html 2>/dev/null || true
rm -rf "$TEMP_DIR"

echo ""
echo "=> Committing and pushing"
git add .
git commit -m "Deploy $(date +%Y-%m-%d)" || echo "Nothing new"
git push origin gh-pages --force

echo ""
echo "=> Returning to main"
git checkout main --force

echo ""
echo "========================================="
echo "Deploy finished: $(date)"
echo "Log saved to: $LOG_FILE"
echo "Live at: https://spranavc.github.io/potential-octo-lamp/"
echo "========================================="
