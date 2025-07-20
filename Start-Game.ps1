# Quick setup script for PowerShell Leafmap Game
# This script will generate game data and start the server

param(
    [string]$City = "New York",
    [int]$LocationCount = 15,
    [int]$Port = 8080,
    [switch]$SkipGeneration
)

Write-Host "🎮 PowerShell Leafmap Game - Quick Setup" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

# Check if we're in the correct directory
if (-not (Test-Path "index.html")) {
    Write-Error "Please run this script from the game root directory (where index.html is located)"
    exit 1
}

# Create directories if they don't exist
$directories = @("css", "js", "scripts")
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "✓ Created directory: $dir" -ForegroundColor Cyan
    }
}

# Generate game data unless skipped
if (-not $SkipGeneration) {
    Write-Host "`n📍 Generating game data..." -ForegroundColor Yellow

    if (Test-Path "scripts\Generate-GameData.ps1") {
        try {
            $dataFile = & ".\scripts\Generate-GameData.ps1" -LocationCount $LocationCount -City $City
            Write-Host "✓ Game data generated: $dataFile" -ForegroundColor Green
        } catch {
            Write-Warning "Could not generate game data: $($_.Exception.Message)"
            Write-Host "You can generate it manually later with:" -ForegroundColor Yellow
            Write-Host "  .\scripts\Generate-GameData.ps1 -LocationCount $LocationCount -City '$City'" -ForegroundColor Gray
        }
    } else {
        Write-Warning "Generate-GameData.ps1 not found in scripts directory"
    }
} else {
    Write-Host "⏭️  Skipping game data generation" -ForegroundColor Yellow
}

# Check for existing game data
if (Test-Path "gamedata.json") {
    Write-Host "✓ Game data file found: gamedata.json" -ForegroundColor Green
} else {
    Write-Warning "No game data file found. The game will use demo data."
}

# Display game information
Write-Host "`n🎯 Game Setup Complete!" -ForegroundColor Green
Write-Host "=======================" -ForegroundColor Green
Write-Host "City: $City" -ForegroundColor White
Write-Host "Locations: $LocationCount" -ForegroundColor White
Write-Host "Server Port: $Port" -ForegroundColor White

Write-Host "`n🚀 Starting the game server..." -ForegroundColor Yellow

# Start the server
if (Test-Path "scripts\Start-Server.ps1") {
    Write-Host "Server will open in your default browser..." -ForegroundColor Cyan
    Write-Host "Game URL: http://localhost:$Port" -ForegroundColor Magenta
    Write-Host "`nPress Ctrl+C to stop the server when you're done playing." -ForegroundColor Yellow
    Write-Host "`n" -ForegroundColor White

    # Start the server with browser opening
    & ".\scripts\Start-Server.ps1" -Port $Port -OpenBrowser
} else {
    Write-Error "Start-Server.ps1 not found in scripts directory"
    Write-Host "You can start the server manually with:" -ForegroundColor Yellow
    Write-Host "  .\scripts\Start-Server.ps1 -Port $Port -OpenBrowser" -ForegroundColor Gray
}

Write-Host "`n👋 Thanks for playing PowerShell Leafmap Game!" -ForegroundColor Green
