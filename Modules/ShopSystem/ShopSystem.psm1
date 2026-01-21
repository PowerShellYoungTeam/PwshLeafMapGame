# ShopSystem Module
# Comprehensive shop, vendor, inventory, and trading system

#region Module State
$script:ShopSystemState = @{
    Initialized = $false
    Shops = @{}
    ItemCatalog = @{}
    PlayerInventory = @{
        Items = @{}
        Currency = 0
        MaxWeight = 100
        CurrentWeight = 0
    }
    Transactions = @()
    Configuration = @{}
}

# Vendor Types as per GameDesign.md
$script:VendorTypes = @{
    BlackMarket = @{
        Name = 'Black Market'
        Description = 'Illegal weapons, stolen cyberware, contraband'
        RequiresReputation = $true
        MinStanding = 'Neutral'
        LegalItems = $false
        IllegalItems = $true
        DefaultMarkup = 1.2
        BuybackRate = 0.6
        ItemCategories = @('Weapons', 'Cyberware', 'Contraband', 'Drugs', 'StolenGoods')
    }
    CorporateStore = @{
        Name = 'Corporate Store'
        Description = 'Legal items, overpriced, available to all'
        RequiresReputation = $false
        MinStanding = 'Hostile'
        LegalItems = $true
        IllegalItems = $false
        DefaultMarkup = 1.5
        BuybackRate = 0.4
        ItemCategories = @('Weapons', 'Armor', 'Electronics', 'Medical', 'Consumables')
    }
    StreetVendor = @{
        Name = 'Street Vendor'
        Description = 'Basic supplies, fair prices'
        RequiresReputation = $false
        MinStanding = 'Unfriendly'
        LegalItems = $true
        IllegalItems = $false
        DefaultMarkup = 1.0
        BuybackRate = 0.5
        ItemCategories = @('Consumables', 'Medical', 'Tools', 'Junk')
    }
    Fixer = @{
        Name = 'Fixer'
        Description = 'Intel, mission equipment, specialized gear'
        RequiresReputation = $true
        MinStanding = 'Neutral'
        LegalItems = $true
        IllegalItems = $true
        DefaultMarkup = 1.1
        BuybackRate = 0.55
        ItemCategories = @('Intel', 'MissionGear', 'Electronics', 'Cyberware')
    }
    ChopShop = @{
        Name = 'Chop Shop'
        Description = 'Vehicles, vehicle mods, stolen parts'
        RequiresReputation = $true
        MinStanding = 'Neutral'
        LegalItems = $false
        IllegalItems = $true
        DefaultMarkup = 0.9
        BuybackRate = 0.7
        ItemCategories = @('Vehicles', 'VehicleParts', 'StolenGoods')
    }
    MedClinic = @{
        Name = 'Medical Clinic'
        Description = 'Medical supplies, healing services, cyberware installation'
        RequiresReputation = $false
        MinStanding = 'Unfriendly'
        LegalItems = $true
        IllegalItems = $false
        DefaultMarkup = 1.3
        BuybackRate = 0.3
        ItemCategories = @('Medical', 'Cyberware', 'Drugs')
    }
    TechShop = @{
        Name = 'Tech Shop'
        Description = 'Electronics, hacking tools, drone parts'
        RequiresReputation = $false
        MinStanding = 'Neutral'
        LegalItems = $true
        IllegalItems = $true
        DefaultMarkup = 1.15
        BuybackRate = 0.5
        ItemCategories = @('Electronics', 'DroneParts', 'Tools', 'Software')
    }
}

# Item Rarities with price modifiers
$script:RarityLevels = @{
    Common = @{
        Name = 'Common'
        PriceModifier = 1.0
        Color = 'Gray'
        DropChance = 0.60
    }
    Uncommon = @{
        Name = 'Uncommon'
        PriceModifier = 2.0
        Color = 'Green'
        DropChance = 0.25
    }
    Rare = @{
        Name = 'Rare'
        PriceModifier = 5.0
        Color = 'Blue'
        DropChance = 0.10
    }
    Epic = @{
        Name = 'Epic'
        PriceModifier = 10.0
        Color = 'Purple'
        DropChance = 0.04
    }
    Legendary = @{
        Name = 'Legendary'
        PriceModifier = 20.0
        Color = 'Orange'
        DropChance = 0.01
    }
}

# Item Categories
$script:ItemCategories = @{
    Weapons = @{
        Name = 'Weapons'
        DefaultWeight = 3.0
        Stackable = $false
        MaxStack = 1
    }
    Armor = @{
        Name = 'Armor'
        DefaultWeight = 5.0
        Stackable = $false
        MaxStack = 1
    }
    Cyberware = @{
        Name = 'Cyberware'
        DefaultWeight = 0.5
        Stackable = $false
        MaxStack = 1
    }
    Consumables = @{
        Name = 'Consumables'
        DefaultWeight = 0.2
        Stackable = $true
        MaxStack = 99
    }
    Medical = @{
        Name = 'Medical'
        DefaultWeight = 0.3
        Stackable = $true
        MaxStack = 20
    }
    Electronics = @{
        Name = 'Electronics'
        DefaultWeight = 0.5
        Stackable = $true
        MaxStack = 10
    }
    Tools = @{
        Name = 'Tools'
        DefaultWeight = 1.0
        Stackable = $false
        MaxStack = 1
    }
    Intel = @{
        Name = 'Intel'
        DefaultWeight = 0.0
        Stackable = $true
        MaxStack = 999
    }
    Contraband = @{
        Name = 'Contraband'
        DefaultWeight = 1.0
        Stackable = $true
        MaxStack = 50
    }
    Drugs = @{
        Name = 'Drugs'
        DefaultWeight = 0.1
        Stackable = $true
        MaxStack = 20
    }
    Junk = @{
        Name = 'Junk'
        DefaultWeight = 0.5
        Stackable = $true
        MaxStack = 99
    }
    Vehicles = @{
        Name = 'Vehicles'
        DefaultWeight = 0.0
        Stackable = $false
        MaxStack = 1
    }
    VehicleParts = @{
        Name = 'Vehicle Parts'
        DefaultWeight = 5.0
        Stackable = $true
        MaxStack = 10
    }
    DroneParts = @{
        Name = 'Drone Parts'
        DefaultWeight = 1.0
        Stackable = $true
        MaxStack = 20
    }
    MissionGear = @{
        Name = 'Mission Gear'
        DefaultWeight = 2.0
        Stackable = $false
        MaxStack = 1
    }
    Software = @{
        Name = 'Software'
        DefaultWeight = 0.0
        Stackable = $false
        MaxStack = 1
    }
    StolenGoods = @{
        Name = 'Stolen Goods'
        DefaultWeight = 2.0
        Stackable = $true
        MaxStack = 20
    }
}

# Standing price modifiers (from FactionSystem integration)
$script:StandingPriceModifiers = @{
    Hostile = 2.0
    Unfriendly = 1.5
    Neutral = 1.0
    Friendly = 0.9
    Allied = 0.8
}
#endregion

#region Initialization
function Initialize-ShopSystem {
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{}
    )
    
    Write-Host "Initializing ShopSystem module..."
    
    $defaultConfig = @{
        StartingCurrency = 1000
        MaxInventoryWeight = 100
        DefaultBuybackRate = 0.5
        TransactionTax = 0.0
        EnableDynamicPricing = $true
        PriceFluctuation = 0.1
        RestockInterval = 24
    }
    
    # Merge configurations
    foreach ($key in $Configuration.Keys) {
        $defaultConfig[$key] = $Configuration[$key]
    }
    
    $script:ShopSystemState = @{
        Initialized = $true
        Shops = @{}
        ItemCatalog = @{}
        PlayerInventory = @{
            Items = @{}
            Currency = $defaultConfig.StartingCurrency
            MaxWeight = $defaultConfig.MaxInventoryWeight
            CurrentWeight = 0
        }
        Transactions = @()
        Configuration = $defaultConfig
        SupplyModifiers = @{}
        LastRestock = Get-Date
    }
    
    return @{
        Initialized = $true
        ModuleName = 'ShopSystem'
        Configuration = $defaultConfig
        VendorTypes = $script:VendorTypes.Keys | Sort-Object
        ItemCategories = $script:ItemCategories.Keys | Sort-Object
        RarityLevels = $script:RarityLevels.Keys | Sort-Object
    }
}

function Get-ShopSystemState {
    [CmdletBinding()]
    param()
    
    return @{
        Initialized = $script:ShopSystemState.Initialized
        ShopCount = $script:ShopSystemState.Shops.Count
        ItemCatalogCount = $script:ShopSystemState.ItemCatalog.Count
        PlayerCurrency = $script:ShopSystemState.PlayerInventory.Currency
        InventoryWeight = "$($script:ShopSystemState.PlayerInventory.CurrentWeight)/$($script:ShopSystemState.PlayerInventory.MaxWeight)"
        TransactionCount = $script:ShopSystemState.Transactions.Count
        Configuration = $script:ShopSystemState.Configuration
    }
}
#endregion

#region Item Catalog
function New-Item {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateSet('Weapons', 'Armor', 'Cyberware', 'Consumables', 'Medical', 'Electronics', 
                     'Tools', 'Intel', 'Contraband', 'Drugs', 'Junk', 'Vehicles', 
                     'VehicleParts', 'DroneParts', 'MissionGear', 'Software', 'StolenGoods')]
        [string]$Category,
        
        [Parameter(Mandatory)]
        [int]$BasePrice,
        
        [ValidateSet('Common', 'Uncommon', 'Rare', 'Epic', 'Legendary')]
        [string]$Rarity = 'Common',
        
        [string]$Description = '',
        
        [double]$Weight = -1,
        
        [bool]$IsLegal = $true,
        
        [hashtable]$Properties = @{},
        
        [string[]]$Tags = @()
    )
    
    if (-not $script:ShopSystemState.Initialized) {
        throw "ShopSystem not initialized."
    }
    
    if ($script:ShopSystemState.ItemCatalog.ContainsKey($ItemId)) {
        throw "Item '$ItemId' already exists in catalog."
    }
    
    $categoryInfo = $script:ItemCategories[$Category]
    $rarityInfo = $script:RarityLevels[$Rarity]
    
    $itemWeight = if ($Weight -ge 0) { $Weight } else { $categoryInfo.DefaultWeight }
    
    $item = @{
        ItemId = $ItemId
        Name = $Name
        Category = $Category
        CategoryInfo = $categoryInfo
        BasePrice = $BasePrice
        Rarity = $Rarity
        RarityInfo = $rarityInfo
        Description = $Description
        Weight = $itemWeight
        IsLegal = $IsLegal
        Stackable = $categoryInfo.Stackable
        MaxStack = $categoryInfo.MaxStack
        Properties = $Properties
        Tags = $Tags
        CreatedAt = Get-Date
    }
    
    $script:ShopSystemState.ItemCatalog[$ItemId] = $item
    
    return $item
}

function Get-Item {
    [CmdletBinding()]
    param(
        [string]$ItemId,
        [string]$Category,
        [string]$Rarity,
        [switch]$IllegalOnly,
        [switch]$LegalOnly
    )
    
    if (-not $script:ShopSystemState.Initialized) {
        throw "ShopSystem not initialized."
    }
    
    if ($ItemId) {
        return $script:ShopSystemState.ItemCatalog[$ItemId]
    }
    
    $items = $script:ShopSystemState.ItemCatalog.Values
    
    if ($Category) {
        $items = $items | Where-Object { $_.Category -eq $Category }
    }
    
    if ($Rarity) {
        $items = $items | Where-Object { $_.Rarity -eq $Rarity }
    }
    
    if ($IllegalOnly) {
        $items = $items | Where-Object { -not $_.IsLegal }
    }
    
    if ($LegalOnly) {
        $items = $items | Where-Object { $_.IsLegal }
    }
    
    return @($items)
}

function Remove-Item {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ItemId
    )
    
    if (-not $script:ShopSystemState.ItemCatalog.ContainsKey($ItemId)) {
        return $false
    }
    
    $script:ShopSystemState.ItemCatalog.Remove($ItemId)
    return $true
}
#endregion

#region Shop Management
function New-Shop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateSet('BlackMarket', 'CorporateStore', 'StreetVendor', 'Fixer', 'ChopShop', 'MedClinic', 'TechShop')]
        [string]$VendorType,
        
        [string]$Description = '',
        
        [string]$LocationId = '',
        
        [string]$OwnerId = '',
        
        [string]$FactionId = '',
        
        [hashtable]$CustomPricing = @{},
        
        [double]$MarkupModifier = 1.0,
        
        [bool]$IsOpen = $true
    )
    
    if (-not $script:ShopSystemState.Initialized) {
        throw "ShopSystem not initialized."
    }
    
    if ($script:ShopSystemState.Shops.ContainsKey($ShopId)) {
        throw "Shop '$ShopId' already exists."
    }
    
    $vendorInfo = $script:VendorTypes[$VendorType]
    
    $shop = @{
        ShopId = $ShopId
        Name = $Name
        VendorType = $VendorType
        VendorInfo = $vendorInfo
        Description = $Description
        LocationId = $LocationId
        OwnerId = $OwnerId
        FactionId = $FactionId
        Inventory = @{}
        CustomPricing = $CustomPricing
        MarkupModifier = $MarkupModifier
        BuybackRate = $vendorInfo.BuybackRate
        IsOpen = $IsOpen
        LastRestock = Get-Date
        TotalSales = 0
        TotalPurchases = 0
        CreatedAt = Get-Date
    }
    
    $script:ShopSystemState.Shops[$ShopId] = $shop
    
    # Send event if available
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'ShopCreated' -Data @{
            ShopId = $ShopId
            Name = $Name
            VendorType = $VendorType
            FactionId = $FactionId
        }
    }
    
    return $shop
}

function Get-Shop {
    [CmdletBinding()]
    param(
        [string]$ShopId,
        [string]$VendorType,
        [string]$LocationId,
        [string]$FactionId,
        [switch]$OpenOnly
    )
    
    if (-not $script:ShopSystemState.Initialized) {
        throw "ShopSystem not initialized."
    }
    
    if ($ShopId) {
        return $script:ShopSystemState.Shops[$ShopId]
    }
    
    $shops = $script:ShopSystemState.Shops.Values
    
    if ($VendorType) {
        $shops = $shops | Where-Object { $_.VendorType -eq $VendorType }
    }
    
    if ($LocationId) {
        $shops = $shops | Where-Object { $_.LocationId -eq $LocationId }
    }
    
    if ($FactionId) {
        $shops = $shops | Where-Object { $_.FactionId -eq $FactionId }
    }
    
    if ($OpenOnly) {
        $shops = $shops | Where-Object { $_.IsOpen }
    }
    
    return @($shops)
}

function Set-ShopOpen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [Parameter(Mandatory)]
        [bool]$IsOpen
    )
    
    $shop = $script:ShopSystemState.Shops[$ShopId]
    if (-not $shop) {
        return $false
    }
    
    $shop.IsOpen = $IsOpen
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'ShopStatusChanged' -Data @{
            ShopId = $ShopId
            IsOpen = $IsOpen
        }
    }
    
    return $true
}

function Remove-Shop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId
    )
    
    if (-not $script:ShopSystemState.Shops.ContainsKey($ShopId)) {
        return $false
    }
    
    $script:ShopSystemState.Shops.Remove($ShopId)
    return $true
}
#endregion

#region Shop Inventory
function Add-ShopInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [int]$Quantity = 1,
        
        [double]$CustomPrice = -1
    )
    
    $shop = $script:ShopSystemState.Shops[$ShopId]
    if (-not $shop) {
        throw "Shop '$ShopId' not found."
    }
    
    $item = $script:ShopSystemState.ItemCatalog[$ItemId]
    if (-not $item) {
        throw "Item '$ItemId' not found in catalog."
    }
    
    # Check if item category is allowed for this vendor type
    if ($item.Category -notin $shop.VendorInfo.ItemCategories) {
        Write-Warning "Item category '$($item.Category)' not typically sold at $($shop.VendorInfo.Name)"
    }
    
    if ($shop.Inventory.ContainsKey($ItemId)) {
        $shop.Inventory[$ItemId].Quantity += $Quantity
    }
    else {
        $shop.Inventory[$ItemId] = @{
            ItemId = $ItemId
            Quantity = $Quantity
            CustomPrice = $CustomPrice
            AddedAt = Get-Date
        }
    }
    
    return @{
        ShopId = $ShopId
        ItemId = $ItemId
        Quantity = $shop.Inventory[$ItemId].Quantity
        Item = $item
    }
}

function Remove-ShopInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [int]$Quantity = 1
    )
    
    $shop = $script:ShopSystemState.Shops[$ShopId]
    if (-not $shop) {
        return $false
    }
    
    if (-not $shop.Inventory.ContainsKey($ItemId)) {
        return $false
    }
    
    $shop.Inventory[$ItemId].Quantity -= $Quantity
    
    if ($shop.Inventory[$ItemId].Quantity -le 0) {
        $shop.Inventory.Remove($ItemId)
    }
    
    return $true
}

function Get-ShopInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [string]$Category,
        
        [switch]$WithPrices,
        
        [string]$PlayerStanding = 'Neutral'
    )
    
    $shop = $script:ShopSystemState.Shops[$ShopId]
    if (-not $shop) {
        throw "Shop '$ShopId' not found."
    }
    
    $inventory = [System.Collections.ArrayList]::new()
    
    foreach ($entry in $shop.Inventory.GetEnumerator()) {
        $item = $script:ShopSystemState.ItemCatalog[$entry.Key]
        if (-not $item) { continue }
        
        if ($Category -and $item.Category -ne $Category) { continue }
        
        $invItem = @{
            ItemId = $entry.Key
            Name = $item.Name
            Category = $item.Category
            Rarity = $item.Rarity
            Quantity = $entry.Value.Quantity
            BasePrice = $item.BasePrice
            Weight = $item.Weight
            IsLegal = $item.IsLegal
        }
        
        if ($WithPrices) {
            $invItem.Price = Get-ItemPrice -ShopId $ShopId -ItemId $entry.Key -PlayerStanding $PlayerStanding
            $invItem.SellPrice = Get-ItemSellPrice -ShopId $ShopId -ItemId $entry.Key -PlayerStanding $PlayerStanding
        }
        
        [void]$inventory.Add($invItem)
    }
    
    # Use comma operator to ensure array is preserved even with single item
    return ,@($inventory)
}

function Restock-Shop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [hashtable]$StockDefinition = @{},
        
        [switch]$ClearExisting
    )
    
    if (-not $script:ShopSystemState.Shops.ContainsKey($ShopId)) {
        throw "Shop '$ShopId' not found."
    }
    
    if ($ClearExisting) {
        $script:ShopSystemState.Shops[$ShopId].Inventory = @{}
    }
    
    foreach ($entry in $StockDefinition.GetEnumerator()) {
        $itemId = $entry.Key
        $quantity = $entry.Value
        
        if ($script:ShopSystemState.ItemCatalog.ContainsKey($itemId)) {
            Add-ShopInventory -ShopId $ShopId -ItemId $itemId -Quantity $quantity | Out-Null
        }
    }
    
    $script:ShopSystemState.Shops[$ShopId].LastRestock = Get-Date
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'ShopRestocked' -Data @{
            ShopId = $ShopId
            ItemCount = $script:ShopSystemState.Shops[$ShopId].Inventory.Count
        }
    }
    
    return @{
        ShopId = $ShopId
        ItemCount = $script:ShopSystemState.Shops[$ShopId].Inventory.Count
        RestockedAt = $script:ShopSystemState.Shops[$ShopId].LastRestock
    }
}
#endregion

#region Pricing System
function Get-ItemPrice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [string]$PlayerStanding = 'Neutral',
        
        [int]$Quantity = 1
    )
    
    $shop = $script:ShopSystemState.Shops[$ShopId]
    if (-not $shop) {
        throw "Shop '$ShopId' not found."
    }
    
    $item = $script:ShopSystemState.ItemCatalog[$ItemId]
    if (-not $item) {
        throw "Item '$ItemId' not found."
    }
    
    # Check for custom price in shop inventory
    $customPrice = -1
    if ($shop.Inventory.ContainsKey($ItemId)) {
        $customPrice = $shop.Inventory[$ItemId].CustomPrice
    }
    
    # Check for custom price in shop settings
    if ($customPrice -lt 0 -and $shop.CustomPricing.ContainsKey($ItemId)) {
        $customPrice = $shop.CustomPricing[$ItemId]
    }
    
    $basePrice = if ($customPrice -gt 0) { $customPrice } else { $item.BasePrice }
    
    # Apply modifiers
    # 1. Rarity modifier
    $rarityMod = $item.RarityInfo.PriceModifier
    
    # 2. Faction/Standing modifier
    $standingMod = $script:StandingPriceModifiers[$PlayerStanding]
    if (-not $standingMod) { $standingMod = 1.0 }
    
    # 3. Vendor markup
    $vendorMarkup = $shop.VendorInfo.DefaultMarkup * $shop.MarkupModifier
    
    # 4. Supply modifier (dynamic pricing)
    $supplyMod = 1.0
    if ($script:ShopSystemState.Configuration.EnableDynamicPricing) {
        if ($script:ShopSystemState.SupplyModifiers.ContainsKey($item.Category)) {
            $supplyMod = $script:ShopSystemState.SupplyModifiers[$item.Category]
        }
    }
    
    # Calculate final price
    # Note: Rarity is already factored into BasePrice for most items, 
    # so we only apply it if it's a base catalog price
    $finalPrice = [math]::Ceiling($basePrice * $standingMod * $vendorMarkup * $supplyMod * $Quantity)
    
    return [int]$finalPrice
}

function Get-ItemSellPrice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [string]$PlayerStanding = 'Neutral',
        
        [int]$Quantity = 1
    )
    
    $shop = $script:ShopSystemState.Shops[$ShopId]
    if (-not $shop) {
        throw "Shop '$ShopId' not found."
    }
    
    $item = $script:ShopSystemState.ItemCatalog[$ItemId]
    if (-not $item) {
        throw "Item '$ItemId' not found."
    }
    
    # Base sell price is item value * buyback rate
    $basePrice = $item.BasePrice
    $buybackRate = $shop.BuybackRate
    
    # Better standing = better sell prices (inverse of buy modifier)
    $standingMod = $script:StandingPriceModifiers[$PlayerStanding]
    if (-not $standingMod) { $standingMod = 1.0 }
    
    # Invert standing for selling (friendly = better price when selling)
    $sellStandingMod = 2.0 - $standingMod
    if ($sellStandingMod -lt 0.5) { $sellStandingMod = 0.5 }
    if ($sellStandingMod -gt 1.5) { $sellStandingMod = 1.5 }
    
    $finalPrice = [math]::Floor($basePrice * $buybackRate * $sellStandingMod * $Quantity)
    
    return [int][math]::Max(1, $finalPrice)
}

function Set-SupplyModifier {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Category,
        
        [Parameter(Mandatory)]
        [double]$Modifier,
        
        [string]$Reason = ''
    )
    
    if ($Modifier -lt 0.5) { $Modifier = 0.5 }
    if ($Modifier -gt 3.0) { $Modifier = 3.0 }
    
    $script:ShopSystemState.SupplyModifiers[$Category] = $Modifier
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'SupplyModifierChanged' -Data @{
            Category = $Category
            Modifier = $Modifier
            Reason = $Reason
        }
    }
    
    return @{
        Category = $Category
        Modifier = $Modifier
        Reason = $Reason
    }
}

function Get-SupplyModifier {
    [CmdletBinding()]
    param(
        [string]$Category
    )
    
    if ($Category) {
        $mod = $script:ShopSystemState.SupplyModifiers[$Category]
        if ($mod) { return $mod } else { return 1.0 }
    }
    
    return $script:ShopSystemState.SupplyModifiers.Clone()
}
#endregion

#region Player Inventory
function Get-PlayerInventory {
    [CmdletBinding()]
    param(
        [string]$Category,
        [switch]$Summary
    )
    
    if (-not $script:ShopSystemState.Initialized) {
        throw "ShopSystem not initialized."
    }
    
    if ($Summary) {
        return @{
            Currency = $script:ShopSystemState.PlayerInventory.Currency
            CurrentWeight = $script:ShopSystemState.PlayerInventory.CurrentWeight
            MaxWeight = $script:ShopSystemState.PlayerInventory.MaxWeight
            ItemCount = $script:ShopSystemState.PlayerInventory.Items.Count
            UniqueItems = $script:ShopSystemState.PlayerInventory.Items.Keys.Count
        }
    }
    
    $items = @()
    foreach ($entry in $script:ShopSystemState.PlayerInventory.Items.GetEnumerator()) {
        $catalogItem = $script:ShopSystemState.ItemCatalog[$entry.Key]
        
        $invItem = @{
            ItemId = $entry.Key
            Name = if ($catalogItem) { $catalogItem.Name } else { $entry.Key }
            Category = if ($catalogItem) { $catalogItem.Category } else { 'Unknown' }
            Rarity = if ($catalogItem) { $catalogItem.Rarity } else { 'Common' }
            Quantity = $entry.Value.Quantity
            TotalWeight = $entry.Value.TotalWeight
            AcquiredAt = $entry.Value.AcquiredAt
        }
        
        if ($Category -and $invItem.Category -ne $Category) { continue }
        
        $items += $invItem
    }
    
    return $items
}

function Add-PlayerInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [int]$Quantity = 1,
        
        [string]$Source = 'Unknown'
    )
    
    if (-not $script:ShopSystemState.Initialized) {
        throw "ShopSystem not initialized."
    }
    
    $item = $script:ShopSystemState.ItemCatalog[$ItemId]
    if (-not $item) {
        throw "Item '$ItemId' not found in catalog."
    }
    
    $itemWeight = $item.Weight * $Quantity
    
    # Check weight capacity
    $newWeight = $script:ShopSystemState.PlayerInventory.CurrentWeight + $itemWeight
    if ($newWeight -gt $script:ShopSystemState.PlayerInventory.MaxWeight) {
        return @{
            Success = $false
            Reason = 'Inventory full'
            RequiredWeight = $itemWeight
            AvailableWeight = $script:ShopSystemState.PlayerInventory.MaxWeight - $script:ShopSystemState.PlayerInventory.CurrentWeight
        }
    }
    
    # Check stack limits
    if ($script:ShopSystemState.PlayerInventory.Items.ContainsKey($ItemId)) {
        $currentQty = $script:ShopSystemState.PlayerInventory.Items[$ItemId].Quantity
        if (-not $item.Stackable -and $currentQty -ge 1) {
            return @{
                Success = $false
                Reason = 'Item not stackable'
            }
        }
        if ($currentQty + $Quantity -gt $item.MaxStack) {
            return @{
                Success = $false
                Reason = 'Stack limit reached'
                MaxStack = $item.MaxStack
                CurrentStack = $currentQty
            }
        }
        
        $script:ShopSystemState.PlayerInventory.Items[$ItemId].Quantity += $Quantity
        $script:ShopSystemState.PlayerInventory.Items[$ItemId].TotalWeight += $itemWeight
    }
    else {
        $script:ShopSystemState.PlayerInventory.Items[$ItemId] = @{
            ItemId = $ItemId
            Quantity = $Quantity
            TotalWeight = $itemWeight
            AcquiredAt = Get-Date
            Source = $Source
        }
    }
    
    $script:ShopSystemState.PlayerInventory.CurrentWeight += $itemWeight
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'ItemAcquired' -Data @{
            ItemId = $ItemId
            ItemName = $item.Name
            Quantity = $Quantity
            Source = $Source
        }
    }
    
    return @{
        Success = $true
        ItemId = $ItemId
        ItemName = $item.Name
        Quantity = $script:ShopSystemState.PlayerInventory.Items[$ItemId].Quantity
        CurrentWeight = $script:ShopSystemState.PlayerInventory.CurrentWeight
    }
}

function Remove-PlayerInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [int]$Quantity = 1
    )
    
    if (-not $script:ShopSystemState.PlayerInventory.Items.ContainsKey($ItemId)) {
        return @{
            Success = $false
            Reason = 'Item not in inventory'
        }
    }
    
    $invItem = $script:ShopSystemState.PlayerInventory.Items[$ItemId]
    $catalogItem = $script:ShopSystemState.ItemCatalog[$ItemId]
    
    if ($invItem.Quantity -lt $Quantity) {
        return @{
            Success = $false
            Reason = 'Insufficient quantity'
            Available = $invItem.Quantity
            Requested = $Quantity
        }
    }
    
    $weightPerItem = if ($catalogItem) { $catalogItem.Weight } else { $invItem.TotalWeight / $invItem.Quantity }
    $removedWeight = $weightPerItem * $Quantity
    
    $invItem.Quantity -= $Quantity
    $invItem.TotalWeight -= $removedWeight
    $script:ShopSystemState.PlayerInventory.CurrentWeight -= $removedWeight
    
    if ($invItem.Quantity -le 0) {
        $script:ShopSystemState.PlayerInventory.Items.Remove($ItemId)
    }
    
    return @{
        Success = $true
        ItemId = $ItemId
        RemovedQuantity = $Quantity
        RemainingQuantity = [math]::Max(0, $invItem.Quantity)
        CurrentWeight = $script:ShopSystemState.PlayerInventory.CurrentWeight
    }
}

function Test-HasItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [int]$Quantity = 1
    )
    
    if (-not $script:ShopSystemState.PlayerInventory.Items.ContainsKey($ItemId)) {
        return $false
    }
    
    return $script:ShopSystemState.PlayerInventory.Items[$ItemId].Quantity -ge $Quantity
}

function Get-PlayerCurrency {
    [CmdletBinding()]
    param()
    
    return $script:ShopSystemState.PlayerInventory.Currency
}

function Add-PlayerCurrency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Amount,
        
        [string]$Source = 'Unknown'
    )
    
    $script:ShopSystemState.PlayerInventory.Currency += $Amount
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'CurrencyChanged' -Data @{
            Amount = $Amount
            Source = $Source
            NewBalance = $script:ShopSystemState.PlayerInventory.Currency
        }
    }
    
    return $script:ShopSystemState.PlayerInventory.Currency
}

function Remove-PlayerCurrency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Amount,
        
        [string]$Reason = 'Unknown'
    )
    
    if ($script:ShopSystemState.PlayerInventory.Currency -lt $Amount) {
        return @{
            Success = $false
            Reason = 'Insufficient funds'
            Available = $script:ShopSystemState.PlayerInventory.Currency
            Required = $Amount
        }
    }
    
    $script:ShopSystemState.PlayerInventory.Currency -= $Amount
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'CurrencyChanged' -Data @{
            Amount = -$Amount
            Reason = $Reason
            NewBalance = $script:ShopSystemState.PlayerInventory.Currency
        }
    }
    
    return @{
        Success = $true
        Spent = $Amount
        NewBalance = $script:ShopSystemState.PlayerInventory.Currency
    }
}

function Set-PlayerCurrency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Amount
    )
    
    $oldAmount = $script:ShopSystemState.PlayerInventory.Currency
    $script:ShopSystemState.PlayerInventory.Currency = [math]::Max(0, $Amount)
    
    return @{
        OldBalance = $oldAmount
        NewBalance = $script:ShopSystemState.PlayerInventory.Currency
    }
}

function Set-InventoryCapacity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$MaxWeight
    )
    
    $script:ShopSystemState.PlayerInventory.MaxWeight = $MaxWeight
    
    return @{
        MaxWeight = $MaxWeight
        CurrentWeight = $script:ShopSystemState.PlayerInventory.CurrentWeight
        Available = $MaxWeight - $script:ShopSystemState.PlayerInventory.CurrentWeight
    }
}
#endregion

#region Transactions
function Invoke-Purchase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [int]$Quantity = 1,
        
        [string]$PlayerStanding = 'Neutral'
    )
    
    $shop = $script:ShopSystemState.Shops[$ShopId]
    if (-not $shop) {
        return @{
            Success = $false
            Reason = 'Shop not found'
        }
    }
    
    if (-not $shop.IsOpen) {
        return @{
            Success = $false
            Reason = 'Shop is closed'
        }
    }
    
    # Check shop has item in stock
    if (-not $shop.Inventory.ContainsKey($ItemId)) {
        return @{
            Success = $false
            Reason = 'Item not in stock'
        }
    }
    
    if ($shop.Inventory[$ItemId].Quantity -lt $Quantity) {
        return @{
            Success = $false
            Reason = 'Insufficient stock'
            Available = $shop.Inventory[$ItemId].Quantity
        }
    }
    
    $item = $script:ShopSystemState.ItemCatalog[$ItemId]
    
    # Check access based on standing
    $minStanding = $shop.VendorInfo.MinStanding
    $standingOrder = @('Hostile', 'Unfriendly', 'Neutral', 'Friendly', 'Allied')
    $minIndex = $standingOrder.IndexOf($minStanding)
    $playerIndex = $standingOrder.IndexOf($PlayerStanding)
    
    if ($playerIndex -lt $minIndex) {
        return @{
            Success = $false
            Reason = "Standing too low"
            RequiredStanding = $minStanding
            CurrentStanding = $PlayerStanding
        }
    }
    
    # Calculate price
    $totalPrice = Get-ItemPrice -ShopId $ShopId -ItemId $ItemId -PlayerStanding $PlayerStanding -Quantity $Quantity
    
    # Check player can afford
    if ($script:ShopSystemState.PlayerInventory.Currency -lt $totalPrice) {
        return @{
            Success = $false
            Reason = 'Insufficient funds'
            Price = $totalPrice
            Available = $script:ShopSystemState.PlayerInventory.Currency
        }
    }
    
    # Check player inventory capacity
    $addResult = Add-PlayerInventory -ItemId $ItemId -Quantity $Quantity -Source "Purchased from $($shop.Name)"
    if (-not $addResult.Success) {
        return @{
            Success = $false
            Reason = $addResult.Reason
            Details = $addResult
        }
    }
    
    # Complete transaction
    $script:ShopSystemState.PlayerInventory.Currency -= $totalPrice
    Remove-ShopInventory -ShopId $ShopId -ItemId $ItemId -Quantity $Quantity | Out-Null
    $shop.TotalSales += $totalPrice
    
    # Record transaction
    $transaction = @{
        TransactionId = [guid]::NewGuid().ToString()
        Type = 'Purchase'
        ShopId = $ShopId
        ShopName = $shop.Name
        ItemId = $ItemId
        ItemName = $item.Name
        Quantity = $Quantity
        UnitPrice = [math]::Ceiling($totalPrice / $Quantity)
        TotalPrice = $totalPrice
        PlayerStanding = $PlayerStanding
        Timestamp = Get-Date
    }
    $script:ShopSystemState.Transactions += $transaction
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'ItemPurchased' -Data @{
            ShopId = $ShopId
            ItemId = $ItemId
            ItemName = $item.Name
            Quantity = $Quantity
            TotalPrice = $totalPrice
        }
    }
    
    return @{
        Success = $true
        Transaction = $transaction
        NewBalance = $script:ShopSystemState.PlayerInventory.Currency
        Message = "Purchased $Quantity x $($item.Name) for ₡$totalPrice"
    }
}

function Invoke-Sale {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [Parameter(Mandatory)]
        [string]$ItemId,
        
        [int]$Quantity = 1,
        
        [string]$PlayerStanding = 'Neutral'
    )
    
    $shop = $script:ShopSystemState.Shops[$ShopId]
    if (-not $shop) {
        return @{
            Success = $false
            Reason = 'Shop not found'
        }
    }
    
    if (-not $shop.IsOpen) {
        return @{
            Success = $false
            Reason = 'Shop is closed'
        }
    }
    
    # Check player has item
    if (-not (Test-HasItem -ItemId $ItemId -Quantity $Quantity)) {
        return @{
            Success = $false
            Reason = 'Item not in inventory or insufficient quantity'
        }
    }
    
    $item = $script:ShopSystemState.ItemCatalog[$ItemId]
    if (-not $item) {
        return @{
            Success = $false
            Reason = 'Item not recognized'
        }
    }
    
    # Check if shop accepts this item category
    if ($item.Category -notin $shop.VendorInfo.ItemCategories) {
        return @{
            Success = $false
            Reason = "This vendor doesn't buy $($item.Category) items"
            AcceptedCategories = $shop.VendorInfo.ItemCategories
        }
    }
    
    # Check legality
    if (-not $item.IsLegal -and -not $shop.VendorInfo.IllegalItems) {
        return @{
            Success = $false
            Reason = 'This vendor does not buy illegal items'
        }
    }
    
    # Calculate sell price
    $totalPrice = Get-ItemSellPrice -ShopId $ShopId -ItemId $ItemId -PlayerStanding $PlayerStanding -Quantity $Quantity
    
    # Complete transaction
    $removeResult = Remove-PlayerInventory -ItemId $ItemId -Quantity $Quantity
    if (-not $removeResult.Success) {
        return @{
            Success = $false
            Reason = $removeResult.Reason
        }
    }
    
    $script:ShopSystemState.PlayerInventory.Currency += $totalPrice
    Add-ShopInventory -ShopId $ShopId -ItemId $ItemId -Quantity $Quantity | Out-Null
    $shop.TotalPurchases += $totalPrice
    
    # Record transaction
    $transaction = @{
        TransactionId = [guid]::NewGuid().ToString()
        Type = 'Sale'
        ShopId = $ShopId
        ShopName = $shop.Name
        ItemId = $ItemId
        ItemName = $item.Name
        Quantity = $Quantity
        UnitPrice = [math]::Floor($totalPrice / $Quantity)
        TotalPrice = $totalPrice
        PlayerStanding = $PlayerStanding
        Timestamp = Get-Date
    }
    $script:ShopSystemState.Transactions += $transaction
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'ItemSold' -Data @{
            ShopId = $ShopId
            ItemId = $ItemId
            ItemName = $item.Name
            Quantity = $Quantity
            TotalPrice = $totalPrice
        }
    }
    
    return @{
        Success = $true
        Transaction = $transaction
        NewBalance = $script:ShopSystemState.PlayerInventory.Currency
        Message = "Sold $Quantity x $($item.Name) for ₡$totalPrice"
    }
}

function Get-TransactionHistory {
    [CmdletBinding()]
    param(
        [string]$ShopId,
        [ValidateSet('Purchase', 'Sale', 'All')]
        [string]$Type = 'All',
        [int]$Limit = 50
    )
    
    $transactions = $script:ShopSystemState.Transactions
    
    if ($ShopId) {
        $transactions = $transactions | Where-Object { $_.ShopId -eq $ShopId }
    }
    
    if ($Type -ne 'All') {
        $transactions = $transactions | Where-Object { $_.Type -eq $Type }
    }
    
    return @($transactions | Select-Object -Last $Limit)
}
#endregion

#region Access Control
function Test-CanAccessShop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShopId,
        
        [Parameter(Mandatory)]
        [string]$PlayerStanding
    )
    
    $shop = $script:ShopSystemState.Shops[$ShopId]
    if (-not $shop) {
        return @{
            CanAccess = $false
            Reason = 'Shop not found'
        }
    }
    
    if (-not $shop.IsOpen) {
        return @{
            CanAccess = $false
            Reason = 'Shop is closed'
        }
    }
    
    $standingOrder = @('Hostile', 'Unfriendly', 'Neutral', 'Friendly', 'Allied')
    $minIndex = $standingOrder.IndexOf($shop.VendorInfo.MinStanding)
    $playerIndex = $standingOrder.IndexOf($PlayerStanding)
    
    if ($playerIndex -lt $minIndex) {
        return @{
            CanAccess = $false
            Reason = 'Standing too low'
            RequiredStanding = $shop.VendorInfo.MinStanding
            CurrentStanding = $PlayerStanding
        }
    }
    
    return @{
        CanAccess = $true
        Shop = $shop.Name
        VendorType = $shop.VendorType
        PriceModifier = $script:StandingPriceModifiers[$PlayerStanding]
    }
}

function Get-AvailableShops {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlayerStanding,
        
        [string]$LocationId
    )
    
    $shops = Get-Shop -OpenOnly
    
    if ($LocationId) {
        $shops = $shops | Where-Object { $_.LocationId -eq $LocationId }
    }
    
    $available = @()
    foreach ($shop in $shops) {
        $access = Test-CanAccessShop -ShopId $shop.ShopId -PlayerStanding $PlayerStanding
        if ($access.CanAccess) {
            $available += @{
                ShopId = $shop.ShopId
                Name = $shop.Name
                VendorType = $shop.VendorType
                PriceModifier = $access.PriceModifier
                ItemCount = $shop.Inventory.Count
            }
        }
    }
    
    return $available
}
#endregion

#region Event Processing
function Process-ShopEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('CombatEnded', 'PoliceRaid', 'FactionConflict', 'Restock', 'ShopRobbed')]
        [string]$EventType,
        
        [hashtable]$EventData = @{}
    )
    
    $results = @()
    
    switch ($EventType) {
        'CombatEnded' {
            # After major combat, weapon/ammo prices increase
            Set-SupplyModifier -Category 'Weapons' -Modifier 1.3 -Reason 'Post-combat demand'
            Set-SupplyModifier -Category 'Medical' -Modifier 1.2 -Reason 'Post-combat demand'
            $results += @{ Action = 'SupplyModified'; Categories = @('Weapons', 'Medical') }
        }
        
        'PoliceRaid' {
            # Black market prices spike
            Set-SupplyModifier -Category 'Contraband' -Modifier 1.5 -Reason 'Police raid'
            Set-SupplyModifier -Category 'Drugs' -Modifier 1.8 -Reason 'Police raid'
            
            # Close affected shops temporarily
            if ($EventData.LocationId) {
                $shops = Get-Shop -LocationId $EventData.LocationId | Where-Object { 
                    $_.VendorType -in @('BlackMarket', 'ChopShop') 
                }
                foreach ($shop in $shops) {
                    Set-ShopOpen -ShopId $shop.ShopId -IsOpen $false | Out-Null
                    $results += @{ Action = 'ShopClosed'; ShopId = $shop.ShopId; Reason = 'Police raid' }
                }
            }
        }
        
        'FactionConflict' {
            # Affected faction shops may close or change prices
            if ($EventData.FactionId) {
                $shops = Get-Shop -FactionId $EventData.FactionId
                foreach ($shop in $shops) {
                    $shop.MarkupModifier = 1.5
                    $results += @{ Action = 'PriceIncrease'; ShopId = $shop.ShopId; Reason = 'Faction conflict' }
                }
            }
        }
        
        'Restock' {
            # Reset supply modifiers
            $script:ShopSystemState.SupplyModifiers = @{}
            $results += @{ Action = 'SupplyNormalized' }
        }
        
        'ShopRobbed' {
            if ($EventData.ShopId) {
                $shop = $script:ShopSystemState.Shops[$EventData.ShopId]
                if ($shop) {
                    # Reduce inventory
                    $shop.Inventory = @{}
                    Set-ShopOpen -ShopId $EventData.ShopId -IsOpen $false | Out-Null
                    $results += @{ Action = 'ShopRobbed'; ShopId = $EventData.ShopId }
                }
            }
        }
    }
    
    return @{
        EventType = $EventType
        Results = $results
        Timestamp = Get-Date
    }
}
#endregion

#region State Export/Import
function Export-ShopData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    $exportData = @{
        Version = '1.0'
        ExportedAt = Get-Date
        Shops = $script:ShopSystemState.Shops
        ItemCatalog = $script:ShopSystemState.ItemCatalog
        PlayerInventory = $script:ShopSystemState.PlayerInventory
        Transactions = $script:ShopSystemState.Transactions
        SupplyModifiers = $script:ShopSystemState.SupplyModifiers
        Configuration = $script:ShopSystemState.Configuration
    }
    
    $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath
    
    return @{
        Success = $true
        FilePath = $FilePath
        ShopCount = $script:ShopSystemState.Shops.Count
        ItemCount = $script:ShopSystemState.ItemCatalog.Count
    }
}

function Import-ShopData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $importData = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
    
    # Convert PSCustomObject back to hashtables
    $script:ShopSystemState.Shops = @{}
    foreach ($prop in $importData.Shops.PSObject.Properties) {
        $script:ShopSystemState.Shops[$prop.Name] = @{}
        foreach ($p in $prop.Value.PSObject.Properties) {
            $script:ShopSystemState.Shops[$prop.Name][$p.Name] = $p.Value
        }
    }
    
    $script:ShopSystemState.ItemCatalog = @{}
    foreach ($prop in $importData.ItemCatalog.PSObject.Properties) {
        $script:ShopSystemState.ItemCatalog[$prop.Name] = @{}
        foreach ($p in $prop.Value.PSObject.Properties) {
            $script:ShopSystemState.ItemCatalog[$prop.Name][$p.Name] = $p.Value
        }
    }
    
    $script:ShopSystemState.PlayerInventory = @{
        Items = @{}
        Currency = $importData.PlayerInventory.Currency
        MaxWeight = $importData.PlayerInventory.MaxWeight
        CurrentWeight = $importData.PlayerInventory.CurrentWeight
    }
    foreach ($prop in $importData.PlayerInventory.Items.PSObject.Properties) {
        $script:ShopSystemState.PlayerInventory.Items[$prop.Name] = @{}
        foreach ($p in $prop.Value.PSObject.Properties) {
            $script:ShopSystemState.PlayerInventory.Items[$prop.Name][$p.Name] = $p.Value
        }
    }
    
    $script:ShopSystemState.Transactions = @($importData.Transactions)
    $script:ShopSystemState.SupplyModifiers = @{}
    if ($importData.SupplyModifiers) {
        foreach ($prop in $importData.SupplyModifiers.PSObject.Properties) {
            $script:ShopSystemState.SupplyModifiers[$prop.Name] = $prop.Value
        }
    }
    
    $script:ShopSystemState.Initialized = $true
    
    return @{
        Success = $true
        ShopCount = $script:ShopSystemState.Shops.Count
        ItemCount = $script:ShopSystemState.ItemCatalog.Count
        PlayerCurrency = $script:ShopSystemState.PlayerInventory.Currency
    }
}
#endregion

#region Utility Functions
function Get-VendorTypes {
    [CmdletBinding()]
    param()
    
    return $script:VendorTypes.Clone()
}

function Get-RarityLevels {
    [CmdletBinding()]
    param()
    
    return $script:RarityLevels.Clone()
}

function Get-ItemCategories {
    [CmdletBinding()]
    param()
    
    return $script:ItemCategories.Clone()
}

function Get-StandingPriceModifiers {
    [CmdletBinding()]
    param()
    
    return $script:StandingPriceModifiers.Clone()
}
#endregion

# Export all functions
Export-ModuleMember -Function @(
    # Initialization
    'Initialize-ShopSystem'
    'Get-ShopSystemState'
    
    # Item Catalog
    'New-Item'
    'Get-Item'
    'Remove-Item'
    
    # Shop Management
    'New-Shop'
    'Get-Shop'
    'Set-ShopOpen'
    'Remove-Shop'
    
    # Shop Inventory
    'Add-ShopInventory'
    'Remove-ShopInventory'
    'Get-ShopInventory'
    'Restock-Shop'
    
    # Pricing
    'Get-ItemPrice'
    'Get-ItemSellPrice'
    'Set-SupplyModifier'
    'Get-SupplyModifier'
    
    # Player Inventory
    'Get-PlayerInventory'
    'Add-PlayerInventory'
    'Remove-PlayerInventory'
    'Test-HasItem'
    'Get-PlayerCurrency'
    'Add-PlayerCurrency'
    'Remove-PlayerCurrency'
    'Set-PlayerCurrency'
    'Set-InventoryCapacity'
    
    # Transactions
    'Invoke-Purchase'
    'Invoke-Sale'
    'Get-TransactionHistory'
    
    # Access Control
    'Test-CanAccessShop'
    'Get-AvailableShops'
    
    # Events
    'Process-ShopEvent'
    
    # Export/Import
    'Export-ShopData'
    'Import-ShopData'
    
    # Utilities
    'Get-VendorTypes'
    'Get-RarityLevels'
    'Get-ItemCategories'
    'Get-StandingPriceModifiers'
)
