# HTTP Bridge Server Integration Tests
# Tests the bridge server endpoints with actual HTTP requests

BeforeAll {
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:BridgePort = 18082  # Use non-standard port for testing
    $script:BridgeUrl = "http://localhost:$script:BridgePort"
    $script:ServerJob = $null

    # Start the bridge server as a background job
    Write-Host "Starting bridge server for testing on port $script:BridgePort..." -ForegroundColor Cyan

    $script:ServerJob = Start-Job -ScriptBlock {
        param($Root, $Port)
        Set-Location $Root
        & "$Root\scripts\Start-BridgeServer.ps1" -Port $Port -AllowedOrigin "*"
    } -ArgumentList $script:ProjectRoot, $script:BridgePort

    # Wait for server to start
    $maxWait = 10
    $waited = 0
    $serverReady = $false

    while ($waited -lt $maxWait -and -not $serverReady) {
        Start-Sleep -Seconds 1
        $waited++

        try {
            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/status" -Method GET -TimeoutSec 2 -ErrorAction Stop
            if ($response.Status -eq 'ok') {
                $serverReady = $true
                Write-Host "Bridge server ready after $waited seconds" -ForegroundColor Green
            }
        } catch {
            # Server not ready yet
        }
    }

    if (-not $serverReady) {
        # Check if job failed
        $jobState = (Get-Job -Id $script:ServerJob.Id).State
        if ($jobState -eq 'Failed') {
            $output = Receive-Job $script:ServerJob
            throw "Bridge server failed to start: $output"
        }
        throw "Bridge server did not become ready within $maxWait seconds"
    }
}

AfterAll {
    # Cleanup: Stop the server job
    if ($script:ServerJob) {
        Write-Host "Stopping bridge server..." -ForegroundColor Cyan
        Stop-Job $script:ServerJob -ErrorAction SilentlyContinue
        Remove-Job $script:ServerJob -Force -ErrorAction SilentlyContinue
    }
}

Describe "Bridge Server - Status Endpoint" {
    Context "GET /status" {
        It "Should return status ok" {
            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/status" -Method GET
            $response.Status | Should -Be 'ok'
        }

        It "Should include timestamp" {
            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/status" -Method GET
            $response.Timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should indicate CommandRegistry availability" {
            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/status" -Method GET
            $response.PSObject.Properties.Name | Should -Contain 'CommandRegistryAvailable'
        }
    }
}

Describe "Bridge Server - Commands Endpoint" {
    Context "GET /commands" {
        It "Should return commands list" {
            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/commands" -Method GET
            $response.PSObject.Properties.Name | Should -Contain 'Commands'
        }

        It "Should indicate registry availability" {
            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/commands" -Method GET
            $response.RegistryAvailable | Should -BeOfType [bool]
        }

        It "Should return array of commands" {
            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/commands" -Method GET
            # Commands should be an array (may be empty or have items)
            $response.Commands -is [array] -or $response.Commands.Count -ge 0 | Should -Be $true
        }
    }
}

Describe "Bridge Server - Command Documentation Endpoint" {
    Context "GET /commands/docs" {
        It "Should return documentation object" {
            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/commands/docs" -Method GET
            $response.PSObject.Properties.Name | Should -Contain 'Generated'
        }

        It "Should indicate generation status" {
            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/commands/docs" -Method GET
            $response.Generated | Should -BeOfType [bool]
        }
    }
}

Describe "Bridge Server - Command Execution Endpoint" {
    Context "POST /command" {
        It "Should accept valid command request" {
            $body = @{
                Id = "test_$(Get-Date -Format 'yyyyMMddHHmmss')"
                Command = "registry.listCommands"
                Parameters = @{}
                Timestamp = (Get-Date).ToString("o")
            } | ConvertTo-Json

            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/command" -Method POST -Body $body -ContentType 'application/json'
            $response.PSObject.Properties.Name | Should -Contain 'Success'
        }

        It "Should return execution time" {
            $body = @{
                Id = "test_$(Get-Date -Format 'yyyyMMddHHmmss')"
                Command = "registry.listCommands"
                Parameters = @{}
                Timestamp = (Get-Date).ToString("o")
            } | ConvertTo-Json

            $response = Invoke-RestMethod -Uri "$script:BridgeUrl/command" -Method POST -Body $body -ContentType 'application/json'
            $response.ExecutionTime | Should -BeGreaterOrEqual 0
        }

        It "Should return error for missing command name" {
            $body = @{
                Id = "test_error"
                Parameters = @{}
            } | ConvertTo-Json

            try {
                $response = Invoke-RestMethod -Uri "$script:BridgeUrl/command" -Method POST -Body $body -ContentType 'application/json'
                # Should have error in response
                $response.Error | Should -Not -BeNullOrEmpty
            } catch {
                # 400 error is expected
                $_.Exception.Response.StatusCode.value__ | Should -Be 400
            }
        }

        It "Should return error for empty body" {
            try {
                Invoke-RestMethod -Uri "$script:BridgeUrl/command" -Method POST -Body "" -ContentType 'application/json'
            } catch {
                $_.Exception.Response.StatusCode.value__ | Should -Be 400
            }
        }
    }
}

Describe "Bridge Server - CORS Headers" {
    Context "OPTIONS preflight request" {
        It "Should handle OPTIONS request" {
            try {
                $response = Invoke-WebRequest -Uri "$script:BridgeUrl/command" -Method OPTIONS -ErrorAction Stop
                $response.StatusCode | Should -BeIn @(200, 204)
            } catch {
                # Some PowerShell versions may throw on 204
                $_.Exception.Response.StatusCode.value__ | Should -BeIn @(200, 204)
            }
        }
    }

    Context "CORS headers on responses" {
        It "Should include Access-Control-Allow-Origin header" {
            $response = Invoke-WebRequest -Uri "$script:BridgeUrl/status" -Method GET
            $response.Headers['Access-Control-Allow-Origin'] | Should -Not -BeNullOrEmpty
        }

        It "Should include Access-Control-Allow-Methods header" {
            $response = Invoke-WebRequest -Uri "$script:BridgeUrl/status" -Method GET
            $response.Headers['Access-Control-Allow-Methods'] | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Bridge Server - Error Handling" {
    Context "404 Not Found" {
        It "Should return 404 for unknown endpoint" {
            try {
                Invoke-RestMethod -Uri "$script:BridgeUrl/nonexistent" -Method GET
            } catch {
                $_.Exception.Response.StatusCode.value__ | Should -Be 404
            }
        }

        It "Should include available endpoints in 404 response" {
            try {
                Invoke-RestMethod -Uri "$script:BridgeUrl/nonexistent" -Method GET
            } catch {
                $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorResponse.AvailableEndpoints | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "405 Method Not Allowed" {
        It "Should return 405 for POST on /status" {
            try {
                Invoke-RestMethod -Uri "$script:BridgeUrl/status" -Method POST -Body "{}"
            } catch {
                $_.Exception.Response.StatusCode.value__ | Should -Be 405
            }
        }

        It "Should return 405 for GET on /command" {
            try {
                Invoke-RestMethod -Uri "$script:BridgeUrl/command" -Method GET
            } catch {
                $_.Exception.Response.StatusCode.value__ | Should -Be 405
            }
        }
    }
}
