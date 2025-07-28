# PowerShell Leafmap Game - Communication Bridge Test & Demo
# Test and demonstration script for the communication bridge system

Import-Module (Join-Path $PSScriptRoot "Modules\CoreGame\StateManager.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Modules\CoreGame\CommunicationBridge.psm1") -Force

function Test-CommunicationBridge {
    Write-Host "=== PowerShell Leafmap Game - Communication Bridge Test ===" -ForegroundColor Cyan

    try {
        # Initialize State Manager first
        Write-Host "🔧 Initializing State Manager..." -ForegroundColor Yellow
        Initialize-StateManager

        # Initialize Communication Bridge
        Write-Host "🌉 Initializing Communication Bridge..." -ForegroundColor Yellow
        $bridgeConfig = @{
            HttpPort = 8080
            WebSocketPort = 8081
            DebugMode = $true
            LoggingEnabled = $true
        }
        Initialize-CommunicationBridge -Configuration $bridgeConfig

        # Start the bridge
        Write-Host "🚀 Starting Communication Bridge..." -ForegroundColor Yellow
        Start-CommunicationBridge

        # Test basic functionality
        Write-Host "🧪 Testing bridge functionality..." -ForegroundColor Yellow
        Test-BridgeFunctionality

        # Test file-based communication
        Write-Host "📁 Testing file-based communication..." -ForegroundColor Yellow
        Test-FileBasedCommunication

        # Test HTTP commands
        Write-Host "🌐 Testing HTTP commands..." -ForegroundColor Yellow
        Test-HttpCommands

        # Test event broadcasting
        Write-Host "📡 Testing event broadcasting..." -ForegroundColor Yellow
        Test-EventBroadcasting

        # Show statistics
        Write-Host "📊 Bridge Statistics:" -ForegroundColor Cyan
        $stats = Get-BridgeStatistics
        $stats | ConvertTo-Json -Depth 3 | Write-Host

        Write-Host "✅ Communication Bridge test completed successfully!" -ForegroundColor Green
        Write-Host "🔗 Bridge is running on:" -ForegroundColor Cyan
        Write-Host "   HTTP: http://localhost:8080" -ForegroundColor White
        Write-Host "   WebSocket: ws://localhost:8081/gamebridge" -ForegroundColor White
        Write-Host "   Events: http://localhost:8080/events" -ForegroundColor White
        Write-Host "" -ForegroundColor White
        Write-Host "💡 Press any key to stop the bridge..." -ForegroundColor Yellow

        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    }
    catch {
        Write-Error "Bridge test failed: $($_.Exception.Message)"
        Write-Host "Stack trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    finally {
        Write-Host "🛑 Stopping Communication Bridge..." -ForegroundColor Yellow
        Stop-CommunicationBridge
        Write-Host "✅ Bridge stopped" -ForegroundColor Green
    }
}

function Test-BridgeFunctionality {
    # Register test entities
    Register-GameEntity -EntityId "test_player_001" -EntityType "Player" -InitialState @{
        Username = "TestPlayer"
        Level = 1
        Experience = 0
        Currency = 100
        Location = "TestTown"
    }

    # Test command execution
    $result = Send-BridgeCommand -Command "GetGameState"
    Write-Host "✓ GetGameState command executed" -ForegroundColor Green

    $result = Send-BridgeCommand -Command "UpdateGameState" -Parameters @{
        EntityId = "test_player_001"
        Property = "Experience"
        Value = 250
    }
    Write-Host "✓ UpdateGameState command executed" -ForegroundColor Green

    $result = Send-BridgeCommand -Command "SaveGame" -Parameters @{
        SaveName = "bridge_test"
    }
    Write-Host "✓ SaveGame command executed" -ForegroundColor Green
}

function Test-FileBasedCommunication {
    $commandsDir = ".\Data\Bridge\Commands"
    $responsesDir = ".\Data\Bridge\Responses"

    # Create test command file
    $commandId = [System.Guid]::NewGuid().ToString()
    $commandData = @{
        Id = $commandId
        Command = "GetStatistics"
        Parameters = @{}
        Timestamp = Get-Date
    }

    $commandFile = Join-Path $commandsDir "$commandId.json"
    $commandData | ConvertTo-Json -Depth 10 | Set-Content $commandFile

    # Wait for response
    $responseFile = Join-Path $responsesDir "$commandId.json"
    $timeout = 10
    $elapsed = 0

    while (-not (Test-Path $responseFile) -and $elapsed -lt $timeout) {
        Start-Sleep -Milliseconds 100
        $elapsed += 0.1
    }

    if (Test-Path $responseFile) {
        $response = Get-Content $responseFile -Raw | ConvertFrom-Json -AsHashtable
        Remove-Item $responseFile -Force
        Write-Host "✓ File-based communication successful" -ForegroundColor Green
        Write-Host "  Response time: $($response.ExecutionTime)ms" -ForegroundColor Gray
    }
    else {
        Write-Warning "File-based communication timeout"
    }
}

function Test-HttpCommands {
    try {
        # Test HTTP status endpoint
        $statusResponse = Invoke-RestMethod -Uri "http://localhost:8080/status" -Method GET
        Write-Host "✓ HTTP status endpoint accessible" -ForegroundColor Green
        Write-Host "  Server status: $($statusResponse.Status)" -ForegroundColor Gray

        # Test HTTP command endpoint
        $commandData = @{
            Id = [System.Guid]::NewGuid().ToString()
            Command = "GetGameState"
            Parameters = @{}
            Timestamp = Get-Date
        }

        $response = Invoke-RestMethod -Uri "http://localhost:8080/command" -Method POST -Body ($commandData | ConvertTo-Json) -ContentType "application/json"
        Write-Host "✓ HTTP command execution successful" -ForegroundColor Green
        Write-Host "  Response time: $($response.ExecutionTime)ms" -ForegroundColor Gray
    }
    catch {
        Write-Warning "HTTP command test failed: $($_.Exception.Message)"
    }
}

function Test-EventBroadcasting {
    # Send test events
    Send-BridgeEvent -EventType "test.event" -EventData @{
        Message = "Test event from PowerShell"
        Timestamp = Get-Date
        TestData = @{
            Number = 42
            String = "Hello World"
            Array = @(1, 2, 3)
        }
    }

    # Trigger state events that should be broadcast
    Update-GameEntityState -EntityId "test_player_001" -Property "Level" -Value 2
    Save-GameState -SaveName "event_test"

    Write-Host "✓ Events broadcast successfully" -ForegroundColor Green
}

# Run the test
Test-CommunicationBridge
