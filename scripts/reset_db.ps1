# Reset the ClimbApp database — deletes the SQLite file for a fresh start.
# Usage: .\scripts\reset_db.ps1

$dbFile = "$env:USERPROFILE\Documents\climbapp.sqlite"

if (Test-Path $dbFile) {
    Remove-Item $dbFile -Force
    Write-Host "✓ Database deleted: $dbFile"
    Write-Host "  The app will create a fresh database on next launch."
} else {
    Write-Host "⚠ No database found at $dbFile (already clean)."
}
