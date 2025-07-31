# Start Demo Server and Open in Edge
Write-Host "🚀 Starting PowerShell CommandRegistry Demo..." -ForegroundColor Green

# Kill any existing servers on port 8081
try {
    $existingProcess = Get-NetTCPConnection -LocalPort 8081 -ErrorAction SilentlyContinue
    if ($existingProcess) {
        Write-Host "⚠️ Stopping existing process on port 8081..." -ForegroundColor Yellow
        Stop-Process -Id $existingProcess.OwningProcess -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
} catch {
    # Port is free
}

# Start the server in background
Write-Host "🌐 Starting server on port 8081..." -ForegroundColor Cyan
$serverJob = Start-Job -ScriptBlock {
    Set-Location $args[0]
    powershell -NoProfile -Command ".\Tests\Demo-Server.ps1 -Port 8081"
} -ArgumentList (Get-Location)

# Wait a moment for server to start
Start-Sleep -Seconds 3

# Open the demo in Edge
$demoUrl = "file:///$(Get-Location | ForEach-Object { $_.Path.Replace('\', '/') })/Tests/CommandRegistry-Live-Demo.html"
Write-Host "🌐 Opening demo in Microsoft Edge..." -ForegroundColor Green
Write-Host "Demo URL: $demoUrl" -ForegroundColor Cyan

try {
    Start-Process "msedge.exe" -ArgumentList $demoUrl
    Write-Host "✅ Demo opened in Edge!" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Could not open Edge automatically. Please manually open:" -ForegroundColor Yellow
    Write-Host "   $demoUrl" -ForegroundColor White
}

Write-Host ""
Write-Host "🎯 DEMO INSTRUCTIONS:" -ForegroundColor Magenta
Write-Host "1. The PowerShell server is starting in the background" -ForegroundColor White
Write-Host "2. Click 'Check Server' in the demo to connect" -ForegroundColor White
Write-Host "3. Test the live CommandRegistry integration!" -ForegroundColor White
Write-Host ""
Write-Host "📋 Server Status:" -ForegroundColor Yellow
Write-Host "   URL: http://localhost:8081" -ForegroundColor White
Write-Host "   Job ID: $($serverJob.Id)" -ForegroundColor White
Write-Host ""
Write-Host "⚠️ To stop the server later, run: Stop-Job $($serverJob.Id)" -ForegroundColor Red

# Keep the script running to show server status
Write-Host "🔄 Monitoring server startup..." -ForegroundColor Yellow
for ($i = 1; $i -le 10; $i++) {
    Start-Sleep -Seconds 1
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8081/api/status" -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Server is running! Demo is ready to use." -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "." -NoNewline -ForegroundColor Yellow
    }

    if ($i -eq 10) {
        Write-Host ""
        Write-Host "⚠️ Server may still be starting. Check the demo page." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "🎉 Demo is ready! Use the browser to test your CommandRegistry!" -ForegroundColor Green
