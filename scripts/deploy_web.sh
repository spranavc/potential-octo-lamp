#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="$HOME/climbapp-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Deploy  $(date) ==="

echo "=> Build"
flutter pub get
dart run build_runner build
MSYS_NO_PATHCONV=1 flutter build web --base-href "/potential-octo-lamp/"

# Copy to temp so the output survives the branch switch to gh-pages
TMP="$(mktemp -d)"
cp -r build/web "$TMP/web"

echo "=> Push to gh-pages"
git checkout main --force
git branch -D gh-pages 2>/dev/null || true
git checkout --orphan gh-pages
git rm -rf --ignore-unmatch . 2>/dev/null || true
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null || true

cp "$TMP/web"/* . 2>/dev/null || true
cp -r "$TMP/web/assets" . 2>/dev/null || true
cp -r "$TMP/web/canvaskit" . 2>/dev/null || true
cp -r "$TMP/web/icons" . 2>/dev/null || true
cp index.html 404.html 2>/dev/null || true
rm -rf "$TMP"

git add .
git commit -m "deploy $(date +%Y-%m-%d-%H%M)" || true
git push origin gh-pages --force

echo "=> Back to main"
git checkout main --force
dart run build_runner build 2>/dev/null || true

echo "=== Done. https://spranavc.github.io/potential-octo-lamp/ ==="
