#!/usr/bin/env bash
set -euo pipefail

echo "=> Stopping dev server..."
# Kill python HTTP server on port 8081
kill $(lsof -ti :8081) 2>/dev/null && echo "   Server stopped" || echo "   No server running on :8081"

echo "=> Cleaning build artifacts..."
rm -rf build/web 2>/dev/null && echo "   build/web removed" || echo "   No build/web to clean"

echo "=> Cleaning stale lock files..."
rm -rf .dart_tool 2>/dev/null || true

echo ""
echo "Dev environment cleaned."
