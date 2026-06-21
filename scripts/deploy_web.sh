#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="$HOME/climbapp-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"

# ── helpers ────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # no color
TOTAL_STEPS=7
CURRENT=0

progress() {
  CURRENT=$((CURRENT + 1))
  local BAR=""
  local WIDTH=30
  local FILL=$((CURRENT * WIDTH / TOTAL_STEPS))
  local EMPTY=$((WIDTH - FILL))
  local i
  for ((i=0; i<FILL; i++)); do BAR+="█"; done
  for ((i=0; i<EMPTY; i++)); do BAR+="░"; done
  printf "\n%b[%s/%s] %b${BAR}%b  %s%b\n" \
    "${BLUE}" "${CURRENT}" "${TOTAL_STEPS}" "${GREEN}" "${NC}" "$1" "${NC}"
}

fail() {
  printf "\n%b✗ %s%b\n" "${RED}" "$1" "${NC}"
  exit 1
}

ok() { printf "%b  ✓ %s%b\n" "${GREEN}" "$1" "${NC}"; }

# ── log to file ────────────────────────────────────────────────────────────
exec > >(tee -a "$LOG_FILE") 2>&1

clear
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}       ${YELLOW}ClimbApp Deploy${NC}                      ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}       $(date +'%Y-%m-%d %H:%M:%S')              ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── 1. Deps ────────────────────────────────────────────────────────────────
progress "Installing dependencies"
flutter pub get > /dev/null 2>&1 && ok "flutter pub get" || fail "flutter pub get failed"

# ── 2. Codegen ─────────────────────────────────────────────────────────────
progress "Generating Drift code"
dart run build_runner build > /dev/null 2>&1 && ok "build_runner" || fail "build_runner failed"

# ── 3. Build web ───────────────────────────────────────────────────────────
progress "Building web app"
MSYS_NO_PATHCONV=1 flutter build web --base-href "/potential-octo-lamp/" > /dev/null 2>&1 && ok "flutter build web" || fail "web build failed"

# ── 4. Prepare deploy branch ───────────────────────────────────────────────
progress "Preparing gh-pages branch"
TMP="$(mktemp -d)"
cp -r build/web "$TMP/web" 2>/dev/null || fail "copy build failed"
git checkout main --force > /dev/null 2>&1
git branch -D gh-pages 2>/dev/null || true
git checkout --orphan gh-pages > /dev/null 2>&1
git rm -rf --ignore-unmatch . 2>/dev/null || true
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null || true
ok "gh-pages ready"

# ── 5. Copy files ──────────────────────────────────────────────────────────
progress "Copying web assets"
cp "$TMP/web"/* . 2>/dev/null || true
cp -r "$TMP/web/assets" . 2>/dev/null || true
cp -r "$TMP/web/canvaskit" . 2>/dev/null || true
cp -r "$TMP/web/icons" . 2>/dev/null || true
cp index.html 404.html 2>/dev/null || true
rm -rf "$TMP"
ok "files copied"

# ── 6. Push ────────────────────────────────────────────────────────────────
progress "Pushing to origin"
git add . > /dev/null 2>&1
git commit -m "deploy $(date +%Y-%m-%d-%H%M)" > /dev/null 2>&1 || true
git push origin gh-pages --force > /dev/null 2>&1 && ok "pushed gh-pages" || fail "push failed"

# ── 7. Return to main ──────────────────────────────────────────────────────
progress "Switching back to main"
git checkout main --force > /dev/null 2>&1
dart run build_runner build > /dev/null 2>&1 || true
ok "on main"

# ── done ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}   ✓ Deploy complete                    ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}   https://spranavc.github.io/potential-octo-lamp/  ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "Log: ${LOG_FILE}"
