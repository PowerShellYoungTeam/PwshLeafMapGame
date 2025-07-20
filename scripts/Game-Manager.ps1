# PowerShell script to manage game state and interact with the web app
# This script demonstrates how PowerShell can be used to manage game logic

param(
    [string]$Action = "status",
    [string]$DataFile = "gamedata.json",
    [string]$PlayerName = "Player1"
)

# Function to read game data
function Get-GameData {
    param([string]$FilePath)

    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Raw | ConvertFrom-Json
        return $content
    } else {
        Write-Warning "Game data file not found: $FilePath"
        return $null
    }
}

# Function to save player progress
function Save-PlayerProgress {
    param(
        [string]$PlayerName,
        [hashtable]$Progress
    )

    $progressFile = "progress_$PlayerName.json"
    $Progress | ConvertTo-Json -Depth 5 | Out-File -FilePath $progressFile
    Write-Host "Player progress saved to: $progressFile" -ForegroundColor Green
}

# Function to load player progress
function Get-PlayerProgress {
    param([string]$PlayerName)

    $progressFile = "progress_$PlayerName.json"
    if (Test-Path $progressFile) {
        return Get-Content $progressFile -Raw | ConvertFrom-Json
    } else {
        # Return new player data
        return @{
            playerName = $PlayerName
            score = 0
            visitedLocations = @()
            inventory = @()
            achievements = @()
            startTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        }
    }
}

# Function to analyze game statistics
function Get-GameStatistics {
    param([object]$GameData)

    if (-not $GameData) {
        Write-Warning "No game data available for analysis"
        return
    }

    $stats = @{
        TotalLocations = $GameData.locations.Count
        LocationTypes = $GameData.locations | Group-Object type | ForEach-Object { @{ Type = $_.Name; Count = $_.Count } }
        TotalPoints = ($GameData.locations | Measure-Object points -Sum).Sum
        AveragePoints = [math]::Round(($GameData.locations | Measure-Object points -Average).Average, 2)
        ItemDistribution = $GameData.locations | ForEach-Object { $_.items } | Group-Object | ForEach-Object { @{ Item = $_.Name; Count = $_.Count } }
    }

    return $stats
}

# Function to find locations near coordinates
function Find-NearbyLocations {
    param(
        [object]$GameData,
        [double]$Latitude,
        [double]$Longitude,
        [double]$RadiusKm = 5
    )

    $nearbyLocations = @()

    foreach ($location in $GameData.locations) {
        $distance = Get-DistanceKm -Lat1 $Latitude -Lng1 $Longitude -Lat2 $location.lat -Lng2 $location.lng

        if ($distance -le $RadiusKm) {
            $nearbyLocations += [PSCustomObject]@{
                Location = $location
                Distance = [math]::Round($distance, 2)
            }
        }
    }

    return $nearbyLocations | Sort-Object Distance
}

# Function to calculate distance between two points
function Get-DistanceKm {
    param(
        [double]$Lat1,
        [double]$Lng1,
        [double]$Lat2,
        [double]$Lng2
    )

    $R = 6371 # Earth's radius in kilometers
    $dLat = [math]::PI * ($Lat2 - $Lat1) / 180
    $dLng = [math]::PI * ($Lng2 - $Lng1) / 180

    $a = [math]::Sin($dLat/2) * [math]::Sin($dLat/2) +
         [math]::Cos([math]::PI * $Lat1 / 180) * [math]::Cos([math]::PI * $Lat2 / 180) *
         [math]::Sin($dLng/2) * [math]::Sin($dLng/2)

    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1-$a))
    $distance = $R * $c

    return $distance
}

# Function to export data for web app
function Export-ForWebApp {
    param(
        [object]$GameData,
        [object]$PlayerProgress
    )

    $webData = @{
        gameData = $GameData
        playerProgress = $PlayerProgress
        exportTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        instructions = @{
            usage = "This data can be imported into the web application"
            command = "GameUtils.updateGameFromPowerShell(jsonData)"
        }
    }

    $webOutput = "web_export.json"
    $webData | ConvertTo-Json -Depth 10 | Out-File -FilePath $webOutput
    Write-Host "Web app export saved to: $webOutput" -ForegroundColor Cyan

    return $webOutput
}

# Main script logic
Write-Host "PowerShell Game Manager - Action: $Action" -ForegroundColor Yellow

switch ($Action.ToLower()) {
    "status" {
        Write-Host "`n=== Game Status ===" -ForegroundColor Green
        $gameData = Get-GameData -FilePath $DataFile
        if ($gameData) {
            $stats = Get-GameStatistics -GameData $gameData
            Write-Host "Game Version: $($gameData.version)" -ForegroundColor White
            Write-Host "Generated: $($gameData.generatedAt)" -ForegroundColor White
            Write-Host "City: $($gameData.city)" -ForegroundColor White
            Write-Host "Total Locations: $($stats.TotalLocations)" -ForegroundColor Cyan
            Write-Host "Total Points Available: $($stats.TotalPoints)" -ForegroundColor Cyan
            Write-Host "Average Points per Location: $($stats.AveragePoints)" -ForegroundColor Cyan

            Write-Host "`nLocation Types:" -ForegroundColor Magenta
            $stats.LocationTypes | ForEach-Object {
                Write-Host "  $($_.Type): $($_.Count)" -ForegroundColor White
            }
        }

        $playerProgress = Get-PlayerProgress -PlayerName $PlayerName
        Write-Host "`n=== Player Progress ===" -ForegroundColor Green
        Write-Host "Player: $($playerProgress.playerName)" -ForegroundColor White
        Write-Host "Score: $($playerProgress.score)" -ForegroundColor White
        Write-Host "Locations Visited: $($playerProgress.visitedLocations.Count)" -ForegroundColor White
        Write-Host "Items in Inventory: $($playerProgress.inventory.Count)" -ForegroundColor White
    }

    "generate" {
        Write-Host "Generating new game data..." -ForegroundColor Green
        $outputFile = & ".\Generate-GameData.ps1" -LocationCount 15 -City "New York"
        Write-Host "Game data generated: $outputFile" -ForegroundColor Cyan
    }

    "export" {
        Write-Host "Exporting data for web application..." -ForegroundColor Green
        $gameData = Get-GameData -FilePath $DataFile
        $playerProgress = Get-PlayerProgress -PlayerName $PlayerName

        if ($gameData) {
            $exportFile = Export-ForWebApp -GameData $gameData -PlayerProgress $playerProgress
            Write-Host "Export completed: $exportFile" -ForegroundColor Cyan
            Write-Host "Copy the contents of this file and use GameUtils.updateGameFromPowerShell() in the browser console" -ForegroundColor Yellow
        }
    }

    "nearby" {
        # Example: Find locations near Times Square
        $timesSquareLat = 40.7580
        $timesSquareLng = -73.9855

        Write-Host "Finding locations near Times Square..." -ForegroundColor Green
        $gameData = Get-GameData -FilePath $DataFile

        if ($gameData) {
            $nearby = Find-NearbyLocations -GameData $gameData -Latitude $timesSquareLat -Longitude $timesSquareLng -RadiusKm 10

            Write-Host "`nLocations within 10km of Times Square:" -ForegroundColor Cyan
            $nearby | ForEach-Object {
                Write-Host "  $($_.Location.name) - $($_.Distance)km - Type: $($_.Location.type)" -ForegroundColor White
            }
        }
    }

    "help" {
        Write-Host "`n=== PowerShell Game Manager Help ===" -ForegroundColor Yellow
        Write-Host "Available actions:" -ForegroundColor White
        Write-Host "  status   - Show game and player status" -ForegroundColor Cyan
        Write-Host "  generate - Generate new game data" -ForegroundColor Cyan
        Write-Host "  export   - Export data for web app" -ForegroundColor Cyan
        Write-Host "  nearby   - Find nearby locations" -ForegroundColor Cyan
        Write-Host "  help     - Show this help message" -ForegroundColor Cyan
        Write-Host "`nUsage examples:" -ForegroundColor White
        Write-Host "  .\Game-Manager.ps1 -Action status -PlayerName 'YourName'" -ForegroundColor Gray
        Write-Host "  .\Game-Manager.ps1 -Action generate" -ForegroundColor Gray
        Write-Host "  .\Game-Manager.ps1 -Action export -DataFile 'gamedata.json'" -ForegroundColor Gray
    }

    default {
        Write-Warning "Unknown action: $Action"
        Write-Host "Use -Action help for available commands" -ForegroundColor Yellow
    }
}
