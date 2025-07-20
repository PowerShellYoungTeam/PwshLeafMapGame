# Simple launcher to start the game from anywhere
# This script automatically changes to the correct directory and starts the server

param(
    [int]$Port = 8080,
    [switch]$OpenBrowser = $true
)

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Change to the game directory
Write-Host "🎮 Starting PowerShell Leafmap Game..." -ForegroundColor Green
Write-Host "Game directory: $scriptDir" -ForegroundColor Cyan

# Verify the game files exist
if (-not (Test-Path (Join-Path $scriptDir "index.html"))) {
    Write-Error "Game files not found in $scriptDir"
    Write-Host "Expected to find index.html in the game directory." -ForegroundColor Red
    exit 1
}

# Change to the game directory
Set-Location $scriptDir

Write-Host "✓ Changed to game directory" -ForegroundColor Green

# Check if game data exists, generate if needed
if (-not (Test-Path "gamedata.json")) {
    Write-Host "📍 No game data found, generating..." -ForegroundColor Yellow
    if (Test-Path "scripts\Generate-GameData.ps1") {
        try {
            & ".\scripts\Generate-GameData.ps1" -LocationCount 15 -City "New York"
            Write-Host "✓ Game data generated" -ForegroundColor Green
        } catch {
            Write-Warning "Could not generate game data automatically: $($_.Exception.Message)"
        }
    }
}

# Start the server
Write-Host "🚀 Starting server on port $Port..." -ForegroundColor Yellow

if (Test-Path "scripts\Start-Server.ps1") {
    if ($OpenBrowser) {
        & ".\scripts\Start-Server.ps1" -Port $Port -OpenBrowser
    } else {
        & ".\scripts\Start-Server.ps1" -Port $Port
    }
} else {
    Write-Error "Start-Server.ps1 not found in scripts directory"
}
