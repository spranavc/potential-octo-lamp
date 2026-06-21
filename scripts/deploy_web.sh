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

# ---- semantic version (bump manually when you want) -------------
VERSION="${1:-0.0.1}"
# -----------------------------------------------------------------

TEMP_DIR="$(mktemp -d)"
DEPLOY_BRANCH="gh-pages"

echo "=> Version: $VERSION"
echo "=> Deploy branch: $DEPLOY_BRANCH"
echo ""

echo "=> Stashing any uncommitted work"
git stash --include-untracked 2>/dev/null || true

echo "=> Running setup"
bash "$SCRIPT_DIR/setup.sh"

echo "=> Building web"
MSYS_NO_PATHCONV=1 flutter build web --base-href "/potential-octo-lamp/"

echo "=> Verifying base href"
grep 'base href' build/web/index.html || echo "WARNING: no base href found"

# ---- save build output outside the repo so it survives branch switches
echo "=> Copying build to temp dir"
cp -r build/web "$TEMP_DIR/web"

# ---- create fresh deploy branch (delete old one if exists) -------
echo "=> Creating fresh $DEPLOY_BRANCH"
git checkout main --force
git branch -D "$DEPLOY_BRANCH" 2>/dev/null || true
git checkout --orphan "$DEPLOY_BRANCH"

echo "=> Cleaning $DEPLOY_BRANCH"
git rm -rf --ignore-unmatch . 2>/dev/null || true
rm -rf assets canvaskit icons .dart_tool build windows lib test scripts docs 2>/dev/null || true

echo "=> Copying web files"
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

echo "=> Committing and pushing $DEPLOY_BRANCH"
git add .
git commit -m "Deploy v${VERSION} ($(date +%Y-%m-%d))" || echo "Nothing new"
git push origin "$DEPLOY_BRANCH" --force

# ---- back to main -----------------------------------------------
echo "=> Returning to main"
git checkout main --force

# ---- restore stashed work ---------------------------------------
git stash pop 2>/dev/null || true

# ---- regenerate generated files that --force wiped --------------
echo "=> Regenerating Drift code on main"
dart run build_runner build 2>/dev/null || true

echo ""
echo "========================================="
echo "Deploy finished: $(date)"
echo "Version:    $VERSION"
echo "Branch:     $DEPLOY_BRANCH"
echo "Live at:    https://spranavc.github.io/potential-octo-lamp/"
echo "Log:        $LOG_FILE"
echo "========================================="
