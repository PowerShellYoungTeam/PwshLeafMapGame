# PowerShell HTTP Server for CommandRegistry Demo
# This creates a local web server to demonstrate real integration

param(
    [int]$Port = 8080
)

# Import required modules
Import-Module ".\Modules\CoreGame\EventSystem.psm1" -Force
Import-Module ".\Modules\CoreGame\CommandRegistry.psm1" -Force

# Initialize the system
Write-Host "Starting PowerShell Command Registry Demo Server..." -ForegroundColor Green
Initialize-CommandRegistry

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "Server running at http://localhost:$Port" -ForegroundColor Green
Write-Host "Available endpoints:" -ForegroundColor Cyan
Write-Host "  GET  /api/status      - Get system status" -ForegroundColor Yellow
Write-Host "  GET  /api/commands    - List all commands" -ForegroundColor Yellow
Write-Host "  POST /api/execute     - Execute a command" -ForegroundColor Yellow
Write-Host "  GET  /api/statistics  - Get system statistics" -ForegroundColor Yellow
Write-Host "  GET  /demo           - Serve the demo page" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Magenta

# Helper function to send JSON response
function Send-JsonResponse {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [object]$Data,
        [int]$StatusCode = 200
    )

    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json"
    $Response.Headers.Add("Access-Control-Allow-Origin", "*")
    $Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

    $json = $Data | ConvertTo-Json -Depth 10
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Response.ContentLength64 = $buffer.Length
    $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Response.Close()
}

# Helper function to serve HTML file
function Send-HtmlFile {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$FilePath
    )

    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Raw
        $Response.ContentType = "text/html"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
        $Response.ContentLength64 = $buffer.Length
        $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    } else {
        $Response.StatusCode = 404
        $Response.Close()
    }
    $Response.Close()
}

# Main server loop
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $method = $request.HttpMethod
        $url = $request.Url.LocalPath

        Write-Host "$(Get-Date -Format 'HH:mm:ss') $method $url" -ForegroundColor Gray

        try {
            switch -Regex ($url) {
                "^/api/status$" {
                    $status = @{
                        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        registry = @{
                            initialized = $true
                            status = "active"
                        }
                        bridge = @{
                            connected = $true
                            status = "active"
                        }
                        server = @{
                            port = $Port
                            status = "running"
                        }
                    }
                    Send-JsonResponse $response $status
                }

                "^/api/commands$" {
                    $commands = Get-GameCommand
                    $commandsList = @()

                    foreach ($cmd in $commands.Keys) {
                        $commandsList += @{
                            name = $cmd
                            description = $commands[$cmd].Description
                            module = $commands[$cmd].Module
                            parameters = $commands[$cmd].Parameters.Keys
                        }
                    }

                    Send-JsonResponse $response @{
                        commands = $commandsList
                        count = $commandsList.Count
                        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                }

                "^/api/execute$" {
                    if ($method -eq "POST") {
                        $reader = New-Object System.IO.StreamReader($request.InputStream)
                        $body = $reader.ReadToEnd()
                        $data = $body | ConvertFrom-Json

                        $result = Invoke-GameCommand -CommandName $data.command -Parameters $data.parameters

                        Send-JsonResponse $response @{
                            success = $result.Success
                            result = $result.Result
                            command = $data.command
                            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        }
                    } else {
                        Send-JsonResponse $response @{ error = "Method not allowed" } 405
                    }
                }

                "^/api/statistics$" {
                    $stats = Invoke-GameCommand -CommandName "registry.getStatistics" -Parameters @{}
                    Send-JsonResponse $response @{
                        statistics = $stats.Result
                        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                }

                "^/demo$" {
                    Send-HtmlFile $response ".\Tests\CommandRegistry-Demo.html"
                }

                "^/$" {
                    # Redirect to demo
                    $response.StatusCode = 302
                    $response.Headers.Add("Location", "/demo")
                    $response.Close()
                }

                default {
                    Send-JsonResponse $response @{ error = "Endpoint not found" } 404
                }
            }
        }
        catch {
            Write-Host "ERROR: Error processing request: $_" -ForegroundColor Red
            Send-JsonResponse $response @{ error = $_.Exception.Message } 500
        }
    }
}
catch {
    Write-Host "ERROR: Server error: $_" -ForegroundColor Red
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
        Write-Host "Server stopped" -ForegroundColor Yellow
    }
}
