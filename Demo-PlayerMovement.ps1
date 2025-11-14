# Demo-PlayerMovement.ps1
# Demo script for testing player movement with pathfinding

# Import required modules
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $PSScriptRoot 'Modules\CoreGame'

Import-Module (Join-Path $ModulesPath 'GameLogging.psm1') -Force
Import-Module (Join-Path $ModulesPath 'EventSystem.psm1') -Force
Import-Module (Join-Path $ModulesPath 'StateManager.psm1') -Force
Import-Module (Join-Path $ModulesPath 'DataModels.psm1') -Force
Import-Module (Join-Path $ModulesPath 'PathfindingSystem.psm1') -Force
Import-Module (Join-Path $ModulesPath 'CommunicationBridge.psm1') -Force

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        Player Movement & Pathfinding Demo            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Initialize systems
Write-Host "Initializing game systems..." -ForegroundColor Yellow
Initialize-GameLogging
Initialize-EventSystem
Initialize-StateManager
Initialize-PathfindingSystem
Initialize-CommunicationBridge

# Create player entity
Write-Host "Creating player entity..." -ForegroundColor Yellow
$player = New-PlayerEntity -Name "TestPlayer"
$player.SetProperty('Position', @{ Lat = 40.7128; Lng = -74.0060 }) # NYC
Set-GameEntity -Entity $player

Write-Host "✓ Player created at position: [$($player.Position.Lat), $($player.Position.Lng)]" -ForegroundColor Green
Write-Host ""

# Register event handlers
Write-Host "Setting up event handlers..." -ForegroundColor Yellow

Register-GameEvent -EventType 'movement.started' -ScriptBlock {
    param($Data)
    Write-Host "`n[MOVEMENT] Player started moving to [$($Data.Destination.Lat), $($Data.Destination.Lng)]" -ForegroundColor Cyan
    Write-Host "           Travel mode: $($Data.TravelMode)" -ForegroundColor Gray
    Write-Host "           Pathfinding: $($Data.PathfindingType)" -ForegroundColor Gray
    Write-Host "           Distance: $([Math]::Round($Data.Distance, 2))m" -ForegroundColor Gray
}

Register-GameEvent -EventType 'unit.positionUpdated' -ScriptBlock {
    param($Data)
    Write-Host "[UPDATE] Position updated: [$($Data.NewPosition.Lat), $($Data.NewPosition.Lng)]" -ForegroundColor DarkCyan
}

Register-GameEvent -EventType 'movement.completed' -ScriptBlock {
    param($Data)
    Write-Host "[ARRIVAL] Player arrived at [$($Data.Position.Lat), $($Data.Position.Lng)]" -ForegroundColor Green
    Write-Host ""
}

Register-GameEvent -EventType 'location.entered' -ScriptBlock {
    param($Data)
    Write-Host "[LOCATION] Player entered: $($Data.LocationName)" -ForegroundColor Magenta
}

Register-GameEvent -EventType 'encounter.random' -ScriptBlock {
    param($Data)
    Write-Host "[ENCOUNTER] Random encounter: $($Data.EncounterType)!" -ForegroundColor Yellow
}

Write-Host "✓ Event handlers registered" -ForegroundColor Green
Write-Host ""

# Start local server
Write-Host "Starting local web server on http://localhost:8080..." -ForegroundColor Yellow
Write-Host "Opening player-movement-demo.html..." -ForegroundColor Yellow
Write-Host ""

# Start simple HTTP server
$ServerJob = Start-Job -ScriptBlock {
    param($RootPath)

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:8080/")
    $listener.Start()

    Write-Host "Server started on http://localhost:8080" -ForegroundColor Green

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.LocalPath
        if ($path -eq '/') { $path = '/player-movement-demo.html' }

        $filePath = Join-Path $RootPath $path.TrimStart('/')

        if (Test-Path $filePath) {
            $content = [System.IO.File]::ReadAllBytes($filePath)

            # Set content type
            $ext = [System.IO.Path]::GetExtension($filePath)
            $contentType = switch ($ext) {
                '.html' { 'text/html' }
                '.js' { 'application/javascript' }
                '.css' { 'text/css' }
                '.json' { 'application/json' }
                default { 'application/octet-stream' }
            }

            $response.ContentType = $contentType
            $response.StatusCode = 200
            $response.OutputStream.Write($content, 0, $content.Length)
        }
        else {
            $response.StatusCode = 404
            $errorMsg = [System.Text.Encoding]::UTF8.GetBytes("404 - File not found: $path")
            $response.OutputStream.Write($errorMsg, 0, $errorMsg.Length)
        }

        $response.Close()
    }

    $listener.Stop()
} -ArgumentList $PSScriptRoot

# Wait for server to start
Start-Sleep -Seconds 2

# Open browser
Start-Process "http://localhost:8080/player-movement-demo.html"

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                Demo is now running!                   ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "  1. Click anywhere on the map to move the player" -ForegroundColor White
Write-Host "  2. Select different travel modes (foot, car, etc.)" -ForegroundColor White
Write-Host "  3. Watch the path calculation and animation" -ForegroundColor White
Write-Host "  4. Check this console for event logs" -ForegroundColor White
Write-Host ""
Write-Host "Active Systems:" -ForegroundColor Yellow
Write-Host "  ✓ PathfindingSystem - Handles movement logic" -ForegroundColor Green
Write-Host "  ✓ EventSystem - Broadcasts movement events" -ForegroundColor Green
Write-Host "  ✓ StateManager - Tracks player position" -ForegroundColor Green
Write-Host "  ✓ CommunicationBridge - Frontend ↔ Backend sync" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop the demo..." -ForegroundColor Cyan
Write-Host ""

# Keep script running and process commands from frontend
try {
    while ($true) {
        # Process bridge commands
        $commands = Receive-BridgeCommands

        foreach ($cmd in $commands) {
            switch ($cmd.Type) {
                'StartMovement' {
                    Start-UnitMovement -UnitId $player.Id -Destination $cmd.Destination -TravelMode $cmd.TravelMode
                }
                'StopMovement' {
                    Stop-UnitMovement -UnitId $player.Id
                }
                'UpdatePosition' {
                    Update-UnitPosition -UnitId $player.Id -Position $cmd.Position
                }
                'CompleteMovement' {
                    Complete-UnitMovement -UnitId $player.Id -FinalPosition $cmd.FinalPosition
                }
            }
        }

        # Process game events
        $events = Get-GameEvent
        foreach ($event in $events) {
            # Events are already handled by registered handlers
        }

        # Small delay to prevent CPU spinning
        Start-Sleep -Milliseconds 100
    }
}
finally {
    # Cleanup
    Write-Host "`nShutting down..." -ForegroundColor Yellow

    if ($ServerJob) {
        Stop-Job $ServerJob
        Remove-Job $ServerJob
    }

    Write-Host "✓ Demo stopped" -ForegroundColor Green
}
