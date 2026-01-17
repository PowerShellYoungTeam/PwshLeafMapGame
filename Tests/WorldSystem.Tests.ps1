# WorldSystem.Tests.ps1
# Comprehensive tests for WorldSystem module

BeforeAll {
    # Import CoreGame first (dependency for events)
    $CorePath = Join-Path $PSScriptRoot "..\Modules\CoreGame\CoreGame.psd1"
    Import-Module $CorePath -Force -Global
    
    # Import WorldSystem
    $ModulePath = Join-Path $PSScriptRoot "..\Modules\WorldSystem\WorldSystem.psd1"
    Import-Module $ModulePath -Force
}

Describe "WorldSystem Module" {
    
    Context "Module Loading" {
        It "Should import WorldSystem without errors" {
            $ModulePath = Join-Path $PSScriptRoot "..\Modules\WorldSystem\WorldSystem.psd1"
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module WorldSystem
            $module.ExportedFunctions.Keys | Should -Contain 'Initialize-WorldSystem'
            $module.ExportedFunctions.Keys | Should -Contain 'Get-GameTime'
            $module.ExportedFunctions.Keys | Should -Contain 'New-District'
            $module.ExportedFunctions.Keys | Should -Contain 'New-Location'
            $module.ExportedFunctions.Keys | Should -Contain 'Start-Travel'
        }
    }
    
    Context "Initialize-WorldSystem" {
        It "Should initialize with default configuration" {
            $result = Initialize-WorldSystem
            $result.Initialized | Should -Be $true
            $result.ModuleName | Should -Be 'WorldSystem'
        }
        
        It "Should accept custom start time" {
            $customTime = Get-Date "2045-01-01 12:00:00"
            $result = Initialize-WorldSystem -StartTime $customTime
            $result.GameTime | Should -Be $customTime
        }
        
        It "Should accept custom configuration" {
            $config = @{ TimeScale = 120; DayStartHour = 7 }
            $result = Initialize-WorldSystem -Configuration $config
            $result.Configuration.TimeScale | Should -Be 120
        }
    }
    
    Context "Time System" {
        BeforeEach {
            $null = Initialize-WorldSystem -StartTime (Get-Date "2042-06-15 12:00:00")
        }
        
        It "Get-GameTime should return current time" {
            $time = Get-GameTime
            $time.Hour | Should -Be 12
        }
        
        It "Set-GameTime should update the time" {
            $newTime = Get-Date "2042-06-15 18:00:00"
            $result = Set-GameTime -Time $newTime
            $result.Hour | Should -Be 18
        }
        
        It "Advance-GameTime should add minutes" {
            $result = Advance-GameTime -Minutes 30
            $result.Minute | Should -Be 30
        }
        
        It "Advance-GameTime should add hours" {
            $result = Advance-GameTime -Hours 3
            $result.Hour | Should -Be 15
        }
        
        It "Advance-GameTime should add days" {
            $result = Advance-GameTime -Days 1
            $result.Day | Should -Be 16
        }
        
        It "Get-TimeOfDay should return Noon at 12:00" {
            $tod = Get-TimeOfDay
            $tod.Period | Should -Be 'Noon'
            $tod.IsNight | Should -Be $false
        }
        
        It "Get-TimeOfDay should return Night at 22:00" {
            $null = Set-GameTime -Time (Get-Date "2042-06-15 22:00:00")
            $tod = Get-TimeOfDay
            $tod.Period | Should -Be 'Night'
            $tod.IsNight | Should -Be $true
        }
        
        It "Get-TimeOfDay should return Dawn at 6:00" {
            $null = Set-GameTime -Time (Get-Date "2042-06-15 06:00:00")
            $tod = Get-TimeOfDay
            $tod.Period | Should -Be 'Dawn'
        }
        
        It "Get-TimeOfDay should return LateNight at 2:00" {
            $null = Set-GameTime -Time (Get-Date "2042-06-15 02:00:00")
            $tod = Get-TimeOfDay
            $tod.Period | Should -Be 'LateNight'
            $tod.IsNight | Should -Be $true
        }
    }
    
    Context "Weather System" {
        BeforeEach {
            $null = Initialize-WorldSystem
        }
        
        It "Get-Weather should return current weather" {
            $weather = Get-Weather
            $weather.Name | Should -Be 'Clear'
            $weather.VisibilityModifier | Should -Be 1.0
        }
        
        It "Set-Weather should change weather" {
            $result = Set-Weather -Weather 'Rain'
            $result.Name | Should -Be 'Rain'
            $result.VisibilityModifier | Should -BeLessThan 1.0
        }
        
        It "Set-Weather -Random should set valid weather" {
            $result = Set-Weather -Random
            $validWeathers = @('Clear', 'Rain', 'HeavyRain', 'Fog', 'AcidRain', 'Sandstorm')
            $validWeathers | Should -Contain $result.Name
        }
        
        It "AcidRain should have damage per minute" {
            $result = Set-Weather -Weather 'AcidRain'
            $result.DamagePerMinute | Should -BeGreaterThan 0
        }
        
        It "Weather should affect stealth modifier" {
            $fog = Set-Weather -Weather 'Fog'
            $fog.StealthModifier | Should -BeGreaterThan 1.0
        }
        
        It "Get-WeatherTypes should return all weather types" {
            $types = Get-WeatherTypes
            $types | Should -Contain 'Clear'
            $types | Should -Contain 'Rain'
            $types | Should -Contain 'Fog'
        }
    }
    
    Context "District Management" {
        BeforeEach {
            $null = Initialize-WorldSystem
        }
        
        It "New-District should create a district" {
            $district = New-District -Id 'corp-city' -Name 'Corporate City' -Type 'Corporate'
            $district.Id | Should -Be 'corp-city'
            $district.Name | Should -Be 'Corporate City'
            $district.Type | Should -Be 'Corporate'
        }
        
        It "District should inherit type defaults" {
            $district = New-District -Id 'slum-1' -Name 'The Sprawl' -Type 'Slum'
            $district.SecurityLevel | Should -Be 'None'
            $district.GangPresence | Should -Be 'Very High'
            $district.ShopPriceModifier | Should -BeLessThan 1.0
        }
        
        It "District should accept custom danger level" {
            $district = New-District -Id 'test-1' -Name 'Test' -Type 'Industrial' -DangerLevel 8
            $district.DangerLevel | Should -Be 8
        }
        
        It "Danger level should be clamped to 1-10" {
            $district = New-District -Id 'test-2' -Name 'Test' -Type 'Industrial' -DangerLevel 15
            $district.DangerLevel | Should -Be 10
        }
        
        It "Get-District should return district by ID" {
            $null = New-District -Id 'test-get' -Name 'Test' -Type 'Residential'
            $result = Get-District -Id 'test-get'
            $result.Name | Should -Be 'Test'
        }
        
        It "Get-District -All should return all districts" {
            $null = New-District -Id 'd1' -Name 'District 1' -Type 'Corporate'
            $null = New-District -Id 'd2' -Name 'District 2' -Type 'Industrial'
            $all = Get-District -All
            $all.Count | Should -BeGreaterOrEqual 2
        }
        
        It "Set-DistrictControl should change controlling faction" {
            $null = New-District -Id 'contested' -Name 'Contested Zone' -Type 'Industrial'
            $result = Set-DistrictControl -DistrictId 'contested' -FactionId 'tigers'
            $result.ControllingFaction | Should -Be 'tigers'
        }
        
        It "Get-DistrictTypes should return all district types" {
            $types = Get-DistrictTypes
            $types | Should -Contain 'Corporate'
            $types | Should -Contain 'Slum'
            $types | Should -Contain 'Entertainment'
        }
    }
    
    Context "Location Management" {
        BeforeEach {
            $null = Initialize-WorldSystem
            $null = New-District -Id 'downtown' -Name 'Downtown' -Type 'Entertainment'
        }
        
        It "New-Location should create a location" {
            $loc = New-Location -Id 'bar-1' -Name 'Neon Dreams Bar' -Type 'Bar' -DistrictId 'downtown'
            $loc.Id | Should -Be 'bar-1'
            $loc.Name | Should -Be 'Neon Dreams Bar'
            $loc.Type | Should -Be 'Bar'
        }
        
        It "Location should inherit type properties" {
            $safehouse = New-Location -Id 'safe-1' -Name 'My Safehouse' -Type 'SafeHouse'
            $safehouse.CanRest | Should -Be $true
            $safehouse.CanStore | Should -Be $true
            $safehouse.IsPublic | Should -Be $false
        }
        
        It "Bar should have CanGatherInfo" {
            $bar = New-Location -Id 'bar-2' -Name 'Test Bar' -Type 'Bar'
            $bar.CanGatherInfo | Should -Be $true
        }
        
        It "Clinic should have CanHeal" {
            $clinic = New-Location -Id 'clinic-1' -Name 'Street Doc' -Type 'Clinic'
            $clinic.CanHeal | Should -Be $true
        }
        
        It "Location should be added to district" {
            $null = New-Location -Id 'shop-1' -Name 'Weapon Shop' -Type 'Shop' -DistrictId 'downtown'
            $district = Get-District -Id 'downtown'
            $district.Locations | Should -Contain 'shop-1'
        }
        
        It "Get-Location should return location by ID" {
            $null = New-Location -Id 'loc-get' -Name 'Test Location' -Type 'Street'
            $result = Get-Location -Id 'loc-get'
            $result.Name | Should -Be 'Test Location'
        }
        
        It "Get-Location -All should return all locations" {
            $null = New-Location -Id 'loc-1' -Name 'Location 1' -Type 'Street'
            $null = New-Location -Id 'loc-2' -Name 'Location 2' -Type 'Shop'
            $all = Get-Location -All
            $all.Count | Should -BeGreaterOrEqual 2
        }
        
        It "Get-Location should filter by district" {
            $null = New-District -Id 'other' -Name 'Other' -Type 'Industrial'
            $null = New-Location -Id 'in-downtown' -Name 'In Downtown' -Type 'Street' -DistrictId 'downtown'
            $null = New-Location -Id 'in-other' -Name 'In Other' -Type 'Street' -DistrictId 'other'
            
            $downtownLocs = Get-Location -DistrictId 'downtown'
            $downtownLocs.Id | Should -Contain 'in-downtown'
            $downtownLocs.Id | Should -Not -Contain 'in-other'
        }
        
        It "Get-Location should filter by type" {
            $null = New-Location -Id 'type-bar' -Name 'A Bar' -Type 'Bar'
            $null = New-Location -Id 'type-shop' -Name 'A Shop' -Type 'Shop'
            
            $bars = Get-Location -Type 'Bar'
            $bars.Type | Should -Not -Contain 'Shop'
        }
        
        It "Set-LocationDiscovered should mark location discovered" {
            $loc = New-Location -Id 'discover-me' -Name 'Hidden Place' -Type 'Hideout'
            $loc.IsDiscovered | Should -Be $false
            
            $result = Set-LocationDiscovered -LocationId 'discover-me'
            $result.IsDiscovered | Should -Be $true
        }
        
        It "Get-LocationTypes should return all location types" {
            $types = Get-LocationTypes
            $types | Should -Contain 'SafeHouse'
            $types | Should -Contain 'Shop'
            $types | Should -Contain 'Bar'
        }
    }
    
    Context "Location Connections" {
        BeforeEach {
            $null = Initialize-WorldSystem
            $null = New-Location -Id 'a' -Name 'Point A' -Type 'Street'
            $null = New-Location -Id 'b' -Name 'Point B' -Type 'Street'
        }
        
        It "Connect-Locations should create bidirectional connection" {
            $result = Connect-Locations -FromLocationId 'a' -ToLocationId 'b' -Distance 2.5
            $result | Should -Be $true
            
            $locA = Get-Location -Id 'a'
            $locB = Get-Location -Id 'b'
            
            $locA.Connections.TargetId | Should -Contain 'b'
            $locB.Connections.TargetId | Should -Contain 'a'
        }
        
        It "Connect-Locations -OneWay should create one-way connection" {
            $result = Connect-Locations -FromLocationId 'a' -ToLocationId 'b' -OneWay
            
            $locA = Get-Location -Id 'a'
            $locB = Get-Location -Id 'b'
            
            $locA.Connections.TargetId | Should -Contain 'b'
            $locB.Connections.TargetId | Should -Not -Contain 'a'
        }
    }
    
    Context "Travel System" {
        BeforeEach {
            $null = Initialize-WorldSystem -StartTime (Get-Date "2042-06-15 12:00:00")
            $null = New-District -Id 'district-1' -Name 'District 1' -Type 'Residential'
            $null = New-Location -Id 'home' -Name 'Home' -Type 'SafeHouse' -DistrictId 'district-1'
            $null = New-Location -Id 'shop' -Name 'Corner Shop' -Type 'Shop' -DistrictId 'district-1'
            $null = Connect-Locations -FromLocationId 'home' -ToLocationId 'shop' -Distance 1.0
        }
        
        It "Start-Travel should succeed for valid locations" {
            $result = Start-Travel -FromLocationId 'home' -ToLocationId 'shop'
            $result.Success | Should -Be $true
            $result.FromLocation | Should -Be 'Home'
            $result.ToLocation | Should -Be 'Corner Shop'
        }
        
        It "Travel should advance game time" {
            $timeBefore = Get-GameTime
            $null = Start-Travel -FromLocationId 'home' -ToLocationId 'shop'
            $timeAfter = Get-GameTime
            $timeAfter | Should -BeGreaterThan $timeBefore
        }
        
        It "Travel should mark destination as discovered" {
            $shop = Get-Location -Id 'shop'
            $shop.IsDiscovered | Should -Be $false
            
            $null = Start-Travel -FromLocationId 'home' -ToLocationId 'shop'
            
            $shop = Get-Location -Id 'shop'
            $shop.IsDiscovered | Should -Be $true
        }
        
        It "Travel should increment visit count" {
            $shop = Get-Location -Id 'shop'
            $shop.VisitCount | Should -Be 0
            
            $null = Start-Travel -FromLocationId 'home' -ToLocationId 'shop'
            
            $shop = Get-Location -Id 'shop'
            $shop.VisitCount | Should -Be 1
        }
        
        It "Vehicle travel should be faster" {
            # Create separate locations for this test
            $null = New-Location -Id 'walk-start' -Name 'Walk Start' -Type 'Street'
            $null = New-Location -Id 'walk-end' -Name 'Walk End' -Type 'Street'
            $null = Connect-Locations -FromLocationId 'walk-start' -ToLocationId 'walk-end' -Distance 5.0
            
            $null = New-Location -Id 'drive-start' -Name 'Drive Start' -Type 'Street'
            $null = New-Location -Id 'drive-end' -Name 'Drive End' -Type 'Street'
            $null = Connect-Locations -FromLocationId 'drive-start' -ToLocationId 'drive-end' -Distance 5.0
            
            $walkResult = Start-Travel -FromLocationId 'walk-start' -ToLocationId 'walk-end' -Method 'Walk'
            $vehicleResult = Start-Travel -FromLocationId 'drive-start' -ToLocationId 'drive-end' -Method 'Vehicle'
            
            $vehicleResult.TravelTimeMinutes | Should -BeLessThan $walkResult.TravelTimeMinutes
        }
        
        It "Travel should fail for inaccessible destination" {
            $blockedLoc = New-Location -Id 'blocked' -Name 'Blocked' -Type 'MissionSite'
            $blockedLoc.IsAccessible = $false
            
            $result = Start-Travel -FromLocationId 'home' -ToLocationId 'blocked'
            $result.Success | Should -Be $false
            $result.Error | Should -Be "Destination is not accessible"
        }
        
        It "Travel should fail for invalid locations" {
            $result = Start-Travel -FromLocationId 'home' -ToLocationId 'nonexistent'
            $result.Success | Should -Be $false
        }
    }
    
    Context "Map Functions" {
        BeforeEach {
            $null = Initialize-WorldSystem
        }
        
        It "New-GameMap should create a map" {
            $map = New-GameMap -Name 'Test City'
            $map.Name | Should -Be 'Test City'
            $map.Id | Should -Not -BeNullOrEmpty
        }
        
        It "Add-MapLayer should add layer to map" {
            $map = New-GameMap -Name 'Layer Test'
            $map = Add-MapLayer -Map $map -Name 'Buildings' -Type 'Structure'
            $map.Layers.Count | Should -Be 1
            $map.Layers[0].Name | Should -Be 'Buildings'
        }
        
        It "Add-MapPoint should add point to map" {
            $map = New-GameMap -Name 'Point Test'
            $map = Add-MapPoint -Map $map -Name 'Marker' -Latitude 40.75 -Longitude -73.99
            $map.Points.Count | Should -Be 1
            $map.Points[0].Name | Should -Be 'Marker'
        }
        
        It "Export-GameMap should create file" {
            $map = New-GameMap -Name 'Export Test'
            $map = Add-MapPoint -Map $map -Name 'Test Point' -Latitude 40.75 -Longitude -73.99
            
            $outputPath = Join-Path $TestDrive 'maps'
            $result = Export-GameMap -Map $map -OutputPath $outputPath
            
            $result | Should -Not -BeNullOrEmpty
            Test-Path $result | Should -Be $true
        }
        
        It "Export-GameMap -AsGeoJSON should create GeoJSON file" {
            $map = New-GameMap -Name 'GeoJSON Test'
            $map = Add-MapPoint -Map $map -Name 'Test Point' -Latitude 40.75 -Longitude -73.99
            
            $outputPath = Join-Path $TestDrive 'geojson'
            $result = Export-GameMap -Map $map -OutputPath $outputPath -AsGeoJSON
            
            $result | Should -Match '\.geojson$'
            Test-Path $result | Should -Be $true
        }
        
        It "Import-GameMap should load map from file" {
            $map = New-GameMap -Name 'Import Test'
            $map = Add-MapPoint -Map $map -Name 'Saved Point' -Latitude 40.75 -Longitude -73.99
            
            $outputPath = Join-Path $TestDrive 'import-test'
            $filePath = Export-GameMap -Map $map -OutputPath $outputPath
            
            $loaded = Import-GameMap -Path $filePath
            $loaded.Name | Should -Be 'Import Test'
            $loaded.Points.Count | Should -Be 1
        }
    }
    
    Context "World State" {
        BeforeEach {
            $null = Initialize-WorldSystem -StartTime (Get-Date "2042-06-15 14:00:00")
            $null = New-District -Id 'ws-district' -Name 'Test District' -Type 'Corporate'
            $null = New-Location -Id 'ws-loc-1' -Name 'Location 1' -Type 'Shop' -DistrictId 'ws-district'
            $null = New-Location -Id 'ws-loc-2' -Name 'Location 2' -Type 'Bar' -DistrictId 'ws-district'
        }
        
        It "Get-WorldState should return world summary" {
            $state = Get-WorldState
            $state.GameTime | Should -Not -BeNullOrEmpty
            $state.TimeOfDay | Should -Be 'Afternoon'
            $state.Weather | Should -Be 'Clear'
            $state.DistrictCount | Should -BeGreaterOrEqual 1
            $state.LocationCount | Should -BeGreaterOrEqual 2
        }
        
        It "Get-NearbyLocations should return district locations" {
            $nearby = Get-NearbyLocations -DistrictId 'ws-district'
            $nearby.Count | Should -BeGreaterOrEqual 2
        }
        
        It "Get-NearbyLocations should filter discovered only" {
            $null = Set-LocationDiscovered -LocationId 'ws-loc-1'
            
            $discovered = Get-NearbyLocations -DistrictId 'ws-district' -DiscoveredOnly
            $discovered.Id | Should -Contain 'ws-loc-1'
            $discovered.Id | Should -Not -Contain 'ws-loc-2'
        }
        
        It "Get-NearbyLocations should return connected locations" {
            $null = Connect-Locations -FromLocationId 'ws-loc-1' -ToLocationId 'ws-loc-2' -Distance 0.5
            
            $nearby = Get-NearbyLocations -FromLocationId 'ws-loc-1'
            $nearby.Id | Should -Contain 'ws-loc-2'
        }
    }
}
