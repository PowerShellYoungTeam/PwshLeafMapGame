# Download-OSMData.ps1
# Pre-downloads OpenStreetMap data for a game area using the Overpass API
# Stores data locally to avoid runtime API calls and improve performance

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("New York", "London", "Tokyo", "Glasgow", "Los Angeles", "Moscow", "Berlin", "Dumbarton", "Custom")]
    [string]$City = "New York",

    [Parameter()]
    [string]$OutputPath = "Data/Maps",

    [Parameter()]
    [double]$CustomSouth,

    [Parameter()]
    [double]$CustomWest,

    [Parameter()]
    [double]$CustomNorth,

    [Parameter()]
    [double]$CustomEast,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [int]$RateLimitMs = 1500
)

# City coordinate bounds
$CityBounds = @{
    "New York" = @{
        South = 40.6800; West = -74.0500; North = 40.8200; East = -73.9000
        # Smaller area focused on Manhattan/Brooklyn for better performance
    }
    "London" = @{
        South = 51.4500; West = -0.2000; North = 51.5500; East = 0.0500
        # Central London area
    }
    "Tokyo" = @{
        South = 35.6200; West = 139.7000; North = 35.7200; East = 139.8200
        # Central Tokyo area
    }
    "Glasgow" = @{
        South = 55.8300; West = -4.3500; North = 55.8800; East = -4.1500
        # Glasgow city centre and surrounding areas
    }
    "Los Angeles" = @{
        South = 33.9500; West = -118.5000; North = 34.1500; East = -118.1500
        # Downtown LA and surrounding neighbourhoods
    }
    "Moscow" = @{
        South = 55.6500; West = 37.4500; North = 55.8500; East = 37.8000
        # Central Moscow and inner ring
    }
    "Berlin" = @{
        South = 52.4500; West = 13.3000; North = 52.6000; East = 13.5000
        # Central Berlin area
    }
    "Dumbarton" = @{
        South = 55.9300; West = -4.6000; North = 55.9700; East = -4.5300
        # Historic town in West Dunbartonshire, Scotland
    }
}

# Overpass API endpoints with fallback
$OverpassEndpoints = @(
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter"
)

$CurrentEndpointIndex = 0

function Write-Status {
    param([string]$Message, [string]$Type = "Info")

    $color = switch ($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Progress" { "Cyan" }
        default { "White" }
    }

    Write-Host "[$Type] $Message" -ForegroundColor $color
}

function Invoke-OverpassQuery {
    param(
        [string]$Query,
        [int]$Timeout = 60
    )

    $endpoint = $OverpassEndpoints[$script:CurrentEndpointIndex]
    $fullQuery = "[out:json][timeout:$Timeout];$Query"

    Write-Status "Querying Overpass API..." -Type "Progress"

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post -Body @{ data = $fullQuery } -TimeoutSec ($Timeout + 30)
        return $response
    }
    catch {
        if ($script:CurrentEndpointIndex -lt ($OverpassEndpoints.Count - 1)) {
            $script:CurrentEndpointIndex++
            Write-Status "Primary endpoint failed, trying fallback..." -Type "Warning"
            return Invoke-OverpassQuery -Query $Query -Timeout $Timeout
        }
        throw $_
    }
}

function Get-WaterBodies {
    param([string]$Bbox)

    $query = @"
(
    way["natural"="water"]($Bbox);
    relation["natural"="water"]($Bbox);
    way["natural"="wetland"]($Bbox);
    way["waterway"~"river|stream|canal"]($Bbox);
);
out geom;
"@

    $data = Invoke-OverpassQuery -Query $query
    $waterBodies = @()

    foreach ($element in $data.elements) {
        if ($element.type -eq "way" -and $element.geometry.Count -ge 3) {
            $coords = @()
            foreach ($p in $element.geometry) {
                if ($null -ne $p.lat -and $null -ne $p.lon) {
                    $coords += ,@($p.lat, $p.lon)
                }
            }
            if ($coords.Count -ge 3) {
                $waterBodies += @{
                    type = "polygon"
                    coordinates = $coords
                    tags = if ($element.tags) { $element.tags } else { @{} }
                }
            }
        }
        elseif ($element.type -eq "relation" -and $element.members) {
            foreach ($member in $element.members) {
                if ($member.type -eq "way" -and $member.geometry.Count -ge 3) {
                    $coords = @()
                    foreach ($p in $member.geometry) {
                        if ($null -ne $p.lat -and $null -ne $p.lon) {
                            $coords += ,@($p.lat, $p.lon)
                        }
                    }
                    if ($coords.Count -ge 3) {
                        $waterBodies += @{
                            type = "polygon"
                            coordinates = $coords
                            tags = if ($element.tags) { $element.tags } else { @{} }
                        }
                    }
                }
            }
        }
    }

    return $waterBodies
}

function Get-Buildings {
    param([string]$Bbox)

    $query = @"
(
    way["building"]["addr:housenumber"]($Bbox);
    way["building"]["addr:street"]($Bbox);
    relation["building"]["addr:housenumber"]($Bbox);
);
out center;
"@

    $data = Invoke-OverpassQuery -Query $query
    $buildings = @()

    foreach ($element in $data.elements) {
        $lat = if ($element.center) { $element.center.lat } else { $element.lat }
        $lon = if ($element.center) { $element.center.lon } else { $element.lon }

        if ($null -ne $lat -and $null -ne $lon) {
            $tags = if ($element.tags) { $element.tags } else { @{} }

            $buildings += @{
                id = $element.id
                lat = $lat
                lng = $lon
                type = if ($tags.building) { $tags.building } else { "yes" }
                address = @{
                    housenumber = if ($tags.'addr:housenumber') { $tags.'addr:housenumber' } else { "" }
                    street = if ($tags.'addr:street') { $tags.'addr:street' } else { "" }
                    city = if ($tags.'addr:city') { $tags.'addr:city' } else { "" }
                    postcode = if ($tags.'addr:postcode') { $tags.'addr:postcode' } else { "" }
                }
                name = if ($tags.name) { $tags.name } else { "" }
                amenity = if ($tags.amenity) { $tags.amenity } else { "" }
                shop = if ($tags.shop) { $tags.shop } else { "" }
            }
        }
    }

    return $buildings
}

function Get-TransportStops {
    param([string]$Bbox)

    $query = @"
(
    node["highway"="bus_stop"]($Bbox);
    node["public_transport"="platform"]($Bbox);
    node["railway"="station"]($Bbox);
    node["railway"="halt"]($Bbox);
    node["railway"="subway_entrance"]($Bbox);
    node["railway"="tram_stop"]($Bbox);
    node["amenity"="ferry_terminal"]($Bbox);
);
out;
"@

    $data = Invoke-OverpassQuery -Query $query
    $stops = @()

    foreach ($element in $data.elements) {
        if ($null -ne $element.lat -and $null -ne $element.lon) {
            $tags = if ($element.tags) { $element.tags } else { @{} }

            # Determine stop type
            $stopType = "unknown"
            if ($tags.highway -eq "bus_stop" -or $tags.bus -eq "yes") { $stopType = "bus" }
            elseif ($tags.railway -eq "station") { $stopType = "train" }
            elseif ($tags.railway -eq "subway_entrance") { $stopType = "subway" }
            elseif ($tags.railway -eq "tram_stop") { $stopType = "tram" }
            elseif ($tags.amenity -eq "ferry_terminal") { $stopType = "ferry" }
            elseif ($tags.public_transport -eq "platform") {
                $stopType = if ($tags.bus) { "bus" } elseif ($tags.train) { "train" } else { "transit" }
            }

            $name = if ($tags.name) { $tags.name } else { "$($stopType.Substring(0,1).ToUpper())$($stopType.Substring(1)) Stop" }

            $stops += @{
                id = $element.id
                lat = $element.lat
                lng = $element.lon
                type = $stopType
                name = $name
                ref = if ($tags.ref) { $tags.ref } else { "" }
                operator = if ($tags.operator) { $tags.operator } else { "" }
                network = if ($tags.network) { $tags.network } else { "" }
                routes = if ($tags.route_ref) { $tags.route_ref } else { "" }
            }
        }
    }

    return $stops
}

function Get-Footpaths {
    param([string]$Bbox)

    $query = @"
way["highway"~"footway|pedestrian|path|steps|cycleway"]($Bbox);
out geom;
"@

    $data = Invoke-OverpassQuery -Query $query
    $paths = @()

    foreach ($element in $data.elements) {
        if ($element.type -eq "way" -and $element.geometry.Count -ge 2) {
            $coords = @()
            foreach ($p in $element.geometry) {
                if ($null -ne $p.lat -and $null -ne $p.lon) {
                    $coords += ,@($p.lat, $p.lon)
                }
            }
            if ($coords.Count -ge 2) {
                $tags = if ($element.tags) { $element.tags } else { @{} }

                $paths += @{
                    id = $element.id
                    coordinates = $coords
                    type = if ($tags.highway) { $tags.highway } else { "path" }
                    surface = if ($tags.surface) { $tags.surface } else { "unknown" }
                    name = if ($tags.name) { $tags.name } else { "" }
                }
            }
        }
    }

    return $paths
}

function Get-SurfaceData {
    param([string]$Bbox)

    $query = @"
way["highway"]["surface"]($Bbox);
out geom;
"@

    $data = Invoke-OverpassQuery -Query $query
    $surfaces = @()

    foreach ($element in $data.elements) {
        if ($element.type -eq "way" -and $element.geometry.Count -ge 2 -and $element.tags.surface) {
            $coords = @()
            foreach ($p in $element.geometry) {
                if ($null -ne $p.lat -and $null -ne $p.lon) {
                    $coords += @{ lat = $p.lat; lng = $p.lon }
                }
            }
            if ($coords.Count -ge 2) {
                $surfaces += ,@(
                    $element.id,
                    @{
                        surface = $element.tags.surface
                        coordinates = $coords
                        highway = if ($element.tags.highway) { $element.tags.highway } else { "road" }
                    }
                )
            }
        }
    }

    return $surfaces
}

function Get-Amenities {
    param([string]$Bbox)

    $query = @"
(
    node["amenity"~"restaurant|cafe|bar|pub|fast_food|bank|atm|hospital|clinic|pharmacy|fuel|parking"]($Bbox);
    way["amenity"~"restaurant|cafe|bar|pub|fast_food|bank|atm|hospital|clinic|pharmacy|fuel|parking"]($Bbox);
);
out center;
"@

    $data = Invoke-OverpassQuery -Query $query
    $amenities = @()

    foreach ($element in $data.elements) {
        $lat = if ($element.center) { $element.center.lat } else { $element.lat }
        $lon = if ($element.center) { $element.center.lon } else { $element.lon }

        if ($null -ne $lat -and $null -ne $lon) {
            $tags = if ($element.tags) { $element.tags } else { @{} }
            $amenityType = if ($tags.amenity) { $tags.amenity } else { "unknown" }
            $formattedName = (Get-Culture).TextInfo.ToTitleCase(($amenityType -replace '_', ' '))

            $amenities += @{
                id = $element.id
                lat = $lat
                lng = $lon
                type = $amenityType
                name = if ($tags.name) { $tags.name } else { $formattedName }
                cuisine = if ($tags.cuisine) { $tags.cuisine } else { "" }
                openingHours = if ($tags.opening_hours) { $tags.opening_hours } else { "" }
                wheelchair = if ($tags.wheelchair) { $tags.wheelchair } else { "" }
                phone = if ($tags.phone) { $tags.phone } else { "" }
                website = if ($tags.website) { $tags.website } else { "" }
            }
        }
    }

    return $amenities
}

function Get-Shops {
    param([string]$Bbox)

    $query = @"
(
    node["shop"]($Bbox);
    way["shop"]($Bbox);
);
out center;
"@

    $data = Invoke-OverpassQuery -Query $query
    $shops = @()

    foreach ($element in $data.elements) {
        $lat = if ($element.center) { $element.center.lat } else { $element.lat }
        $lon = if ($element.center) { $element.center.lon } else { $element.lon }

        if ($null -ne $lat -and $null -ne $lon) {
            $tags = if ($element.tags) { $element.tags } else { @{} }
            $shopType = if ($tags.shop) { $tags.shop } else { "general" }
            $formattedName = (Get-Culture).TextInfo.ToTitleCase(($shopType -replace '_', ' '))

            $shops += @{
                id = $element.id
                lat = $lat
                lng = $lon
                shopType = $shopType
                name = if ($tags.name) { $tags.name } else { $formattedName }
                brand = if ($tags.brand) { $tags.brand } else { "" }
                openingHours = if ($tags.opening_hours) { $tags.opening_hours } else { "" }
                wheelchair = if ($tags.wheelchair) { $tags.wheelchair } else { "" }
                phone = if ($tags.phone) { $tags.phone } else { "" }
                website = if ($tags.website) { $tags.website } else { "" }
            }
        }
    }

    return $shops
}

function Get-POIs {
    param([string]$Bbox)

    $query = @"
(
    node["tourism"~"hotel|hostel|motel|attraction|museum|viewpoint|information"]($Bbox);
    node["leisure"~"park|playground|sports_centre|fitness_centre|swimming_pool"]($Bbox);
    node["historic"~"monument|memorial|castle|ruins"]($Bbox);
    way["tourism"]($Bbox);
    way["leisure"~"park|playground|sports_centre"]($Bbox);
);
out center;
"@

    $data = Invoke-OverpassQuery -Query $query
    $pois = @()

    foreach ($element in $data.elements) {
        $lat = if ($element.center) { $element.center.lat } else { $element.lat }
        $lon = if ($element.center) { $element.center.lon } else { $element.lon }

        if ($null -ne $lat -and $null -ne $lon) {
            $tags = if ($element.tags) { $element.tags } else { @{} }

            # Determine category
            $category = "unknown"
            $subtype = ""
            if ($tags.tourism) { $category = "tourism"; $subtype = $tags.tourism }
            elseif ($tags.leisure) { $category = "leisure"; $subtype = $tags.leisure }
            elseif ($tags.historic) { $category = "historic"; $subtype = $tags.historic }

            $formattedName = (Get-Culture).TextInfo.ToTitleCase(($subtype -replace '_', ' '))
            if (-not $formattedName) { $formattedName = "Point of Interest" }

            $pois += @{
                id = $element.id
                lat = $lat
                lng = $lon
                category = $category
                subtype = $subtype
                name = if ($tags.name) { $tags.name } else { $formattedName }
                description = if ($tags.description) { $tags.description } else { "" }
                openingHours = if ($tags.opening_hours) { $tags.opening_hours } else { "" }
                fee = if ($tags.fee) { $tags.fee } else { "" }
                wheelchair = if ($tags.wheelchair) { $tags.wheelchair } else { "" }
                website = if ($tags.website) { $tags.website } else { "" }
            }
        }
    }

    return $pois
}

function Get-LandUse {
    param([string]$Bbox)

    $query = @"
(
    way["landuse"~"residential|commercial|industrial|retail|farmland|forest|grass|meadow|recreation_ground"]($Bbox);
    relation["landuse"]($Bbox);
);
out geom;
"@

    $data = Invoke-OverpassQuery -Query $query
    $landUse = @()

    $speedModifiers = @{
        "residential" = 1.0
        "commercial" = 1.0
        "industrial" = 0.9
        "retail" = 1.0
        "farmland" = 0.7
        "forest" = 0.5
        "grass" = 0.7
        "meadow" = 0.6
        "recreation_ground" = 0.9
        "unknown" = 0.8
    }

    foreach ($element in $data.elements) {
        if ($element.type -eq "way" -and $element.geometry.Count -ge 3) {
            $coords = @()
            foreach ($p in $element.geometry) {
                if ($null -ne $p.lat -and $null -ne $p.lon) {
                    $coords += ,@($p.lat, $p.lon)
                }
            }
            if ($coords.Count -ge 3) {
                $tags = if ($element.tags) { $element.tags } else { @{} }
                $landUseType = if ($tags.landuse) { $tags.landuse } else { "unknown" }
                $modifier = if ($speedModifiers[$landUseType]) { $speedModifiers[$landUseType] } else { 0.8 }

                $landUse += @{
                    id = $element.id
                    type = "polygon"
                    landUseType = $landUseType
                    coordinates = $coords
                    name = if ($tags.name) { $tags.name } else { "" }
                    speedModifier = $modifier
                }
            }
        }
        elseif ($element.type -eq "relation" -and $element.members) {
            foreach ($member in $element.members) {
                if ($member.type -eq "way" -and $member.role -eq "outer" -and $member.geometry.Count -ge 3) {
                    $coords = @()
                    foreach ($p in $member.geometry) {
                        if ($null -ne $p.lat -and $null -ne $p.lon) {
                            $coords += ,@($p.lat, $p.lon)
                        }
                    }
                    if ($coords.Count -ge 3) {
                        $tags = if ($element.tags) { $element.tags } else { @{} }
                        $landUseType = if ($tags.landuse) { $tags.landuse } else { "unknown" }
                        $modifier = if ($speedModifiers[$landUseType]) { $speedModifiers[$landUseType] } else { 0.8 }

                        $landUse += @{
                            id = $element.id
                            type = "polygon"
                            landUseType = $landUseType
                            coordinates = $coords
                            name = if ($tags.name) { $tags.name } else { "" }
                            speedModifier = $modifier
                        }
                    }
                }
            }
        }
    }

    return $landUse
}

# Main script execution
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  OSM Data Downloader for PwshLeafMapGame" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Determine bounds
if ($City -eq "Custom") {
    if (-not $CustomSouth -or -not $CustomWest -or -not $CustomNorth -or -not $CustomEast) {
        Write-Status "Custom bounds require -CustomSouth, -CustomWest, -CustomNorth, -CustomEast parameters" -Type "Error"
        exit 1
    }
    $bounds = @{
        South = $CustomSouth
        West = $CustomWest
        North = $CustomNorth
        East = $CustomEast
    }
    $cityName = "custom"
}
else {
    $bounds = $CityBounds[$City]
    $cityName = $City.ToLower() -replace ' ', ''
}

$bbox = "$($bounds.South),$($bounds.West),$($bounds.North),$($bounds.East)"
Write-Status "City: $City" -Type "Info"
Write-Status "Bounds: $bbox" -Type "Info"

# Ensure output directory exists
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
$outputDir = Join-Path $projectRoot $OutputPath

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Status "Created output directory: $outputDir" -Type "Info"
}

$outputFile = Join-Path $outputDir "$($cityName)_osm.json"

# Check if file exists
if ((Test-Path $outputFile) -and -not $Force) {
    Write-Status "Output file already exists: $outputFile" -Type "Warning"
    Write-Status "Use -Force to overwrite" -Type "Info"
    exit 0
}

# Fetch all data types
$osmData = @{
    metadata = @{
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        city = $City
        source = "overpass-api"
    }
    bounds = @{
        south = $bounds.South
        west = $bounds.West
        north = $bounds.North
        east = $bounds.East
    }
}

$dataTypes = @(
    @{ Name = "waterBodies"; Function = { param($b) Get-WaterBodies -Bbox $b } }
    @{ Name = "buildings"; Function = { param($b) Get-Buildings -Bbox $b } }
    @{ Name = "transportStops"; Function = { param($b) Get-TransportStops -Bbox $b } }
    @{ Name = "footpaths"; Function = { param($b) Get-Footpaths -Bbox $b } }
    @{ Name = "surfaceData"; Function = { param($b) Get-SurfaceData -Bbox $b } }
    @{ Name = "amenities"; Function = { param($b) Get-Amenities -Bbox $b } }
    @{ Name = "shops"; Function = { param($b) Get-Shops -Bbox $b } }
    @{ Name = "pois"; Function = { param($b) Get-POIs -Bbox $b } }
    @{ Name = "landUse"; Function = { param($b) Get-LandUse -Bbox $b } }
)

$totalTypes = $dataTypes.Count
$currentType = 0

foreach ($dataType in $dataTypes) {
    $currentType++
    Write-Host ""
    Write-Status "[$currentType/$totalTypes] Fetching $($dataType.Name)..." -Type "Progress"

    try {
        $result = & $dataType.Function $bbox
        $osmData[$dataType.Name] = $result
        Write-Status "  Retrieved $($result.Count) items" -Type "Success"
    }
    catch {
        Write-Status "  Failed to fetch $($dataType.Name): $_" -Type "Error"
        $osmData[$dataType.Name] = @()
    }

    # Rate limiting
    if ($currentType -lt $totalTypes) {
        Write-Status "  Waiting $($RateLimitMs)ms (rate limit)..." -Type "Info"
        Start-Sleep -Milliseconds $RateLimitMs
    }
}

# Save to file
Write-Host ""
Write-Status "Saving data to $outputFile..." -Type "Progress"

try {
    $jsonContent = $osmData | ConvertTo-Json -Depth 10 -Compress:$false
    $jsonContent | Out-File -FilePath $outputFile -Encoding UTF8

    $fileSize = (Get-Item $outputFile).Length
    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Status "Download complete!" -Type "Success"
    Write-Status "Output file: $outputFile" -Type "Info"
    Write-Status "File size: $fileSizeMB MB" -Type "Info"
    Write-Host ""
    Write-Host "Data Summary:" -ForegroundColor Cyan
    Write-Host "  - Water bodies: $($osmData.waterBodies.Count)"
    Write-Host "  - Buildings: $($osmData.buildings.Count)"
    Write-Host "  - Transport stops: $($osmData.transportStops.Count)"
    Write-Host "  - Footpaths: $($osmData.footpaths.Count)"
    Write-Host "  - Surface segments: $($osmData.surfaceData.Count)"
    Write-Host "  - Amenities: $($osmData.amenities.Count)"
    Write-Host "  - Shops: $($osmData.shops.Count)"
    Write-Host "  - POIs: $($osmData.pois.Count)"
    Write-Host "  - Land use zones: $($osmData.landUse.Count)"
    Write-Host "========================================" -ForegroundColor Green
}
catch {
    Write-Status "Failed to save file: $_" -Type "Error"
    exit 1
}
