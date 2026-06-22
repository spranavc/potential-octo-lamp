#!/usr/bin/env bash
set -euo pipefail

echo "=== Dev Preview  $(date) ==="

# Dev account credentials (set these in your shell profile)
DEV_EMAIL="${BDR_TEST_EMAIL:-}"
DEV_PASS="${BDR_TEST_PASS:-}"

echo "=> Building web app (release mode, base-href /)..."
if [[ -n "$DEV_EMAIL" ]] && [[ -n "$DEV_PASS" ]]; then
  echo "   Dev auto-login enabled for Playwright testing"
  MSYS_NO_PATHCONV=1 flutter build web --base-href "/" \
    --dart-define="BDR_TEST_EMAIL=$DEV_EMAIL" \
    --dart-define="BDR_TEST_PASS=$DEV_PASS"
else
  MSYS_NO_PATHCONV=1 flutter build web --base-href "/"
fi

echo ""
echo "=> Starting local server at http://localhost:8081"
echo "   Dev test URL: http://localhost:8081/#/login?bdr_test=1"
echo "   Press Ctrl+C to stop"
echo ""
# Try every Python variant on the system
for py in python3 python py; do
  if command -v "$py" &>/dev/null; then
    "$py" -m http.server 8081 -d build/web 2>/dev/null && exit 0
  fi
done
echo "Error: Could not find Python. Install Python 3 and try again."
exit 1
