#!/usr/bin/env bash
set -euo pipefail

echo "=== Dev Preview  $(date) ==="

echo "=> Building web app (release mode, base-href /)..."
MSYS_NO_PATHCONV=1 flutter build web --base-href "/"

echo ""
echo "=> Starting local server at http://localhost:8081"
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
