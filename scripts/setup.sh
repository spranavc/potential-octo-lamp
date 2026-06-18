#!/usr/bin/env bash
set -euo pipefail

echo "=> Installing Flutter dependencies"
flutter pub get

echo ""
echo "=> Regenerating Drift database code"
dart run build_runner build

echo ""
echo "=> Running static analysis"
flutter analyze || true

echo ""
echo "=> Running tests"
flutter test || true

echo ""
echo "========================================="
echo "Setup complete. You can now run:"
echo "  flutter run -d windows"
echo "  flutter run -d chrome"
echo "  bash scripts/deploy_web.sh"
echo "========================================="
