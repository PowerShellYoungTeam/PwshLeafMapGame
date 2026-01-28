# PowerShell script to generate game data
# This script can create dynamic game content based on real data
# Note: Client-side OSMDataService validates positions against water bodies

param(
    [string]$OutputFile = "gamedata.json",
    [int]$LocationCount = 10,
    [string]$City = "New York",
    [switch]$IncludeWaterLocations
)

# Function to generate random coordinates within a city bounds
function Get-RandomCoordinates {
    param(
        [string]$CityName
    )

    # City coordinate bounds (you can expand this with more cities)
    $cityBounds = @{
        "New York" = @{
            LatMin = 40.4774
            LatMax = 40.9176
            LngMin = -74.2591
            LngMax = -73.7004
        }
        "London"   = @{
            LatMin = 51.2868
            LatMax = 51.6918
            LngMin = -0.5103
            LngMax = 0.3340
        }
        "Tokyo"    = @{
            LatMin = 35.5494
            LatMax = 35.8174
            LngMin = 139.5792
            LngMax = 139.9160
        }
    }

    $bounds = $cityBounds[$CityName]
    if (-not $bounds) {
        # Default to New York if city not found
        $bounds = $cityBounds["New York"]
    }

    $lat = [math]::Round((Get-Random -Minimum $bounds.LatMin -Maximum $bounds.LatMax), 6)
    $lng = [math]::Round((Get-Random -Minimum $bounds.LngMin -Maximum $bounds.LngMax), 6)

    return @{ Latitude = $lat; Longitude = $lng }
}

# Function to generate location data
function New-GameLocation {
    param(
        [int]$Id,
        [string]$City
    )

    $locationTypes = @("treasure", "quest", "shop", "landmark", "mystery")
    
    # Add water-based location types if enabled
    if ($IncludeWaterLocations) {
        $locationTypes += @("dock", "pier", "marina", "platform")
    }
    
    $type = $locationTypes | Get-Random

    $coordinates = Get-RandomCoordinates -CityName $City

    # Generate items based on location type
    $items = switch ($type) {
        "treasure" { @("golden_coin", "precious_gem", "ancient_artifact") | Get-Random -Count (Get-Random -Minimum 1 -Maximum 3) }
        "quest" { @("quest_item", "magic_scroll", "special_key") | Get-Random -Count 1 }
        "shop" { @("health_potion", "map_upgrade", "tool") | Get-Random -Count (Get-Random -Minimum 1 -Maximum 2) }
        "landmark" { @("tourist_info", "historical_fact") | Get-Random -Count 1 }
        "mystery" { @("mysterious_clue", "riddle_piece") | Get-Random -Count 1 }
        "dock" { @("shipping_manifest", "cargo_crate", "nautical_chart") | Get-Random -Count 1 }
        "pier" { @("fishing_rod", "binoculars", "tide_table") | Get-Random -Count 1 }
        "marina" { @("boat_key", "sailing_manual", "life_jacket") | Get-Random -Count 1 }
        "platform" { @("research_data", "weather_report", "radio_equipment") | Get-Random -Count 1 }
        default { @("common_item") }
    }

    # Generate points based on type
    $points = switch ($type) {
        "treasure" { Get-Random -Minimum 50 -Maximum 150 }
        "quest" { Get-Random -Minimum 100 -Maximum 200 }
        "shop" { Get-Random -Minimum 10 -Maximum 50 }
        "landmark" { Get-Random -Minimum 20 -Maximum 80 }
        "mystery" { Get-Random -Minimum 75 -Maximum 125 }
        "dock" { Get-Random -Minimum 30 -Maximum 70 }
        "pier" { Get-Random -Minimum 15 -Maximum 40 }
        "marina" { Get-Random -Minimum 25 -Maximum 60 }
        "platform" { Get-Random -Minimum 100 -Maximum 175 }
        default { 10 }
    }

    $names = @{
        "treasure" = @("Hidden Cache", "Forgotten Vault", "Secret Stash", "Buried Treasure")
        "quest"    = @("Ancient Temple", "Mystical Portal", "Guardian's Keep", "Sacred Grove")
        "shop"     = @("Merchant's Post", "Trading Hub", "Supply Station", "Market Square")
        "landmark" = @("Historic Monument", "Famous Building", "Cultural Site", "Notable Plaza")
        "mystery"  = @("Enigmatic Location", "Strange Phenomenon", "Unexplained Site", "Curious Spot")
        "dock"     = @("Harbor Dock", "Shipping Terminal", "Cargo Bay", "Ferry Landing")
        "pier"     = @("Fishing Pier", "Observation Pier", "Marina Pier", "Commercial Pier")
        "marina"   = @("Yacht Marina", "Boat Harbor", "Sailing Club", "Maritime Center")
        "platform" = @("Oil Platform", "Research Platform", "Weather Station", "Observation Deck")
    }

    $name = ($names[$type] | Get-Random) + " #$Id"

    $descriptions = @{
        "treasure" = @("A hidden treasure awaits discovery!", "Riches beyond imagination lie here.", "Ancient wealth sleeps in this location.")
        "quest"    = @("A challenging quest begins here.", "Ancient mysteries await your arrival.", "Brave adventurers are needed here.")
        "shop"     = @("Useful items and supplies available.", "A place to trade and resupply.", "Merchants offer their wares here.")
        "landmark" = @("A place of historical significance.", "An important cultural location.", "A famous site worth visiting.")
        "mystery"  = @("Something strange happens here...", "An unexplained phenomenon occurs.", "Mysteries abound in this location.")
        "dock"     = @("Ships come and go from this busy dock.", "A commercial hub on the water.", "Maritime trade flows through here.")
        "pier"     = @("A structure extending into the water.", "Watch the boats from this pier.", "A gathering place by the water.")
        "marina"   = @("Boats of all sizes are moored here.", "A haven for sailing enthusiasts.", "Yacht owners frequent this spot.")
        "platform" = @("An offshore structure in the water.", "Research activities take place here.", "A remote outpost on the waves.")
    }

    $description = $descriptions[$type] | Get-Random

    return @{
        id          = "location_$Id"
        lat         = $coordinates.Latitude
        lng         = $coordinates.Longitude
        name        = $name
        type        = $type
        description = $description
        items       = $items
        points      = $points
        experience  = [math]::Round($points / 2)
        discovered  = $false
        timestamp   = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    }
}

# Main script execution
Write-Host "Generating game data for $City with $LocationCount locations..." -ForegroundColor Green

$gameData = @{
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    city        = $City
    version     = "1.0"
    locations   = @()
    metadata    = @{
        totalLocations = $LocationCount
        generator      = "PowerShell Game Data Generator"
        scriptVersion  = "1.0"
    }
}

# Generate locations
for ($i = 1; $i -le $LocationCount; $i++) {
    $location = New-GameLocation -Id $i -City $City
    $gameData.locations += $location

    # Only show progress if running in interactive console (not redirected)
    try {
        if ([Environment]::UserInteractive -and -not [Console]::IsOutputRedirected) {
            Write-Progress -Activity "Generating locations" -Status "Creating location $i of $LocationCount" -PercentComplete (($i / $LocationCount) * 100)
        }
    }
    catch {
        # Silently continue if Write-Progress fails
    }
}

# Clear progress bar
try {
    Write-Progress -Activity "Generating locations" -Completed
}
catch {
    # Silently continue if Write-Progress fails
}

# Convert to JSON and save
$jsonOutput = $gameData | ConvertTo-Json -Depth 10
$jsonOutput | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "`nGame data generated successfully!" -ForegroundColor Green
Write-Host "File saved as: $OutputFile" -ForegroundColor Yellow
Write-Host "Total locations: $($gameData.locations.Count)" -ForegroundColor Cyan

# Display summary
$typeCounts = $gameData.locations | Group-Object type | ForEach-Object {
    "$($_.Name): $($_.Count)"
} | Join-String -Separator ", "

Write-Host "Location types: $typeCounts" -ForegroundColor Magenta

# Return the file path for use in other scripts
return $OutputFile
