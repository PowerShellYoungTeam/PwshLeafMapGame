# Demo-PlayerMovement.ps1
# Demo script for testing player movement with pathfinding

# Import the CoreGame module using the manifest (which handles all nested modules)
$script:PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$CoreGamePath = Join-Path $script:PSScriptRoot 'Modules\CoreGame'

$ErrorActionPreference = 'Stop'
try {
    Write-Host "Loading CoreGame module..." -ForegroundColor Yellow
    
    # Import CoreGame.psd1 - this loads all nested modules in the correct order
    Import-Module (Join-Path $CoreGamePath "CoreGame.psd1") -Force -Global -ErrorAction Stop
    
    Write-Host "  ✓ CoreGame module loaded (all subsystems included)" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "ERROR: Failed to load CoreGame module - $_" -ForegroundColor Red
    Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.InvocationInfo) {
        Write-Host "At: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    }
    exit 1
}

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        Player Movement & Pathfinding Demo            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Initialize systems
Write-Host "Initializing game systems..." -ForegroundColor Yellow
try {
    Initialize-GameLogging
    Write-Host "  ✓ GameLogging initialized" -ForegroundColor Green
    
    Initialize-EventSystem
    Write-Host "  ✓ EventSystem initialized" -ForegroundColor Green
    
    Initialize-StateManager | Out-Null
    Write-Host "  ✓ StateManager initialized" -ForegroundColor Green
    
    Initialize-PathfindingSystem
    Write-Host "  ✓ PathfindingSystem initialized" -ForegroundColor Green
    
    Initialize-CommunicationBridge
    Write-Host "  ✓ CommunicationBridge initialized" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "`nERROR: Failed to initialize systems - $_" -ForegroundColor Red
    Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create player entity
Write-Host "Creating player entity..." -ForegroundColor Yellow
try {
    $player = New-PlayerEntity -Name "TestPlayer"
    $player.SetProperty('Position', @{ Lat = 40.7128; Lng = -74.0060 }) # NYC
    
    # Register the player entity with StateManager
    Register-GameEntity -EntityId $player.Id -EntityType 'Player' -InitialState @{
        Name     = $player.Name
        Position = $player.Position
    }
    
    Write-Host "✓ Player created at position: [$($player.Position.Lat), $($player.Position.Lng)]" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "ERROR: Failed to create player - $_" -ForegroundColor Red
    Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Register event handlers
Write-Host "Setting up event handlers..." -ForegroundColor Yellow
try {
    Register-GameEvent -EventType 'movement.started' -ScriptBlock {
        param($Data)
        Write-Host "`n[MOVEMENT] Player started moving to [$($Data.Destination.Lat), $($Data.Destination.Lng)]" -ForegroundColor Cyan
        Write-Host "           Travel mode: $($Data.TravelMode)" -ForegroundColor Gray
        Write-Host "           Pathfinding: $($Data.PathfindingType)" -ForegroundColor Gray
        Write-Host "           Distance: $([Math]::Round($Data.Distance, 2))m" -ForegroundColor Gray
    } | Out-Null

    Register-GameEvent -EventType 'unit.positionUpdated' -ScriptBlock {
        param($Data)
        Write-Host "[UPDATE] Position updated: [$($Data.NewPosition.Lat), $($Data.NewPosition.Lng)]" -ForegroundColor DarkCyan
    } | Out-Null

    Register-GameEvent -EventType 'movement.completed' -ScriptBlock {
        param($Data)
        Write-Host "[ARRIVAL] Player arrived at [$($Data.Position.Lat), $($Data.Position.Lng)]" -ForegroundColor Green
        Write-Host ""
    } | Out-Null

    Register-GameEvent -EventType 'location.entered' -ScriptBlock {
        param($Data)
        Write-Host "[LOCATION] Player entered: $($Data.LocationName)" -ForegroundColor Magenta
    } | Out-Null

    Register-GameEvent -EventType 'encounter.random' -ScriptBlock {
        param($Data)
        Write-Host "[ENCOUNTER] Random encounter: $($Data.EncounterType)!" -ForegroundColor Yellow
    } | Out-Null

    Write-Host "✓ Event handlers registered" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "ERROR: Failed to register event handlers - $_" -ForegroundColor Red
    Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

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
            try {
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
            catch {
                Write-Host "Error processing command: $_" -ForegroundColor Red
            }
        }

        # Process game events
        try {
            $events = Get-GameEvent
            foreach ($event in $events) {
                # Events are already handled by registered handlers
            }
        }
        catch {
            # Silently continue if event processing fails
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
