# PowerShell Leafmap Game - Communication Bridge System
# Comprehensive PowerShell-JavaScript bridge for real-time game communication

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Net
using namespace System.Net.WebSockets
using namespace System.Text
using namespace System.Threading

# Import required modules
Import-Module (Join-Path $PSScriptRoot "EventSystem.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "DataModels.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "CommandRegistry.psm1") -Force

# Import enum types from CommandRegistry
Add-Type -TypeDefinition @"
public enum AccessLevel {
    Public = 0,
    Protected = 1,
    Admin = 2,
    System = 3
}
"@

# Global bridge configuration
$script:BridgeConfig = @{
    # Communication methods
    FileBasedEnabled = $true
    HttpServerEnabled = $true
    WebSocketEnabled = $true

    # File-based communication
    CommandsDirectory = ".\Data\Bridge\Commands"
    ResponsesDirectory = ".\Data\Bridge\Responses"
    EventsDirectory = ".\Data\Bridge\Events"

    # HTTP server settings
    HttpPort = 8080
    HttpHost = "localhost"
    HttpPrefix = "http://localhost:8080/"

    # WebSocket settings
    WebSocketPort = 8081
    WebSocketPath = "/gamebridge"

    # Performance settings
    CompressionEnabled = $true
    BatchingEnabled = $true
    BatchSize = 10
    BatchTimeout = 100  # milliseconds
    MaxMessageSize = 1048576  # 1MB

    # Security settings
    AuthenticationEnabled = $false
    AllowedOrigins = @("*")
    ApiKeyRequired = $false

    # Diagnostics
    LoggingEnabled = $true
    MetricsEnabled = $true
    DebugMode = $false
}

# Global bridge state
$script:BridgeState = @{
    IsInitialized = $false
    HttpListener = $null
    WebSocketServer = $null
    ActiveConnections = [ConcurrentDictionary[string, object]]::new()
    CommandQueue = [ConcurrentQueue[hashtable]]::new()
    EventQueue = [ConcurrentQueue[hashtable]]::new()
    ResponseHandlers = [ConcurrentDictionary[string, scriptblock]]::new()
    Statistics = @{
        MessagesProcessed = 0
        CommandsExecuted = 0
        EventsBroadcast = 0
        ErrorCount = 0
        BytesTransferred = 0
        ConnectionCount = 0
        AverageResponseTime = 0
        LastActivity = Get-Date
    }
}

# Message types enumeration
enum MessageType {
    Command
    Response
    Event
    Heartbeat
    Error
    Batch
}

enum CommunicationMethod {
    File
    Http
    WebSocket
}

# Core communication bridge class
class CommunicationBridge {
    [hashtable]$Configuration
    [bool]$IsRunning
    [System.Threading.CancellationTokenSource]$CancellationTokenSource
    [System.Collections.Generic.List[System.Threading.Tasks.Task]]$BackgroundTasks

    CommunicationBridge([hashtable]$Config = @{}) {
        $this.Configuration = $script:BridgeConfig.Clone()
        foreach ($key in $Config.Keys) {
            $this.Configuration[$key] = $Config[$key]
        }

        # Update HttpPrefix if HttpPort was changed
        if ($Config.HttpPort -and $Config.HttpPort -ne $script:BridgeConfig.HttpPort) {
            $this.Configuration.HttpPrefix = "http://$($this.Configuration.HttpHost):$($this.Configuration.HttpPort)/"
        }

        $this.IsRunning = $false
        $this.CancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
        $this.BackgroundTasks = [System.Collections.Generic.List[System.Threading.Tasks.Task]]::new()
        $this.InitializeDirectories()
    }

    [void] InitializeDirectories() {
        $directories = @(
            $this.Configuration.CommandsDirectory,
            $this.Configuration.ResponsesDirectory,
            $this.Configuration.EventsDirectory
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Verbose "Created bridge directory: $dir"
            }
        }
    }

    [void] Start() {
        if ($this.IsRunning) {
            Write-Warning "Communication bridge is already running"
            return
        }

        try {
            Write-Host "🌉 Starting Communication Bridge..." -ForegroundColor Cyan

            if ($this.Configuration.FileBasedEnabled) {
                $this.StartFileWatcher()
            }

            if ($this.Configuration.HttpServerEnabled) {
                $this.StartHttpServer()
            }

            if ($this.Configuration.WebSocketEnabled) {
                $this.StartWebSocketServer()
            }

            $this.StartBackgroundProcessors()
            $this.IsRunning = $true

            Write-Host "✅ Communication Bridge started successfully" -ForegroundColor Green
            $this.LogActivity("Bridge started", "Info")
        }
        catch {
            $this.LogActivity("Failed to start bridge: $($_.Exception.Message)", "Error")
            throw
        }
    }

    [void] Stop() {
        if (-not $this.IsRunning) {
            return
        }

        Write-Host "🛑 Stopping Communication Bridge..." -ForegroundColor Yellow

        $this.CancellationTokenSource.Cancel()
        $this.IsRunning = $false

        # Stop HTTP listener
        if ($script:BridgeState.HttpListener) {
            $script:BridgeState.HttpListener.Stop()
            $script:BridgeState.HttpListener.Close()
        }

        # Close WebSocket connections
        foreach ($connection in $script:BridgeState.ActiveConnections.Values) {
            if ($connection.WebSocket) {
                $connection.WebSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Server shutdown", $this.CancellationTokenSource.Token)
            }
        }

        # Wait for background tasks
        try {
            [System.Threading.Tasks.Task]::WaitAll($this.BackgroundTasks.ToArray(), 5000)
        }
        catch {
            Write-Warning "Some background tasks did not complete cleanly"
        }

        Write-Host "✅ Communication Bridge stopped" -ForegroundColor Green
        $this.LogActivity("Bridge stopped", "Info")
    }

    [void] StartFileWatcher() {
        $commandsPath = $this.Configuration.CommandsDirectory

        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $commandsPath
        $watcher.Filter = "*.json"
        $watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName
        $watcher.EnableRaisingEvents = $true

        Register-ObjectEvent -InputObject $watcher -EventName Created -Action {
            try {
                $filePath = $Event.SourceEventArgs.FullPath
                Start-Sleep -Milliseconds 50  # Allow file write to complete

                if (Test-Path $filePath) {
                    $Global:CommunicationBridge.ProcessFileCommand($filePath)
                }
            }
            catch {
                Write-Error "File watcher error: $($_.Exception.Message)"
            }
        } | Out-Null

        Write-Verbose "File watcher started for: $commandsPath"
    }

    [void] StartHttpServer() {
        # Simplified HTTP server for demo purposes
        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add($this.Configuration.HttpPrefix)
        $listener.Start()
        $script:BridgeState.HttpListener = $listener

        Write-Verbose "HTTP server started on: $($this.Configuration.HttpPrefix)"
        Write-Host "🌐 HTTP server listening on: $($this.Configuration.HttpPrefix)" -ForegroundColor Green
    }

    [void] StartWebSocketServer() {
        # WebSocket server implementation would go here
        # For now, we'll use HTTP upgrade mechanism
        Write-Verbose "WebSocket server prepared"
    }

    [void] StartBackgroundProcessors() {
        # For this demo, we'll use a simplified approach without background tasks
        # In production, you would implement proper async processing
        Write-Verbose "Background processors initialized (simplified for demo)"
    }

    [void] ProcessFileCommand([string]$FilePath) {
        try {
            $commandData = Get-Content $FilePath -Raw | ConvertFrom-Json -AsHashtable
            $this.ExecuteCommand($commandData, [CommunicationMethod]::File, $FilePath)

            # Clean up command file
            Remove-Item $FilePath -Force
        }
        catch {
            $this.LogActivity("File command processing error: $($_.Exception.Message)", "Error")
        }
    }

    [void] ProcessHttpRequest([System.Net.HttpListenerContext]$Context) {
        $request = $Context.Request
        $response = $Context.Response

        try {
            # Handle CORS
            $this.SetCorsHeaders($response)

            if ($request.HttpMethod -eq "OPTIONS") {
                $response.StatusCode = 200
                $response.Close()
                return
            }

            switch ($request.Url.AbsolutePath) {
                "/command" {
                    $this.HandleCommandRequest($Context)
                }
                "/commands" {
                    $this.HandleCommandDiscoveryRequest($Context)
                }
                "/commands/docs" {
                    $this.HandleCommandDocumentationRequest($Context)
                }
                "/events" {
                    $this.HandleEventStream($Context)
                }
                "/status" {
                    $this.HandleStatusRequest($Context)
                }
                "/websocket" {
                    $this.HandleWebSocketUpgrade($Context)
                }
                default {
                    $this.HandleNotFound($Context)
                }
            }
        }
        catch {
            $this.HandleHttpError($Context, $_.Exception)
        }
    }

    [void] SetCorsHeaders([System.Net.HttpListenerResponse]$Response) {
        $Response.Headers.Add("Access-Control-Allow-Origin", "*")
        $Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Command-Id")
    }

    [void] HandleCommandRequest([System.Net.HttpListenerContext]$Context) {
        $request = $Context.Request
        $response = $Context.Response

        if ($request.HttpMethod -ne "POST") {
            $response.StatusCode = 405
            $response.Close()
            return
        }

        # Read command data
        $reader = [System.IO.StreamReader]::new($request.InputStream)
        $commandJson = $reader.ReadToEnd()
        $reader.Close()

        $commandData = $commandJson | ConvertFrom-Json -AsHashtable
        $commandId = if ($request.Headers["X-Command-Id"]) { $request.Headers["X-Command-Id"] } else { [System.Guid]::NewGuid().ToString() }

        # Execute command asynchronously
        $result = $this.ExecuteCommand($commandData, [CommunicationMethod]::Http, $commandId)

        # Send response
        $responseJson = $result | ConvertTo-Json -Depth 10 -Compress
        $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($responseJson)

        $response.ContentType = "application/json"
        $response.ContentLength64 = $responseBytes.Length
        $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
        $response.StatusCode = 200
        $response.Close()
    }

    [void] HandleCommandDiscoveryRequest([System.Net.HttpListenerContext]$Context) {
        $request = $Context.Request
        $response = $Context.Response

        if ($request.HttpMethod -ne "GET") {
            $response.StatusCode = 405
            $response.Close()
            return
        }

        try {
            $queryParams = @{}
            if ($request.Url.Query) {
                $query = $request.Url.Query.TrimStart('?')
                foreach ($param in $query.Split('&')) {
                    $keyValue = $param.Split('=')
                    if ($keyValue.Length -eq 2) {
                        $queryParams[[System.Uri]::UnescapeDataString($keyValue[0])] = [System.Uri]::UnescapeDataString($keyValue[1])
                    }
                }
            }

            $discoveryData = @{
                RegistryAvailable = $null -ne $script:GlobalCommandRegistry
                Commands = @()
                Modules = @()
                Categories = @()
            }

            if ($script:GlobalCommandRegistry) {
                # Get available commands based on access level
                $accessLevel = "Public"
                if ($queryParams.includeProtected -eq 'true') {
                    $accessLevel = "Protected"
                }
                if ($queryParams.includeAdmin -eq 'true') {
                    $accessLevel = "Admin"
                }

                try {
                    $availableCommands = Invoke-GameCommand -CommandName "registry.listCommands" -Parameters @{
                        Module = $queryParams.module
                        IncludeProtected = ($accessLevel -eq "Protected")
                        IncludeAdmin = ($accessLevel -eq "Admin")
                    }
                    $discoveryData.Commands = $availableCommands.Data.Commands
                } catch {
                    # Fallback if registry commands not available
                    $discoveryData.Commands = $script:GlobalCommandRegistry.Commands.Keys | Sort-Object
                }

                # Get modules and categories
                $allCommands = $script:GlobalCommandRegistry.Commands.Values | Where-Object { $_.IsEnabled }
                $discoveryData.Modules = $allCommands | ForEach-Object { $_.Module } | Sort-Object -Unique
                $discoveryData.Categories = $allCommands | ForEach-Object { $_.Category } | Where-Object { $_ } | Sort-Object -Unique
            } else {
                # Fall back to legacy commands
                $discoveryData.Commands = @("GetGameState", "UpdateGameState", "SaveGame", "LoadGame", "GetStatistics", "ExecuteScript")
                $discoveryData.Modules = @("legacy")
                $discoveryData.Categories = @("Core")
            }

            $responseJson = $discoveryData | ConvertTo-Json -Depth 5 -Compress
            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($responseJson)

            $response.ContentType = "application/json"
            $response.ContentLength64 = $responseBytes.Length
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.StatusCode = 200
            $response.Close()
        }
        catch {
            $this.HandleHttpError($Context, $_.Exception)
        }
    }

    [void] HandleCommandDocumentationRequest([System.Net.HttpListenerContext]$Context) {
        $request = $Context.Request
        $response = $Context.Response

        if ($request.HttpMethod -ne "GET") {
            $response.StatusCode = 405
            $response.Close()
            return
        }

        try {
            $queryParams = @{}
            if ($request.Url.Query) {
                $query = $request.Url.Query.TrimStart('?')
                foreach ($param in $query.Split('&')) {
                    $keyValue = $param.Split('=')
                    if ($keyValue.Length -eq 2) {
                        $queryParams[[System.Uri]::UnescapeDataString($keyValue[0])] = [System.Uri]::UnescapeDataString($keyValue[1])
                    }
                }
            }

            $documentation = @{
                Generated = $false
                Message = "Command Registry not available"
                Data = @{}
            }

            if ($script:GlobalCommandRegistry) {
                if ($queryParams.command) {
                    # Get specific command documentation
                    $command = $script:GlobalCommandRegistry.GetCommand($queryParams.command)
                    if ($command) {
                        $documentation = @{
                            Generated = $true
                            Command = $command.GetDocumentation()
                        }
                    } else {
                        $response.StatusCode = 404
                        $documentation = @{
                            Generated = $false
                            Error = "Command not found: $($queryParams.command)"
                        }
                    }
                } else {
                    # Get full documentation
                    $documentation = @{
                        Generated = $true
                        Data = $script:GlobalCommandRegistry.GenerateDocumentation($queryParams.module, $queryParams.format)
                    }
                }
            }

            $responseJson = $documentation | ConvertTo-Json -Depth 10 -Compress
            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($responseJson)

            $response.ContentType = "application/json"
            $response.ContentLength64 = $responseBytes.Length
            $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
            $response.StatusCode = if ($documentation.Generated) { 200 } else { 503 }
            $response.Close()
        }
        catch {
            $this.HandleHttpError($Context, $_.Exception)
        }
    }

    [void] HandleEventStream([System.Net.HttpListenerContext]$Context) {
        $response = $Context.Response
        $response.ContentType = "text/event-stream"
        $response.Headers.Add("Cache-Control", "no-cache")
        $response.Headers.Add("Connection", "keep-alive")

        $connectionId = [System.Guid]::NewGuid().ToString()
        $script:BridgeState.ActiveConnections[$connectionId] = @{
            Type = "EventStream"
            Context = $Context
            StartTime = Get-Date
        }

        try {
            # Send initial connection event
            $this.SendServerSentEvent($response, "connected", @{ connectionId = $connectionId })

            # Keep connection alive and send events
            while ($this.IsRunning) {
                Start-Sleep -Milliseconds 100

                # Send heartbeat every 30 seconds
                if (((Get-Date) - $script:BridgeState.ActiveConnections[$connectionId].StartTime).TotalSeconds % 30 -lt 0.1) {
                    $this.SendServerSentEvent($response, "heartbeat", @{ timestamp = Get-Date })
                }
            }
        }
        finally {
            $script:BridgeState.ActiveConnections.TryRemove($connectionId, [ref]$null)
            $response.Close()
        }
    }

    [void] SendServerSentEvent([System.Net.HttpListenerResponse]$Response, [string]$EventType, [hashtable]$Data) {
        try {
            $eventData = $Data | ConvertTo-Json -Compress
            $sseMessage = "event: $EventType`ndata: $eventData`n`n"
            $sseBytes = [System.Text.Encoding]::UTF8.GetBytes($sseMessage)

            $Response.OutputStream.Write($sseBytes, 0, $sseBytes.Length)
            $Response.OutputStream.Flush()
        }
        catch {
            # Connection likely closed
        }
    }

    [void] HandleStatusRequest([System.Net.HttpListenerContext]$Context) {
        $response = $Context.Response

        $status = @{
            Status = "Running"
            Uptime = ((Get-Date) - $script:BridgeState.Statistics.LastActivity).TotalSeconds
            Statistics = $script:BridgeState.Statistics
            ActiveConnections = $script:BridgeState.ActiveConnections.Count
            Configuration = $this.Configuration
        }

        $statusJson = $status | ConvertTo-Json -Depth 5 -Compress
        $statusBytes = [System.Text.Encoding]::UTF8.GetBytes($statusJson)

        $response.ContentType = "application/json"
        $response.ContentLength64 = $statusBytes.Length
        $response.OutputStream.Write($statusBytes, 0, $statusBytes.Length)
        $response.StatusCode = 200
        $response.Close()
    }

    [void] HandleWebSocketUpgrade([System.Net.HttpListenerContext]$Context) {
        # WebSocket upgrade implementation
        Write-Verbose "WebSocket upgrade requested"

        $response = $Context.Response
        $response.StatusCode = 501
        $response.Close()
    }

    [void] HandleNotFound([System.Net.HttpListenerContext]$Context) {
        $response = $Context.Response
        $response.StatusCode = 404
        $response.Close()
    }

    [void] HandleHttpError([System.Net.HttpListenerContext]$Context, [System.Exception]$Exception) {
        $response = $Context.Response

        $errorResponse = @{
            Error = $Exception.Message
            Timestamp = Get-Date
            Path = $Context.Request.Url.AbsolutePath
        }

        $errorJson = $errorResponse | ConvertTo-Json -Compress
        $errorBytes = [System.Text.Encoding]::UTF8.GetBytes($errorJson)

        $response.ContentType = "application/json"
        $response.ContentLength64 = $errorBytes.Length
        $response.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
        $response.StatusCode = 500
        $response.Close()

        $this.LogActivity("HTTP error: $($Exception.Message)", "Error")
    }

    [hashtable] ExecuteCommand([hashtable]$CommandData, [CommunicationMethod]$Method, [string]$Context) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $result = @{
                Success = $true
                CommandId = $CommandData.Id
                Method = $Method.ToString()
                ExecutionTime = 0
                Timestamp = Get-Date
                Data = $null
                Error = $null
            }

            # Validate command structure
            if (-not $CommandData.Command) {
                throw "Missing required 'Command' field"
            }

            # Use Command Registry if available, otherwise fall back to legacy commands
            if ($script:GlobalCommandRegistry) {
                try {
                    $commandResult = Invoke-GameCommand -CommandName $CommandData.Command -Parameters $CommandData.Parameters -Context @{
                        Method = $Method.ToString()
                        ContextId = $Context
                        ClientInfo = $CommandData.ClientInfo
                    }
                    $result.Data = $commandResult.Data
                }
                catch {
                    # If command not found in registry, try legacy commands
                    if ($_.Exception.Message -like "*Command not found*") {
                        $result.Data = $this.ExecuteLegacyCommand($CommandData)
                    } else {
                        throw
                    }
                }
            } else {
                # Fall back to legacy command execution
                $result.Data = $this.ExecuteLegacyCommand($CommandData)
            }

            $stopwatch.Stop()
            $result.ExecutionTime = $stopwatch.ElapsedMilliseconds

            # Update statistics
            $script:BridgeState.Statistics.CommandsExecuted++
            $script:BridgeState.Statistics.MessagesProcessed++
            $script:BridgeState.Statistics.AverageResponseTime = (
                ($script:BridgeState.Statistics.AverageResponseTime * ($script:BridgeState.Statistics.CommandsExecuted - 1)) +
                $result.ExecutionTime
            ) / $script:BridgeState.Statistics.CommandsExecuted
            $script:BridgeState.Statistics.LastActivity = Get-Date

            # Send response based on method
            $this.SendResponse($result, $Method, $Context)

            return $result
        }
        catch {
            $stopwatch.Stop()

            $errorResult = @{
                Success = $false
                CommandId = $CommandData.Id
                Method = $Method.ToString()
                ExecutionTime = $stopwatch.ElapsedMilliseconds
                Timestamp = Get-Date
                Data = $null
                Error = $_.Exception.Message
            }

            $script:BridgeState.Statistics.ErrorCount++
            $this.LogActivity("Command execution error: $($_.Exception.Message)", "Error")

            $this.SendResponse($errorResult, $Method, $Context)
            return $errorResult
        }
    }

    [object] ExecuteLegacyCommand([hashtable]$CommandData) {
        try {
            # Execute based on command type (legacy commands for backward compatibility)
            $result = switch ($CommandData.Command) {
                "GetGameState" {
                    $this.GetGameState($CommandData.Parameters)
                }
                "UpdateGameState" {
                    $this.UpdateGameState($CommandData.Parameters)
                }
                "SaveGame" {
                    $this.SaveGame($CommandData.Parameters)
                }
                "LoadGame" {
                    $this.LoadGame($CommandData.Parameters)
                }
                "GetStatistics" {
                    $this.GetStatistics()
                }
                "ExecuteScript" {
                    $this.ExecuteScript($CommandData.Parameters)
                }
                default {
                    @{
                        Success = $false
                        Message = "Unknown command: $($CommandData.Command)"
                        Command = $CommandData.Command
                    }
                }
            }
            return $result
        }
        catch {
            return @{
                Success = $false
                Message = "Legacy command execution failed: $($_.Exception.Message)"
                Command = $CommandData.Command
            }
        }
    }

    [void] SendResponse([hashtable]$Result, [CommunicationMethod]$Method, [string]$Context) {
        switch ($Method) {
            "File" {
                $responseFile = Join-Path $this.Configuration.ResponsesDirectory "$($Result.CommandId).json"
                $Result | ConvertTo-Json -Depth 10 | Set-Content $responseFile -Encoding UTF8
            }
            "Http" {
                # Response already sent in HTTP handler
            }
            "WebSocket" {
                # WebSocket response handling
            }
        }
    }

    [hashtable] GetGameState([hashtable]$Parameters) {
        if ($Global:StateManager) {
            return $Global:StateManager.GetStateStatistics()
        }
        return @{ Message = "StateManager not initialized" }
    }

    [hashtable] UpdateGameState([hashtable]$Parameters) {
        if (-not $Global:StateManager) {
            throw "StateManager not initialized"
        }

        if ($Parameters.EntityId -and $Parameters.Property -and $null -ne $Parameters.Value) {
            return Update-GameEntityState -EntityId $Parameters.EntityId -Property $Parameters.Property -Value $Parameters.Value
        }

        throw "Missing required parameters: EntityId, Property, Value"
    }

    [hashtable] SaveGame([hashtable]$Parameters) {
        if (-not $Global:StateManager) {
            throw "StateManager not initialized"
        }

        $saveName = if ($Parameters.SaveName) { $Parameters.SaveName } else { "bridge_save_$(Get-Date -Format 'yyyyMMdd_HHmmss')" }
        return Save-GameState -SaveName $saveName -AdditionalData $Parameters.AdditionalData
    }

    [hashtable] LoadGame([hashtable]$Parameters) {
        if (-not $Global:StateManager) {
            throw "StateManager not initialized"
        }

        if (-not $Parameters.SaveName) {
            throw "Missing required parameter: SaveName"
        }

        return Load-GameState -SaveName $Parameters.SaveName
    }

    [hashtable] GetStatistics() {
        return @{
            Bridge = $script:BridgeState.Statistics
            StateManager = if ($Global:StateManager) { $Global:StateManager.GetStateStatistics() } else { @{} }
        }
    }

    [hashtable] ExecuteScript([hashtable]$Parameters) {
        if (-not $Parameters.Script) {
            throw "Missing required parameter: Script"
        }

        # Security: Only allow whitelisted scripts in production
        if (-not $this.Configuration.DebugMode) {
            throw "Script execution not allowed in production mode"
        }

        try {
            $scriptBlock = [scriptblock]::Create($Parameters.Script)
            $result = & $scriptBlock

            return @{
                Output = $result
                Success = $true
            }
        }
        catch {
            return @{
                Output = $null
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }

    [void] ProcessCommandQueue() {
        $command = $null
        if ($script:BridgeState.CommandQueue.TryDequeue([ref]$command)) {
            $this.ExecuteCommand($command.Data, $command.Method, $command.Context)
        }
    }

    [void] ProcessEventQueue() {
        $eventData = $null
        if ($script:BridgeState.EventQueue.TryDequeue([ref]$eventData)) {
            $this.BroadcastEvent($eventData)
        }
    }

    [void] BroadcastEvent([hashtable]$EventData) {
        try {
            # Broadcast to all active connections
            foreach ($connectionId in $script:BridgeState.ActiveConnections.Keys) {
                $connection = $script:BridgeState.ActiveConnections[$connectionId]

                switch ($connection.Type) {
                    "EventStream" {
                        $this.SendServerSentEvent($connection.Context.Response, $EventData.Type, $EventData.Data)
                    }
                    "WebSocket" {
                        # WebSocket broadcast implementation
                    }
                }
            }

            # File-based event broadcasting
            if ($this.Configuration.FileBasedEnabled) {
                $eventFile = Join-Path $this.Configuration.EventsDirectory "$([System.Guid]::NewGuid().ToString()).json"
                $EventData | ConvertTo-Json -Depth 10 | Set-Content $eventFile -Encoding UTF8
            }

            $script:BridgeState.Statistics.EventsBroadcast++
            $this.LogActivity("Event broadcast: $($EventData.Type)", "Info")
        }
        catch {
            $this.LogActivity("Event broadcast error: $($_.Exception.Message)", "Error")
        }
    }

    [void] LogActivity([string]$Message, [string]$Level) {
        if ($this.Configuration.LoggingEnabled) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "[$timestamp] [$Level] $Message"

            if ($this.Configuration.DebugMode) {
                Write-Host $logMessage -ForegroundColor $(
                    switch ($Level) {
                        "Error" { "Red" }
                        "Warning" { "Yellow" }
                        "Info" { "Cyan" }
                        default { "White" }
                    }
                )
            }

            # Log to file if needed
            # Add-Content -Path "bridge.log" -Value $logMessage
        }
    }
}

# Event integration with existing EventSystem
function Register-BridgeEventHandlers {
    # Listen for state events and broadcast them
    Register-GameEvent -EventType "state.*" -ScriptBlock {
        param($EventData)

        if ($Global:CommunicationBridge -and $Global:CommunicationBridge.IsRunning) {
            $bridgeEvent = @{
                Type = $EventData.EventType
                Data = $EventData.Data
                Timestamp = Get-Date
                Source = "StateManager"
            }

            $script:BridgeState.EventQueue.Enqueue($bridgeEvent)
        }
    }

    # Listen for game events
    Register-GameEvent -EventType "game.*" -ScriptBlock {
        param($EventData)

        if ($Global:CommunicationBridge -and $Global:CommunicationBridge.IsRunning) {
            $bridgeEvent = @{
                Type = $EventData.EventType
                Data = $EventData.Data
                Timestamp = Get-Date
                Source = "Game"
            }

            $script:BridgeState.EventQueue.Enqueue($bridgeEvent)
        }
    }
}

# Public API functions
function Initialize-CommunicationBridge {
    param([hashtable]$Configuration = @{})

    try {
        # Initialize Command Registry first
        if (-not $script:GlobalCommandRegistry) {
            Initialize-CommandRegistry @{
                EnableAccessControl = $true
                EnableTelemetry = $true
                EnableValidation = $true
            }
            Write-Host "Command Registry initialized for Communication Bridge" -ForegroundColor Green
        }

        $Global:CommunicationBridge = [CommunicationBridge]::new($Configuration)
        $script:BridgeState.IsInitialized = $true

        # Register event handlers
        Register-BridgeEventHandlers

        # Register legacy commands with the registry for backward compatibility
        Register-LegacyCommands

        Write-Host "Communication Bridge initialized successfully" -ForegroundColor Green

        return @{
            Success = $true
            Message = "Communication Bridge initialized"
            Configuration = $Global:CommunicationBridge.Configuration
            CommandRegistryAvailable = $null -ne $script:GlobalCommandRegistry
        }
    }
    catch {
        Write-Error "Failed to initialize Communication Bridge: $($_.Exception.Message)"
        throw
    }
}

function Register-LegacyCommands {
    if (-not $script:GlobalCommandRegistry) {
        return
    }

    # Register legacy bridge commands
    $getStateCmd = New-CommandDefinition -Name "GetGameState" -Module "bridge" -Handler {
        param($Parameters, $Context)
        if ($Global:StateManager) {
            return $Global:StateManager.GetStateStatistics()
        }
        return @{ Message = "StateManager not initialized" }
    } -Description "Get current game state" -Category "Core"
    Register-GameCommand -Command $getStateCmd

    $updateStateCmd = New-CommandDefinition -Name "UpdateGameState" -Module "bridge" -Handler {
        param($Parameters, $Context)
        if (-not $Global:StateManager) {
            throw "StateManager not initialized"
        }
        if ($Parameters.EntityId -and $Parameters.Property -and $null -ne $Parameters.Value) {
            return Update-GameEntityState -EntityId $Parameters.EntityId -Property $Parameters.Property -Value $Parameters.Value
        }
        throw "Missing required parameters: EntityId, Property, Value"
    } -Description "Update game entity state" -Category "Core"
    $updateStateCmd.AddParameter((New-CommandParameter -Name "EntityId" -Type ([ParameterType]::String) -Required $true -Description "Entity ID to update"))
    $updateStateCmd.AddParameter((New-CommandParameter -Name "Property" -Type ([ParameterType]::String) -Required $true -Description "Property to update"))
    $updateStateCmd.AddParameter((New-CommandParameter -Name "Value" -Type ([ParameterType]::Object) -Required $true -Description "New value for the property"))
    Register-GameCommand -Command $updateStateCmd

    $saveGameCmd = New-CommandDefinition -Name "SaveGame" -Module "bridge" -Handler {
        param($Parameters, $Context)
        if (-not $Global:StateManager) {
            throw "StateManager not initialized"
        }
        $saveName = if ($Parameters.SaveName) { $Parameters.SaveName } else { "bridge_save_$(Get-Date -Format 'yyyyMMdd_HHmmss')" }
        return Save-GameState -SaveName $saveName -AdditionalData $Parameters.AdditionalData
    } -Description "Save current game state" -Category "Core"
    $saveGameCmd.AddParameter((New-CommandParameter -Name "SaveName" -Type ([ParameterType]::String) -Description "Name for the save file"))
    $saveGameCmd.AddParameter((New-CommandParameter -Name "AdditionalData" -Type ([ParameterType]::Object) -Description "Additional data to include in save"))
    Register-GameCommand -Command $saveGameCmd

    $loadGameCmd = New-CommandDefinition -Name "LoadGame" -Module "bridge" -Handler {
        param($Parameters, $Context)
        if (-not $Global:StateManager) {
            throw "StateManager not initialized"
        }
        if (-not $Parameters.SaveName) {
            throw "Missing required parameter: SaveName"
        }
        return Load-GameState -SaveName $Parameters.SaveName
    } -Description "Load saved game state" -Category "Core"
    $loadGameCmd.AddParameter((New-CommandParameter -Name "SaveName" -Type ([ParameterType]::String) -Required $true -Description "Name of the save file to load"))
    Register-GameCommand -Command $loadGameCmd

    $getStatsCmd = New-CommandDefinition -Name "GetStatistics" -Module "bridge" -Handler {
        param($Parameters, $Context)
        return @{
            Bridge = $script:BridgeState.Statistics
            StateManager = if ($Global:StateManager) { $Global:StateManager.GetStateStatistics() } else { @{} }
            CommandRegistry = if ($script:GlobalCommandRegistry) { $script:GlobalCommandRegistry.GetRegistryStatistics() } else { @{} }
        }
    } -Description "Get system statistics" -Category "Diagnostics"
    Register-GameCommand -Command $getStatsCmd

    Write-Host "Legacy commands registered with Command Registry" -ForegroundColor Green
}

function Start-CommunicationBridge {
    if (-not $Global:CommunicationBridge) {
        throw "Communication Bridge not initialized. Call Initialize-CommunicationBridge first."
    }

    $Global:CommunicationBridge.Start()
}

function Stop-CommunicationBridge {
    if ($Global:CommunicationBridge) {
        $Global:CommunicationBridge.Stop()
    }
}

function Send-BridgeCommand {
    param(
        [string]$Command,
        [hashtable]$Parameters = @{},
        [string]$CommandId = $([System.Guid]::NewGuid().ToString()),
        [CommunicationMethod]$Method = [CommunicationMethod]::Http
    )

    $commandData = @{
        Id = $CommandId
        Command = $Command
        Parameters = $Parameters
        Timestamp = Get-Date
    }

    if ($Global:CommunicationBridge) {
        return $Global:CommunicationBridge.ExecuteCommand($commandData, $Method, $CommandId)
    }
    else {
        throw "Communication Bridge not initialized"
    }
}

function Send-BridgeEvent {
    param(
        [string]$EventType,
        [hashtable]$EventData = @{},
        [string]$Source = "Manual"
    )

    $bridgeEvent = @{
        Type = $EventType
        Data = $EventData
        Timestamp = Get-Date
        Source = $Source
    }

    if ($Global:CommunicationBridge -and $Global:CommunicationBridge.IsRunning) {
        $script:BridgeState.EventQueue.Enqueue($bridgeEvent)
        return @{ Success = $true; EventId = [System.Guid]::NewGuid().ToString() }
    }
    else {
        throw "Communication Bridge not running"
    }
}

function Get-BridgeStatistics {
    if ($Global:CommunicationBridge) {
        return $Global:CommunicationBridge.GetStatistics()
    }
    return @{}
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-CommunicationBridge',
    'Start-CommunicationBridge',
    'Stop-CommunicationBridge',
    'Send-BridgeCommand',
    'Send-BridgeEvent',
    'Get-BridgeStatistics'
)

# Module initialization
Write-Host "CommunicationBridge module loaded. Call Initialize-CommunicationBridge to begin." -ForegroundColor Cyan
