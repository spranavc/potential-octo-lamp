#!/usr/bin/env bash
set -euo pipefail

# Parse optional -cm "commit message" argument (used for both main and gh-pages)
DEPLOY_MSG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -cm) DEPLOY_MSG="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; echo "Usage: bash deploy.sh [-cm \"message\"]"; exit 1 ;;
  esac
done

LOG_DIR="$HOME/climbapp-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Deploy  $(date) ==="

# Clean up stale lock files that cause checkout warnings
echo "=> Cleaning stale files"
rm -rf .dart_tool 2>/dev/null || true

# Commit any uncommitted changes on main before deploying
if ! git diff --quiet || ! git diff --cached --quiet; then
  if [[ -z "$DEPLOY_MSG" ]]; then
    echo "ERROR: Uncommitted changes but no -cm message provided."
    echo "Run: bash scripts/deploy.sh -cm \"your commit message\""
    exit 1
  fi
  echo "=> Committing pending changes"
  git add -A
  git commit -m "$DEPLOY_MSG" || true
  git push origin main || echo "warning: push to main failed, continuing"
fi

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
git commit -m "${DEPLOY_MSG:-deploy $(date +%Y-%m-%d-%H%M)}" || true
git push origin gh-pages --force

echo "=> Back to main"
git checkout main --force
dart run build_runner build 2>/dev/null || true

echo "=== Done. https://spranavc.github.io/potential-octo-lamp/ ==="
