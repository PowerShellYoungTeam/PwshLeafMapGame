# Simple HTTP server script to serve the web application
# This allows you to run the game locally without needing Node.js

param(
    [int]$Port = 8080,
    [string]$Path = "",
    [switch]$OpenBrowser
)

# Determine the correct path to serve files from
if ([string]::IsNullOrEmpty($Path)) {
    # If no path specified, determine based on script location
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (Test-Path (Join-Path $scriptDir "..\index.html")) {
        # Script is in a subdirectory (like 'scripts'), go up one level
        $Path = Split-Path -Parent $scriptDir
    } elseif (Test-Path (Join-Path $scriptDir "index.html")) {
        # Script is in the game directory
        $Path = $scriptDir
    } else {
        # Default to current directory
        $Path = Get-Location
    }
}

# Ensure we have an absolute path
$Path = Resolve-Path $Path

Write-Host "Starting PowerShell HTTP Server..." -ForegroundColor Green
Write-Host "Port: $Port" -ForegroundColor Cyan
Write-Host "Serving from: $Path" -ForegroundColor Cyan

# Verify that index.html exists in the target directory
if (-not (Test-Path (Join-Path $Path "index.html"))) {
    Write-Error "index.html not found in $Path. Please specify the correct path with -Path parameter."
    exit 1
}

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")

try {
    $listener.Start()
    Write-Host "Server started successfully!" -ForegroundColor Green
    Write-Host "Access your game at: http://localhost:$Port" -ForegroundColor Yellow

    if ($OpenBrowser) {
        Start-Process "http://localhost:$Port"
    }

    Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Magenta

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        # Get the requested file path
        $requestedPath = $request.Url.LocalPath
        if ($requestedPath -eq "/") {
            $requestedPath = "/index.html"
        }

        $filePath = Join-Path $Path $requestedPath.TrimStart('/')

        Write-Host "$(Get-Date -Format 'HH:mm:ss') - $($request.HttpMethod) $requestedPath" -ForegroundColor Gray

        if (Test-Path $filePath -PathType Leaf) {
            # Determine content type
            $contentType = switch ([System.IO.Path]::GetExtension($filePath).ToLower()) {
                ".html" { "text/html" }
                ".css" { "text/css" }
                ".js" { "application/javascript" }
                ".json" { "application/json" }
                ".png" { "image/png" }
                ".jpg" { "image/jpeg" }
                ".jpeg" { "image/jpeg" }
                ".gif" { "image/gif" }
                ".ico" { "image/x-icon" }
                default { "text/plain" }
            }

            # Read and serve the file
            $content = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentType = $contentType
            $response.ContentLength64 = $content.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($content, 0, $content.Length)
        } else {
            # File not found
            $response.StatusCode = 404
            $errorContent = [System.Text.Encoding]::UTF8.GetBytes("404 - File Not Found: $requestedPath")
            $response.ContentLength64 = $errorContent.Length
            $response.OutputStream.Write($errorContent, 0, $errorContent.Length)
            Write-Host "  -> 404 Not Found" -ForegroundColor Red
        }

        $response.Close()
    }
} catch {
    Write-Error "Server error: $($_.Exception.Message)"
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    Write-Host "Server stopped." -ForegroundColor Yellow
}
