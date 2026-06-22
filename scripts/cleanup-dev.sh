#!/usr/bin/env bash
set -euo pipefail

echo "=> Stopping dev server..."
# Kill any Python HTTP server on port 8081
if command -v lsof &>/dev/null; then
  kill $(lsof -ti :8081) 2>/dev/null && echo "   Server stopped" || echo "   No server running on :8081"
elif command -v netstat &>/dev/null; then
  PID=$(netstat -ano 2>/dev/null | grep ':8081' | grep LISTENING | awk '{print $5}' | head -1)
  if [[ -n "$PID" ]]; then
    kill "$PID" 2>/dev/null && echo "   Server stopped" || true
  else
    echo "   No server running on :8081"
  fi
else
  # Windows fallback: just try taskkill
  for pid in $(ps aux 2>/dev/null | grep 'http.server 8081' | grep -v grep | awk '{print $1}'); do
    kill "$pid" 2>/dev/null || true
  done
  echo "   Server (if any) requested to stop"
fi

echo "=> Cleaning build artifacts..."
rm -rf build/web 2>/dev/null && echo "   build/web removed" || echo "   No build/web to clean"

echo "=> Cleaning stale lock files..."
rm -rf .dart_tool 2>/dev/null || true

echo ""
echo "Dev environment cleaned."
