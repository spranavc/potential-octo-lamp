#!/usr/bin/env bash
set -euo pipefail

echo "=== Dev Preview  $(date) ==="

echo "=> Building web app (release mode, base-href /)..."
MSYS_NO_PATHCONV=1 flutter build web --base-href "/"

echo ""
echo "=> Starting local server at http://localhost:8081"
echo "   Press Ctrl+C to stop"
echo ""
python3 -m http.server 8081 -d build/web 2>/dev/null ||
python -m http.server 8081 -d build/web 2>/dev/null ||
py -m http.server 8081 -d build/web 2>/dev/null
