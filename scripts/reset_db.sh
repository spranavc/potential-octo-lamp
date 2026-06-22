#!/usr/bin/env bash
# Reset the Bolder database — deletes the SQLite file for a fresh start.
# Usage: bash scripts/reset_db.sh
set -euo pipefail

DB_FILE="$HOME/Documents/bolder.sqlite"

if [ -f "$DB_FILE" ]; then
  rm "$DB_FILE"
  echo "✓ Database deleted: $DB_FILE"
  echo "  The app will create a fresh database on next launch."
else
  echo "⚠ No database found at $DB_FILE (already clean)."
fi
