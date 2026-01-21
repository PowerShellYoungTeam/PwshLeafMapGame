# Quick setup script for PowerShell Leafmap Game
# This script will generate game data and start both servers (static + bridge)

param(
    [string]$City = "New York",
    [int]$LocationCount = 15,
    [int]$StaticPort = 8080,
    [int]$BridgePort = 8082,
    [switch]$SkipGeneration,
    [switch]$NoBrowser
)

Write-Host "🎮 PowerShell Leafmap Game - Quick Setup" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

# Check if we're in the correct directory
if (-not (Test-Path "index.html")) {
    Write-Error "Please run this script from the game root directory (where index.html is located)"
    exit 1
}

# Function to check if a port is available
function Test-PortAvailable {
    param([int]$Port)
    try {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
        $listener.Start()
        $listener.Stop()
        return $true
    } catch {
        return $false
    }
}

# Check port availability
Write-Host "`n🔍 Checking port availability..." -ForegroundColor Yellow
if (-not (Test-PortAvailable -Port $StaticPort)) {
    Write-Error "Port $StaticPort is already in use. Please specify a different port with -StaticPort"
    exit 1
}
Write-Host "  ✓ Port $StaticPort available (static server)" -ForegroundColor Green

if (-not (Test-PortAvailable -Port $BridgePort)) {
    Write-Error "Port $BridgePort is already in use. Please specify a different port with -BridgePort"
    exit 1
}
Write-Host "  ✓ Port $BridgePort available (bridge server)" -ForegroundColor Green

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
Write-Host "Static Server Port: $StaticPort" -ForegroundColor White
Write-Host "Bridge Server Port: $BridgePort" -ForegroundColor White

Write-Host "`n🚀 Starting game servers..." -ForegroundColor Yellow

# Store jobs for cleanup
$script:StaticJob = $null
$script:BridgeJob = $null

# Cleanup function
function Stop-GameServers {
    Write-Host "`n🛑 Stopping servers..." -ForegroundColor Yellow

    if ($script:StaticJob) {
        Stop-Job $script:StaticJob -ErrorAction SilentlyContinue
        Remove-Job $script:StaticJob -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Static server stopped" -ForegroundColor Green
    }

    if ($script:BridgeJob) {
        Stop-Job $script:BridgeJob -ErrorAction SilentlyContinue
        Remove-Job $script:BridgeJob -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Bridge server stopped" -ForegroundColor Green
    }
}

# Register cleanup on script exit
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Stop-GameServers }

# Start the servers
if ((Test-Path "scripts\Start-Server.ps1") -and (Test-Path "scripts\Start-BridgeServer.ps1")) {
    $projectRoot = $PWD.Path

    # Start static file server as background job
    Write-Host "  Starting static server on port $StaticPort..." -ForegroundColor Cyan
    $script:StaticJob = Start-Job -ScriptBlock {
        param($Root, $Port)
        Set-Location $Root
        & "$Root\scripts\Start-Server.ps1" -Port $Port -Path $Root
    } -ArgumentList $projectRoot, $StaticPort

    # Start bridge server as background job
    Write-Host "  Starting bridge server on port $BridgePort..." -ForegroundColor Cyan
    $script:BridgeJob = Start-Job -ScriptBlock {
        param($Root, $Port, $AllowedOrigin)
        Set-Location $Root
        & "$Root\scripts\Start-BridgeServer.ps1" -Port $Port -AllowedOrigin $AllowedOrigin
    } -ArgumentList $projectRoot, $BridgePort, "http://localhost:$StaticPort"

    # Wait a moment for servers to start
    Start-Sleep -Seconds 2

    # Check if jobs are running
    $staticRunning = (Get-Job -Id $script:StaticJob.Id).State -eq 'Running'
    $bridgeRunning = (Get-Job -Id $script:BridgeJob.Id).State -eq 'Running'

    if ($staticRunning -and $bridgeRunning) {
        Write-Host "`n✓ Both servers started successfully!" -ForegroundColor Green
        Write-Host "`n📍 Server URLs:" -ForegroundColor Yellow
        Write-Host "  Game:   http://localhost:$StaticPort" -ForegroundColor Magenta
        Write-Host "  Bridge: http://localhost:$BridgePort/status" -ForegroundColor Magenta

        # Open browser unless -NoBrowser specified
        if (-not $NoBrowser) {
            Start-Process "http://localhost:$StaticPort"
        }

        Write-Host "`nPress Ctrl+C to stop both servers." -ForegroundColor Yellow
        Write-Host "Use 'Get-Job' to check server status." -ForegroundColor Gray

        # Keep script running and monitor jobs
        try {
            while ($true) {
                Start-Sleep -Seconds 5

                # Check job states
                $staticState = (Get-Job -Id $script:StaticJob.Id -ErrorAction SilentlyContinue).State
                $bridgeState = (Get-Job -Id $script:BridgeJob.Id -ErrorAction SilentlyContinue).State

                if ($staticState -ne 'Running' -or $bridgeState -ne 'Running') {
                    Write-Host "`n⚠️  A server has stopped unexpectedly" -ForegroundColor Red
                    Write-Host "Static server: $staticState" -ForegroundColor White
                    Write-Host "Bridge server: $bridgeState" -ForegroundColor White

                    # Show any errors
                    if ($staticState -eq 'Failed') {
                        Receive-Job $script:StaticJob
                    }
                    if ($bridgeState -eq 'Failed') {
                        Receive-Job $script:BridgeJob
                    }
                    break
                }
            }
        } finally {
            Stop-GameServers
        }
    } else {
        Write-Error "Failed to start one or more servers"

        if (-not $staticRunning) {
            Write-Host "Static server output:" -ForegroundColor Red
            Receive-Job $script:StaticJob
        }
        if (-not $bridgeRunning) {
            Write-Host "Bridge server output:" -ForegroundColor Red
            Receive-Job $script:BridgeJob
        }

        Stop-GameServers
        exit 1
    }
} else {
    if (-not (Test-Path "scripts\Start-Server.ps1")) {
        Write-Error "Start-Server.ps1 not found in scripts directory"
    }
    if (-not (Test-Path "scripts\Start-BridgeServer.ps1")) {
        Write-Error "Start-BridgeServer.ps1 not found in scripts directory"
    }
    exit 1
}

Write-Host "`n👋 Thanks for playing PowerShell Leafmap Game!" -ForegroundColor Green
