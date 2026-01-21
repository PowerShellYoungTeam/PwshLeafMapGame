# PowerShell HTTP Bridge Server for JS/PowerShell Communication
# Provides REST API endpoints for the game frontend to execute commands

param(
    [int]$Port = 8082,
    [string]$AllowedOrigin = "http://localhost:8080",
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Get script directory and project root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Import the CoreGame module
$coreGamePath = Join-Path $projectRoot "Modules\CoreGame\CoreGame.psd1"
if (Test-Path $coreGamePath) {
    Import-Module $coreGamePath -Force -DisableNameChecking
    Write-Host "✓ CoreGame module loaded" -ForegroundColor Green
} else {
    Write-Error "CoreGame module not found at: $coreGamePath"
    exit 1
}

# Initialize the game engine (includes CommandRegistry)
try {
    $engineResult = Initialize-GameEngine
    Write-Host "✓ Game engine initialized" -ForegroundColor Green
} catch {
    Write-Warning "Could not fully initialize game engine: $($_.Exception.Message)"
}

# Get the command registry instance
$script:Registry = $null
if (Get-Command Get-GameCommand -ErrorAction SilentlyContinue) {
    Write-Host "✓ CommandRegistry available" -ForegroundColor Green
} else {
    Write-Warning "CommandRegistry commands not available"
}

# Helper function to add CORS headers
function Add-CorsHeaders {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$Origin
    )

    $Response.Headers.Add("Access-Control-Allow-Origin", $Origin)
    $Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, X-Command-Id")
    $Response.Headers.Add("Access-Control-Max-Age", "86400")
}

# Helper function to send JSON response
function Send-JsonResponse {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [object]$Data,
        [int]$StatusCode = 200
    )

    $json = $Data | ConvertTo-Json -Depth 10 -Compress
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)

    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json; charset=utf-8"
    $Response.ContentLength64 = $buffer.Length
    $Response.OutputStream.Write($buffer, 0, $buffer.Length)
}

# Helper function to read request body
function Read-RequestBody {
    param(
        [System.Net.HttpListenerRequest]$Request
    )

    if ($Request.HasEntityBody) {
        $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
        $body = $reader.ReadToEnd()
        $reader.Close()
        return $body
    }
    return $null
}

# Handle GET /status
function Handle-Status {
    param([System.Net.HttpListenerResponse]$Response)

    $status = @{
        Status = "ok"
        Timestamp = (Get-Date).ToString("o")
        Version = "1.0.0"
        Port = $Port
        CommandRegistryAvailable = (Get-Command Get-GameCommand -ErrorAction SilentlyContinue) -ne $null
    }

    Send-JsonResponse -Response $Response -Data $status
}

# Handle GET /commands
function Handle-GetCommands {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [System.Collections.Specialized.NameValueCollection]$QueryParams
    )

    $result = @{
        RegistryAvailable = $false
        Commands = [System.Collections.ArrayList]@()
        Modules = [System.Collections.ArrayList]@()
        Categories = [System.Collections.ArrayList]@()
        Error = $null
    }

    try {
        if (Get-Command Get-GameCommand -ErrorAction SilentlyContinue) {
            $result.RegistryAvailable = $true

            # Get all commands
            $commands = @(Get-GameCommand)

            if ($commands -and $commands.Count -gt 0) {
                foreach ($cmd in $commands) {
                    $name = if ($cmd -is [hashtable]) { $cmd.Name }
                            elseif ($cmd.Name) { $cmd.Name }
                            else { $cmd.ToString() }
                    if ($name) { [void]$result.Commands.Add($name) }

                    if ($cmd.Module -and -not $result.Modules.Contains($cmd.Module)) {
                        [void]$result.Modules.Add($cmd.Module)
                    }
                    if ($cmd.Category -and -not $result.Categories.Contains($cmd.Category)) {
                        [void]$result.Categories.Add($cmd.Category)
                    }
                }
            }
        }
    } catch {
        $result.Error = $_.Exception.Message
    }

    Send-JsonResponse -Response $Response -Data $result
}

# Handle GET /commands/docs
function Handle-GetCommandDocs {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [System.Collections.Specialized.NameValueCollection]$QueryParams
    )

    $commandName = $QueryParams["command"]
    $moduleName = $QueryParams["module"]

    $result = @{
        Generated = $false
        Command = $null
        Data = $null
        Error = $null
    }

    try {
        if (Get-Command Get-GameCommand -ErrorAction SilentlyContinue) {
            if ($commandName) {
                # Get specific command documentation
                $command = Get-GameCommand -Name $commandName -ErrorAction SilentlyContinue
                if ($command) {
                    $result.Generated = $true
                    # Convert to simple hashtable for JSON serialization
                    $result.Command = @{
                        Name = $command.Name
                        Description = $command.Description
                        Module = $command.Module
                        Category = $command.Category
                    }
                }
            } else {
                # Get all command documentation
                $commands = @(Get-GameCommand -ErrorAction SilentlyContinue)
                $result.Generated = $true
                $result.Data = @{
                    Commands = @($commands | ForEach-Object {
                        @{
                            Name = $_.Name
                            Description = $_.Description
                            Module = $_.Module
                            Category = $_.Category
                        }
                    })
                    GeneratedAt = (Get-Date).ToString("o")
                    Count = $commands.Count
                }
            }
        }
    } catch {
        $result.Error = $_.Exception.Message
    }

    Send-JsonResponse -Response $Response -Data $result
}

# Handle POST /command
function Handle-ExecuteCommand {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$RequestBody
    )

    $result = @{
        Success = $false
        Data = $null
        Error = $null
        ExecutionTime = 0
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        if ([string]::IsNullOrEmpty($RequestBody)) {
            $result.Error = "Request body is empty"
            Send-JsonResponse -Response $Response -Data $result -StatusCode 400
            return
        }

        $commandData = $RequestBody | ConvertFrom-Json

        if (-not $commandData.Command) {
            $result.Error = "Command name is required"
            Send-JsonResponse -Response $Response -Data $result -StatusCode 400
            return
        }

        $commandName = $commandData.Command
        $parameters = @{}

        # Convert parameters from PSCustomObject to hashtable
        if ($commandData.Parameters) {
            $commandData.Parameters.PSObject.Properties | ForEach-Object {
                $parameters[$_.Name] = $_.Value
            }
        }

        Write-Host "Executing command: $commandName" -ForegroundColor Cyan

        # Try to invoke the command
        if (Get-Command Invoke-GameCommand -ErrorAction SilentlyContinue) {
            $cmdResult = Invoke-GameCommand -CommandName $commandName -Parameters $parameters

            if ($cmdResult) {
                $result.Success = $cmdResult.Success -eq $true
                $result.Data = $cmdResult.Data
                if ($cmdResult.Error) {
                    $result.Error = $cmdResult.Error
                }
            } else {
                $result.Success = $true
                $result.Data = @{ Message = "Command executed" }
            }
        } else {
            $result.Error = "Command registry not available"
        }

    } catch {
        $result.Error = $_.Exception.Message
        Write-Host "Command error: $($_.Exception.Message)" -ForegroundColor Red
    }

    $stopwatch.Stop()
    $result.ExecutionTime = $stopwatch.ElapsedMilliseconds

    $statusCode = if ($result.Success) { 200 } else { 400 }
    Send-JsonResponse -Response $Response -Data $result -StatusCode $statusCode
}

# Main server loop
Write-Host "`n🌉 Starting PowerShell Bridge Server..." -ForegroundColor Green
Write-Host "Port: $Port" -ForegroundColor Cyan
Write-Host "Allowed Origin: $AllowedOrigin" -ForegroundColor Cyan

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")

try {
    $listener.Start()
    Write-Host "✓ Bridge server started successfully!" -ForegroundColor Green
    Write-Host "API Endpoints:" -ForegroundColor Yellow
    Write-Host "  GET  http://localhost:$Port/status" -ForegroundColor White
    Write-Host "  GET  http://localhost:$Port/commands" -ForegroundColor White
    Write-Host "  GET  http://localhost:$Port/commands/docs" -ForegroundColor White
    Write-Host "  POST http://localhost:$Port/command" -ForegroundColor White
    Write-Host "`nPress Ctrl+C to stop the server" -ForegroundColor Magenta

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        # Add CORS headers to all responses
        Add-CorsHeaders -Response $response -Origin $AllowedOrigin

        $method = $request.HttpMethod
        $path = $request.Url.LocalPath
        $queryParams = $request.QueryString

        if ($Verbose) {
            Write-Host "$(Get-Date -Format 'HH:mm:ss') - $method $path" -ForegroundColor Gray
        }

        try {
            # Handle OPTIONS (CORS preflight)
            if ($method -eq "OPTIONS") {
                $response.StatusCode = 204
                $response.Close()
                continue
            }

            # Route requests
            switch -Regex ($path) {
                "^/status$" {
                    if ($method -eq "GET") {
                        Handle-Status -Response $response
                    } else {
                        $response.StatusCode = 405
                    }
                }
                "^/commands/docs$" {
                    if ($method -eq "GET") {
                        Handle-GetCommandDocs -Response $response -QueryParams $queryParams
                    } else {
                        $response.StatusCode = 405
                    }
                }
                "^/commands$" {
                    if ($method -eq "GET") {
                        Handle-GetCommands -Response $response -QueryParams $queryParams
                    } else {
                        $response.StatusCode = 405
                    }
                }
                "^/command$" {
                    if ($method -eq "POST") {
                        $body = Read-RequestBody -Request $request
                        Handle-ExecuteCommand -Response $response -RequestBody $body
                    } else {
                        $response.StatusCode = 405
                    }
                }
                default {
                    # 404 Not Found
                    $notFound = @{
                        Error = "Endpoint not found"
                        Path = $path
                        AvailableEndpoints = @("/status", "/commands", "/commands/docs", "/command")
                    }
                    Send-JsonResponse -Response $response -Data $notFound -StatusCode 404
                }
            }
        } catch {
            Write-Host "Request error: $($_.Exception.Message)" -ForegroundColor Red
            $errorResponse = @{
                Error = $_.Exception.Message
            }
            Send-JsonResponse -Response $response -Data $errorResponse -StatusCode 500
        }

        $response.Close()
    }
} catch {
    Write-Error "Server error: $($_.Exception.Message)"
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    Write-Host "`nBridge server stopped." -ForegroundColor Yellow
}
