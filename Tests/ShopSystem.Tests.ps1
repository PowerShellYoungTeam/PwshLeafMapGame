# ShopSystem Module Tests
# Comprehensive tests for shop, vendor, inventory, and trading functionality

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\Modules\ShopSystem\ShopSystem.psm1'
    Import-Module $modulePath -Force
}

Describe "ShopSystem Module" {
    
    Describe "Initialize-ShopSystem" {
        It "Should initialize successfully with default configuration" {
            $result = Initialize-ShopSystem
            $result.Initialized | Should -BeTrue
            $result.ModuleName | Should -Be 'ShopSystem'
            $result.Configuration.StartingCurrency | Should -Be 1000
        }
        
        It "Should return vendor types" {
            $result = Initialize-ShopSystem
            $result.VendorTypes | Should -Contain 'BlackMarket'
            $result.VendorTypes | Should -Contain 'CorporateStore'
            $result.VendorTypes | Should -Contain 'Fixer'
            $result.VendorTypes | Should -Contain 'ChopShop'
        }
        
        It "Should return item categories" {
            $result = Initialize-ShopSystem
            $result.ItemCategories | Should -Contain 'Weapons'
            $result.ItemCategories | Should -Contain 'Cyberware'
            $result.ItemCategories | Should -Contain 'Medical'
        }
        
        It "Should return rarity levels" {
            $result = Initialize-ShopSystem
            $result.RarityLevels | Should -Contain 'Common'
            $result.RarityLevels | Should -Contain 'Rare'
            $result.RarityLevels | Should -Contain 'Legendary'
        }
        
        It "Should accept custom configuration" {
            $config = @{
                StartingCurrency = 5000
                MaxInventoryWeight = 200
            }
            $result = Initialize-ShopSystem -Configuration $config
            $result.Configuration.StartingCurrency | Should -Be 5000
            $result.Configuration.MaxInventoryWeight | Should -Be 200
        }
    }
    
    Describe "Item Catalog" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
        }
        
        Describe "New-Item" {
            It "Should create a weapon item" {
                $item = New-Item `
                    -ItemId 'pistol_9mm' `
                    -Name '9mm Pistol' `
                    -Category 'Weapons' `
                    -BasePrice 500
                
                $item.ItemId | Should -Be 'pistol_9mm'
                $item.Name | Should -Be '9mm Pistol'
                $item.Category | Should -Be 'Weapons'
                $item.BasePrice | Should -Be 500
                $item.Rarity | Should -Be 'Common'
            }
            
            It "Should create a rare cyberware item" {
                $item = New-Item `
                    -ItemId 'neural_interface' `
                    -Name 'Neural Interface' `
                    -Category 'Cyberware' `
                    -BasePrice 10000 `
                    -Rarity 'Rare' `
                    -Description 'Enhances cognitive functions'
                
                $item.Rarity | Should -Be 'Rare'
                $item.Description | Should -Be 'Enhances cognitive functions'
                $item.RarityInfo.PriceModifier | Should -Be 5.0
            }
            
            It "Should create an illegal item" {
                $item = New-Item `
                    -ItemId 'synth_drugs' `
                    -Name 'Synthetic Stimulants' `
                    -Category 'Drugs' `
                    -BasePrice 200 `
                    -IsLegal $false
                
                $item.IsLegal | Should -BeFalse
            }
            
            It "Should use default weight from category" {
                $item = New-Item `
                    -ItemId 'test_weapon' `
                    -Name 'Test Weapon' `
                    -Category 'Weapons' `
                    -BasePrice 100
                
                $item.Weight | Should -Be 3.0  # Default weapon weight
            }
            
            It "Should allow custom weight" {
                $item = New-Item `
                    -ItemId 'heavy_weapon' `
                    -Name 'Heavy Weapon' `
                    -Category 'Weapons' `
                    -BasePrice 2000 `
                    -Weight 10.0
                
                $item.Weight | Should -Be 10.0
            }
            
            It "Should throw on duplicate item ID" {
                New-Item -ItemId 'dupe_test' -Name 'First' -Category 'Junk' -BasePrice 10
                { New-Item -ItemId 'dupe_test' -Name 'Second' -Category 'Junk' -BasePrice 20 } | Should -Throw
            }
        }
        
        Describe "Get-Item" {
            BeforeEach {
                New-Item -ItemId 'test_weapon' -Name 'Test Weapon' -Category 'Weapons' -BasePrice 500 | Out-Null
                New-Item -ItemId 'test_armor' -Name 'Test Armor' -Category 'Armor' -BasePrice 300 | Out-Null
                New-Item -ItemId 'rare_weapon' -Name 'Rare Weapon' -Category 'Weapons' -BasePrice 2000 -Rarity 'Rare' | Out-Null
                New-Item -ItemId 'illegal_item' -Name 'Contraband' -Category 'Contraband' -BasePrice 100 -IsLegal $false | Out-Null
            }
            
            It "Should get item by ID" {
                $item = Get-Item -ItemId 'test_weapon'
                $item.Name | Should -Be 'Test Weapon'
            }
            
            It "Should get all items" {
                $items = Get-Item
                $items.Count | Should -BeGreaterOrEqual 4
            }
            
            It "Should filter by category" {
                $weapons = Get-Item -Category 'Weapons'
                $weapons | ForEach-Object { $_.Category | Should -Be 'Weapons' }
                $weapons.Count | Should -Be 2
            }
            
            It "Should filter by rarity" {
                $rareItems = Get-Item -Rarity 'Rare'
                $rareItems | ForEach-Object { $_.Rarity | Should -Be 'Rare' }
            }
            
            It "Should filter illegal items only" {
                $illegal = Get-Item -IllegalOnly
                $illegal | ForEach-Object { $_.IsLegal | Should -BeFalse }
            }
            
            It "Should filter legal items only" {
                $legal = Get-Item -LegalOnly
                $legal | ForEach-Object { $_.IsLegal | Should -BeTrue }
            }
        }
        
        Describe "Remove-Item" {
            It "Should remove an existing item" {
                New-Item -ItemId 'to_remove' -Name 'Removable' -Category 'Junk' -BasePrice 1 | Out-Null
                $result = Remove-Item -ItemId 'to_remove'
                $result | Should -BeTrue
                Get-Item -ItemId 'to_remove' | Should -BeNullOrEmpty
            }
            
            It "Should return false for non-existent item" {
                $result = Remove-Item -ItemId 'nonexistent'
                $result | Should -BeFalse
            }
        }
    }
    
    Describe "Shop Management" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
        }
        
        Describe "New-Shop" {
            It "Should create a Black Market shop" {
                $shop = New-Shop `
                    -ShopId 'back_alley_market' `
                    -Name 'Back Alley Market' `
                    -VendorType 'BlackMarket'
                
                $shop.ShopId | Should -Be 'back_alley_market'
                $shop.VendorType | Should -Be 'BlackMarket'
                $shop.VendorInfo.RequiresReputation | Should -BeTrue
                $shop.IsOpen | Should -BeTrue
            }
            
            It "Should create a Corporate Store" {
                $shop = New-Shop `
                    -ShopId 'corpo_store' `
                    -Name 'OmniMart' `
                    -VendorType 'CorporateStore'
                
                $shop.VendorInfo.DefaultMarkup | Should -Be 1.5
                $shop.VendorInfo.MinStanding | Should -Be 'Hostile'
            }
            
            It "Should create a Fixer shop" {
                $shop = New-Shop `
                    -ShopId 'fixers_den' `
                    -Name "Fixer's Den" `
                    -VendorType 'Fixer' `
                    -FactionId 'underground_net'
                
                $shop.FactionId | Should -Be 'underground_net'
                $shop.VendorInfo.ItemCategories | Should -Contain 'Intel'
            }
            
            It "Should create a shop with custom markup" {
                $shop = New-Shop `
                    -ShopId 'discount_store' `
                    -Name 'Discount Store' `
                    -VendorType 'StreetVendor' `
                    -MarkupModifier 0.8
                
                $shop.MarkupModifier | Should -Be 0.8
            }
            
            It "Should throw on duplicate shop ID" {
                New-Shop -ShopId 'dupe_shop' -Name 'First' -VendorType 'StreetVendor'
                { New-Shop -ShopId 'dupe_shop' -Name 'Second' -VendorType 'StreetVendor' } | Should -Throw
            }
        }
        
        Describe "Get-Shop" {
            BeforeEach {
                New-Shop -ShopId 'shop1' -Name 'Shop 1' -VendorType 'StreetVendor' -LocationId 'downtown' | Out-Null
                New-Shop -ShopId 'shop2' -Name 'Shop 2' -VendorType 'BlackMarket' -LocationId 'slums' | Out-Null
                New-Shop -ShopId 'shop3' -Name 'Shop 3' -VendorType 'StreetVendor' -LocationId 'downtown' -IsOpen $false | Out-Null
            }
            
            It "Should get shop by ID" {
                $shop = Get-Shop -ShopId 'shop1'
                $shop.Name | Should -Be 'Shop 1'
            }
            
            It "Should get all shops" {
                $shops = Get-Shop
                $shops.Count | Should -Be 3
            }
            
            It "Should filter by vendor type" {
                $streetVendors = Get-Shop -VendorType 'StreetVendor'
                $streetVendors.Count | Should -Be 2
            }
            
            It "Should filter by location" {
                $downtown = Get-Shop -LocationId 'downtown'
                $downtown.Count | Should -Be 2
            }
            
            It "Should filter open shops only" {
                $open = Get-Shop -OpenOnly
                $open.Count | Should -Be 2
            }
        }
        
        Describe "Set-ShopOpen" {
            It "Should close a shop" {
                New-Shop -ShopId 'closeable' -Name 'Closeable Shop' -VendorType 'StreetVendor' | Out-Null
                $result = Set-ShopOpen -ShopId 'closeable' -IsOpen $false
                $result | Should -BeTrue
                (Get-Shop -ShopId 'closeable').IsOpen | Should -BeFalse
            }
            
            It "Should reopen a shop" {
                New-Shop -ShopId 'reopenable' -Name 'Reopenable' -VendorType 'StreetVendor' -IsOpen $false | Out-Null
                Set-ShopOpen -ShopId 'reopenable' -IsOpen $true
                (Get-Shop -ShopId 'reopenable').IsOpen | Should -BeTrue
            }
        }
        
        Describe "Remove-Shop" {
            It "Should remove a shop" {
                New-Shop -ShopId 'removable' -Name 'Removable' -VendorType 'StreetVendor' | Out-Null
                $result = Remove-Shop -ShopId 'removable'
                $result | Should -BeTrue
                Get-Shop -ShopId 'removable' | Should -BeNullOrEmpty
            }
        }
    }
    
    Describe "Shop Inventory" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
            New-Item -ItemId 'pistol' -Name 'Pistol' -Category 'Weapons' -BasePrice 500 | Out-Null
            New-Item -ItemId 'medkit' -Name 'Medkit' -Category 'Medical' -BasePrice 100 | Out-Null
            New-Item -ItemId 'stim' -Name 'Stimulant' -Category 'Consumables' -BasePrice 50 | Out-Null
            New-Shop -ShopId 'test_shop' -Name 'Test Shop' -VendorType 'StreetVendor' | Out-Null
        }
        
        Describe "Add-ShopInventory" {
            It "Should add item to shop inventory" {
                $result = Add-ShopInventory -ShopId 'test_shop' -ItemId 'medkit' -Quantity 10
                $result.Quantity | Should -Be 10
                $result.Item.Name | Should -Be 'Medkit'
            }
            
            It "Should stack quantities" {
                Add-ShopInventory -ShopId 'test_shop' -ItemId 'stim' -Quantity 5 | Out-Null
                Add-ShopInventory -ShopId 'test_shop' -ItemId 'stim' -Quantity 3 | Out-Null
                $inv = Get-ShopInventory -ShopId 'test_shop'
                ($inv | Where-Object { $_.ItemId -eq 'stim' }).Quantity | Should -Be 8
            }
        }
        
        Describe "Get-ShopInventory" {
            It "Should return shop inventory" {
                Add-ShopInventory -ShopId 'test_shop' -ItemId 'pistol' -Quantity 3 | Out-Null
                Add-ShopInventory -ShopId 'test_shop' -ItemId 'medkit' -Quantity 10 | Out-Null
                $inv = Get-ShopInventory -ShopId 'test_shop'
                $inv.Count | Should -BeGreaterOrEqual 2
            }
            
            It "Should filter by category" {
                Add-ShopInventory -ShopId 'test_shop' -ItemId 'pistol' -Quantity 3 | Out-Null
                Add-ShopInventory -ShopId 'test_shop' -ItemId 'medkit' -Quantity 10 | Out-Null
                $weapons = Get-ShopInventory -ShopId 'test_shop' -Category 'Weapons'
                $weapons | ForEach-Object { $_.Category | Should -Be 'Weapons' }
                $weapons.Count | Should -BeGreaterOrEqual 1
            }
            
            It "Should include prices when requested" {
                Add-ShopInventory -ShopId 'test_shop' -ItemId 'medkit' -Quantity 5 | Out-Null
                $inv = Get-ShopInventory -ShopId 'test_shop' -WithPrices
                $inv.Count | Should -BeGreaterOrEqual 1
                ($inv | Where-Object { $_.Price -gt 0 }).Count | Should -BeGreaterOrEqual 1
            }
        }
        
        Describe "Remove-ShopInventory" {
            It "Should remove items from inventory" {
                Add-ShopInventory -ShopId 'test_shop' -ItemId 'medkit' -Quantity 10 | Out-Null
                Remove-ShopInventory -ShopId 'test_shop' -ItemId 'medkit' -Quantity 3
                $inv = Get-ShopInventory -ShopId 'test_shop'
                ($inv | Where-Object { $_.ItemId -eq 'medkit' }).Quantity | Should -Be 7
            }
            
            It "Should remove item entry when quantity reaches zero" {
                Add-ShopInventory -ShopId 'test_shop' -ItemId 'stim' -Quantity 5 | Out-Null
                Remove-ShopInventory -ShopId 'test_shop' -ItemId 'stim' -Quantity 5
                $inv = Get-ShopInventory -ShopId 'test_shop'
                $inv | Where-Object { $_.ItemId -eq 'stim' } | Should -BeNullOrEmpty
            }
        }
        
        Describe "Restock-Shop" {
            It "Should restock shop with defined items" {
                $stock = @{
                    'medkit' = 20
                    'stim' = 50
                }
                $result = Restock-Shop -ShopId 'test_shop' -StockDefinition $stock
                $result.ItemCount | Should -Be 2
            }
            
            It "Should clear existing inventory when specified" {
                # Create a fresh shop for this isolated test with unique ID
                $uniqueShopId = "restock_clear_test_$(Get-Random)"
                New-Shop -ShopId $uniqueShopId -Name 'Restock Test' -VendorType 'CorporateStore' | Out-Null
                Add-ShopInventory -ShopId $uniqueShopId -ItemId 'pistol' -Quantity 5 | Out-Null
                $stock = @{ 'medkit' = 10 }
                Restock-Shop -ShopId $uniqueShopId -StockDefinition $stock -ClearExisting
                $inv = Get-ShopInventory -ShopId $uniqueShopId
                # After clearing and restocking, should only have medkit
                $inv.Count | Should -Be 1
                $inv[0].ItemId | Should -Be 'medkit'
            }
        }
    }
    
    Describe "Pricing System" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
            New-Item -ItemId 'test_item' -Name 'Test Item' -Category 'Consumables' -BasePrice 100 | Out-Null
            New-Shop -ShopId 'corp_store' -Name 'Corp Store' -VendorType 'CorporateStore' | Out-Null
            New-Shop -ShopId 'street_vendor' -Name 'Street Vendor' -VendorType 'StreetVendor' | Out-Null
            Add-ShopInventory -ShopId 'corp_store' -ItemId 'test_item' -Quantity 10 | Out-Null
            Add-ShopInventory -ShopId 'street_vendor' -ItemId 'test_item' -Quantity 10 | Out-Null
        }
        
        Describe "Get-ItemPrice" {
            It "Should apply vendor markup" {
                $corpPrice = Get-ItemPrice -ShopId 'corp_store' -ItemId 'test_item'
                $streetPrice = Get-ItemPrice -ShopId 'street_vendor' -ItemId 'test_item'
                $corpPrice | Should -BeGreaterThan $streetPrice  # Corp has 1.5x markup vs 1.0x
            }
            
            It "Should apply standing modifier - Hostile pays more" {
                $hostilePrice = Get-ItemPrice -ShopId 'street_vendor' -ItemId 'test_item' -PlayerStanding 'Hostile'
                $neutralPrice = Get-ItemPrice -ShopId 'street_vendor' -ItemId 'test_item' -PlayerStanding 'Neutral'
                $hostilePrice | Should -BeGreaterThan $neutralPrice
            }
            
            It "Should apply standing modifier - Allied pays less" {
                $alliedPrice = Get-ItemPrice -ShopId 'street_vendor' -ItemId 'test_item' -PlayerStanding 'Allied'
                $neutralPrice = Get-ItemPrice -ShopId 'street_vendor' -ItemId 'test_item' -PlayerStanding 'Neutral'
                $alliedPrice | Should -BeLessThan $neutralPrice
            }
            
            It "Should multiply price by quantity" {
                $singlePrice = Get-ItemPrice -ShopId 'street_vendor' -ItemId 'test_item' -Quantity 1
                $multiPrice = Get-ItemPrice -ShopId 'street_vendor' -ItemId 'test_item' -Quantity 5
                $multiPrice | Should -Be ($singlePrice * 5)
            }
        }
        
        Describe "Get-ItemSellPrice" {
            It "Should be less than buy price" {
                $buyPrice = Get-ItemPrice -ShopId 'street_vendor' -ItemId 'test_item'
                $sellPrice = Get-ItemSellPrice -ShopId 'street_vendor' -ItemId 'test_item'
                $sellPrice | Should -BeLessThan $buyPrice
            }
            
            It "Should give better price for friendly standing" {
                $neutralSell = Get-ItemSellPrice -ShopId 'street_vendor' -ItemId 'test_item' -PlayerStanding 'Neutral'
                $friendlySell = Get-ItemSellPrice -ShopId 'street_vendor' -ItemId 'test_item' -PlayerStanding 'Friendly'
                $friendlySell | Should -BeGreaterThan $neutralSell
            }
        }
        
        Describe "Supply Modifiers" {
            It "Should set supply modifier" {
                $result = Set-SupplyModifier -Category 'Weapons' -Modifier 1.5 -Reason 'Combat'
                $result.Category | Should -Be 'Weapons'
                $result.Modifier | Should -Be 1.5
            }
            
            It "Should get supply modifier" {
                Set-SupplyModifier -Category 'Medical' -Modifier 1.3 | Out-Null
                $mod = Get-SupplyModifier -Category 'Medical'
                $mod | Should -Be 1.3
            }
            
            It "Should affect prices when dynamic pricing enabled" {
                Set-SupplyModifier -Category 'Consumables' -Modifier 1.5 | Out-Null
                $normalPrice = 100  # Base price without modifier
                $currentPrice = Get-ItemPrice -ShopId 'street_vendor' -ItemId 'test_item'
                $currentPrice | Should -BeGreaterThan $normalPrice
            }
            
            It "Should clamp modifier to valid range" {
                Set-SupplyModifier -Category 'Test' -Modifier 10.0 | Out-Null  # Should clamp to 3.0
                $mod = Get-SupplyModifier -Category 'Test'
                $mod | Should -Be 3.0
            }
        }
    }
    
    Describe "Player Inventory" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
            New-Item -ItemId 'light_item' -Name 'Light Item' -Category 'Consumables' -BasePrice 50 -Weight 0.5 | Out-Null
            New-Item -ItemId 'heavy_item' -Name 'Heavy Item' -Category 'Weapons' -BasePrice 500 -Weight 10.0 | Out-Null
            New-Item -ItemId 'unique_item' -Name 'Unique Item' -Category 'Tools' -BasePrice 1000 | Out-Null
        }
        
        Describe "Add-PlayerInventory" {
            It "Should add item to inventory" {
                $result = Add-PlayerInventory -ItemId 'light_item' -Quantity 5
                $result.Success | Should -BeTrue
                $result.Quantity | Should -Be 5
            }
            
            It "Should track weight" {
                Add-PlayerInventory -ItemId 'light_item' -Quantity 10 | Out-Null  # 0.5 * 10 = 5
                $inv = Get-PlayerInventory -Summary
                $inv.CurrentWeight | Should -Be 5.0
            }
            
            It "Should fail when over weight capacity" {
                Set-InventoryCapacity -MaxWeight 5.0 | Out-Null
                $result = Add-PlayerInventory -ItemId 'heavy_item' -Quantity 1  # 10 weight
                $result.Success | Should -BeFalse
                $result.Reason | Should -Be 'Inventory full'
            }
            
            It "Should stack stackable items" {
                Add-PlayerInventory -ItemId 'light_item' -Quantity 5 | Out-Null
                Add-PlayerInventory -ItemId 'light_item' -Quantity 3 | Out-Null
                $inv = Get-PlayerInventory
                ($inv | Where-Object { $_.ItemId -eq 'light_item' }).Quantity | Should -Be 8
            }
            
            It "Should not stack non-stackable items" {
                Add-PlayerInventory -ItemId 'unique_item' -Quantity 1 | Out-Null
                $result = Add-PlayerInventory -ItemId 'unique_item' -Quantity 1
                $result.Success | Should -BeFalse
                $result.Reason | Should -Be 'Item not stackable'
            }
        }
        
        Describe "Remove-PlayerInventory" {
            BeforeEach {
                Add-PlayerInventory -ItemId 'light_item' -Quantity 10 | Out-Null
            }
            
            It "Should remove items from inventory" {
                $result = Remove-PlayerInventory -ItemId 'light_item' -Quantity 3
                $result.Success | Should -BeTrue
                $result.RemainingQuantity | Should -Be 7
            }
            
            It "Should update weight" {
                $before = (Get-PlayerInventory -Summary).CurrentWeight
                Remove-PlayerInventory -ItemId 'light_item' -Quantity 5 | Out-Null
                $after = (Get-PlayerInventory -Summary).CurrentWeight
                $after | Should -BeLessThan $before
            }
            
            It "Should fail for insufficient quantity" {
                $result = Remove-PlayerInventory -ItemId 'light_item' -Quantity 100
                $result.Success | Should -BeFalse
                $result.Reason | Should -Be 'Insufficient quantity'
            }
        }
        
        Describe "Test-HasItem" {
            It "Should return true when player has item" {
                Add-PlayerInventory -ItemId 'light_item' -Quantity 5 | Out-Null
                Test-HasItem -ItemId 'light_item' -Quantity 3 | Should -BeTrue
            }
            
            It "Should return false when player lacks quantity" {
                Add-PlayerInventory -ItemId 'light_item' -Quantity 5 | Out-Null
                Test-HasItem -ItemId 'light_item' -Quantity 10 | Should -BeFalse
            }
            
            It "Should return false for missing item" {
                Test-HasItem -ItemId 'nonexistent' | Should -BeFalse
            }
        }
        
        Describe "Currency Management" {
            It "Should start with configured currency" {
                $currency = Get-PlayerCurrency
                $currency | Should -Be 1000  # Default starting currency
            }
            
            It "Should add currency" {
                $before = Get-PlayerCurrency
                Add-PlayerCurrency -Amount 500 -Source 'Quest reward'
                $after = Get-PlayerCurrency
                $after | Should -Be ($before + 500)
            }
            
            It "Should remove currency" {
                $result = Remove-PlayerCurrency -Amount 200 -Reason 'Purchase'
                $result.Success | Should -BeTrue
                $result.NewBalance | Should -Be 800
            }
            
            It "Should fail to remove more than available" {
                $result = Remove-PlayerCurrency -Amount 5000
                $result.Success | Should -BeFalse
                $result.Reason | Should -Be 'Insufficient funds'
            }
            
            It "Should set currency directly" {
                Set-PlayerCurrency -Amount 9999 | Out-Null
                Get-PlayerCurrency | Should -Be 9999
            }
        }
    }
    
    Describe "Transactions" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
            Set-PlayerCurrency -Amount 5000 | Out-Null
            New-Item -ItemId 'buy_item' -Name 'Buyable Item' -Category 'Consumables' -BasePrice 100 | Out-Null
            New-Item -ItemId 'sell_item' -Name 'Sellable Item' -Category 'Consumables' -BasePrice 200 | Out-Null
            New-Shop -ShopId 'trade_shop' -Name 'Trade Shop' -VendorType 'StreetVendor' | Out-Null
            Add-ShopInventory -ShopId 'trade_shop' -ItemId 'buy_item' -Quantity 20 | Out-Null
        }
        
        Describe "Invoke-Purchase" {
            It "Should complete a purchase" {
                $result = Invoke-Purchase -ShopId 'trade_shop' -ItemId 'buy_item' -Quantity 5
                $result.Success | Should -BeTrue
                $result.Transaction.Type | Should -Be 'Purchase'
                $result.Transaction.Quantity | Should -Be 5
            }
            
            It "Should deduct currency" {
                $before = Get-PlayerCurrency
                Invoke-Purchase -ShopId 'trade_shop' -ItemId 'buy_item' -Quantity 1
                $after = Get-PlayerCurrency
                $after | Should -BeLessThan $before
            }
            
            It "Should add item to player inventory" {
                Invoke-Purchase -ShopId 'trade_shop' -ItemId 'buy_item' -Quantity 3
                Test-HasItem -ItemId 'buy_item' -Quantity 3 | Should -BeTrue
            }
            
            It "Should remove item from shop inventory" {
                $before = (Get-ShopInventory -ShopId 'trade_shop' | Where-Object { $_.ItemId -eq 'buy_item' }).Quantity
                Invoke-Purchase -ShopId 'trade_shop' -ItemId 'buy_item' -Quantity 2
                $after = (Get-ShopInventory -ShopId 'trade_shop' | Where-Object { $_.ItemId -eq 'buy_item' }).Quantity
                $after | Should -Be ($before - 2)
            }
            
            It "Should fail with insufficient funds" {
                Set-PlayerCurrency -Amount 10 | Out-Null
                $result = Invoke-Purchase -ShopId 'trade_shop' -ItemId 'buy_item' -Quantity 5
                $result.Success | Should -BeFalse
                $result.Reason | Should -Be 'Insufficient funds'
            }
            
            It "Should fail when shop is closed" {
                Set-ShopOpen -ShopId 'trade_shop' -IsOpen $false | Out-Null
                $result = Invoke-Purchase -ShopId 'trade_shop' -ItemId 'buy_item' -Quantity 1
                $result.Success | Should -BeFalse
                $result.Reason | Should -Be 'Shop is closed'
            }
            
            It "Should fail when item not in stock" {
                $result = Invoke-Purchase -ShopId 'trade_shop' -ItemId 'nonexistent' -Quantity 1
                $result.Success | Should -BeFalse
                $result.Reason | Should -Be 'Item not in stock'
            }
        }
        
        Describe "Invoke-Sale" {
            BeforeEach {
                Add-PlayerInventory -ItemId 'sell_item' -Quantity 10 | Out-Null
            }
            
            It "Should complete a sale" {
                $result = Invoke-Sale -ShopId 'trade_shop' -ItemId 'sell_item' -Quantity 3
                $result.Success | Should -BeTrue
                $result.Transaction.Type | Should -Be 'Sale'
            }
            
            It "Should add currency" {
                $before = Get-PlayerCurrency
                Invoke-Sale -ShopId 'trade_shop' -ItemId 'sell_item' -Quantity 1
                $after = Get-PlayerCurrency
                $after | Should -BeGreaterThan $before
            }
            
            It "Should remove item from player inventory" {
                Invoke-Sale -ShopId 'trade_shop' -ItemId 'sell_item' -Quantity 5
                $remaining = (Get-PlayerInventory | Where-Object { $_.ItemId -eq 'sell_item' }).Quantity
                $remaining | Should -Be 5
            }
            
            It "Should add item to shop inventory" {
                Invoke-Sale -ShopId 'trade_shop' -ItemId 'sell_item' -Quantity 2
                $allInv = Get-ShopInventory -ShopId 'trade_shop'
                $sellItemInv = @($allInv | Where-Object { $_.ItemId -eq 'sell_item' })
                $sellItemInv.Count | Should -BeGreaterOrEqual 1
                $sellItemInv[0].Quantity | Should -Be 2
            }
            
            It "Should fail when player lacks item" {
                $result = Invoke-Sale -ShopId 'trade_shop' -ItemId 'nonexistent' -Quantity 1
                $result.Success | Should -BeFalse
            }
        }
        
        Describe "Get-TransactionHistory" {
            BeforeEach {
                Invoke-Purchase -ShopId 'trade_shop' -ItemId 'buy_item' -Quantity 1 | Out-Null
                Add-PlayerInventory -ItemId 'sell_item' -Quantity 5 | Out-Null
                Invoke-Sale -ShopId 'trade_shop' -ItemId 'sell_item' -Quantity 1 | Out-Null
            }
            
            It "Should return all transactions" {
                $history = Get-TransactionHistory
                $history.Count | Should -Be 2
            }
            
            It "Should filter by type" {
                $purchases = Get-TransactionHistory -Type 'Purchase'
                $purchases | ForEach-Object { $_.Type | Should -Be 'Purchase' }
            }
            
            It "Should filter by shop" {
                $history = Get-TransactionHistory -ShopId 'trade_shop'
                $history | ForEach-Object { $_.ShopId | Should -Be 'trade_shop' }
            }
        }
    }
    
    Describe "Access Control" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
            New-Shop -ShopId 'black_market' -Name 'Black Market' -VendorType 'BlackMarket' | Out-Null
            New-Shop -ShopId 'corp_store' -Name 'Corp Store' -VendorType 'CorporateStore' | Out-Null
        }
        
        Describe "Test-CanAccessShop" {
            It "Should allow Neutral standing for BlackMarket" {
                $result = Test-CanAccessShop -ShopId 'black_market' -PlayerStanding 'Neutral'
                $result.CanAccess | Should -BeTrue
            }
            
            It "Should deny Hostile standing for BlackMarket" {
                $result = Test-CanAccessShop -ShopId 'black_market' -PlayerStanding 'Hostile'
                $result.CanAccess | Should -BeFalse
            }
            
            It "Should allow Hostile standing for CorporateStore" {
                $result = Test-CanAccessShop -ShopId 'corp_store' -PlayerStanding 'Hostile'
                $result.CanAccess | Should -BeTrue
            }
            
            It "Should deny access to closed shop" {
                Set-ShopOpen -ShopId 'corp_store' -IsOpen $false | Out-Null
                $result = Test-CanAccessShop -ShopId 'corp_store' -PlayerStanding 'Allied'
                $result.CanAccess | Should -BeFalse
                $result.Reason | Should -Be 'Shop is closed'
            }
        }
        
        Describe "Get-AvailableShops" {
            It "Should return shops player can access" {
                $available = Get-AvailableShops -PlayerStanding 'Neutral'
                $available.Count | Should -BeGreaterOrEqual 2
            }
            
            It "Should filter by location" {
                New-Shop -ShopId 'downtown_shop' -Name 'Downtown' -VendorType 'StreetVendor' -LocationId 'downtown' | Out-Null
                $downtown = Get-AvailableShops -PlayerStanding 'Neutral' -LocationId 'downtown'
                $downtown | ForEach-Object { $_.ShopId | Should -Match 'downtown' }
                $downtown.Count | Should -BeGreaterOrEqual 1
            }
        }
    }
    
    Describe "Event Processing" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
            New-Shop -ShopId 'event_shop' -Name 'Event Shop' -VendorType 'BlackMarket' -LocationId 'test_loc' | Out-Null
        }
        
        It "Should process CombatEnded event" {
            $result = Process-ShopEvent -EventType 'CombatEnded'
            $result.Results | Should -Not -BeNullOrEmpty
            Get-SupplyModifier -Category 'Weapons' | Should -Be 1.3
            Get-SupplyModifier -Category 'Medical' | Should -Be 1.2
        }
        
        It "Should process PoliceRaid event" {
            $result = Process-ShopEvent -EventType 'PoliceRaid' -EventData @{ LocationId = 'test_loc' }
            Get-SupplyModifier -Category 'Contraband' | Should -Be 1.5
            # Black market shop should be closed
            (Get-Shop -ShopId 'event_shop').IsOpen | Should -BeFalse
        }
        
        It "Should process Restock event" {
            Set-SupplyModifier -Category 'Weapons' -Modifier 2.0 | Out-Null
            Process-ShopEvent -EventType 'Restock'
            $mods = Get-SupplyModifier
            $mods.Count | Should -Be 0
        }
    }
    
    Describe "State Export/Import" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
            New-Item -ItemId 'export_item' -Name 'Export Item' -Category 'Junk' -BasePrice 10 | Out-Null
            New-Shop -ShopId 'export_shop' -Name 'Export Shop' -VendorType 'StreetVendor' | Out-Null
            Add-ShopInventory -ShopId 'export_shop' -ItemId 'export_item' -Quantity 5 | Out-Null
            Set-PlayerCurrency -Amount 9999 | Out-Null
        }
        
        It "Should export to file" {
            $testPath = Join-Path $env:TEMP 'shop_export_test.json'
            $result = Export-ShopData -FilePath $testPath
            $result.Success | Should -BeTrue
            Test-Path $testPath | Should -BeTrue
            Remove-Item $testPath -ErrorAction SilentlyContinue
        }
        
        It "Should import from file" {
            $testPath = Join-Path $env:TEMP 'shop_import_test.json'
            Export-ShopData -FilePath $testPath | Out-Null
            
            # Reset
            Initialize-ShopSystem | Out-Null
            
            # Import
            $result = Import-ShopData -FilePath $testPath
            $result.Success | Should -BeTrue
            $result.PlayerCurrency | Should -Be 9999
            $result.ShopCount | Should -Be 1
            
            Remove-Item $testPath -ErrorAction SilentlyContinue
        }
    }
    
    Describe "Utility Functions" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
        }
        
        It "Should return vendor types" {
            $types = Get-VendorTypes
            $types.Keys | Should -Contain 'BlackMarket'
            $types.BlackMarket.Name | Should -Be 'Black Market'
        }
        
        It "Should return rarity levels" {
            $rarities = Get-RarityLevels
            $rarities.Legendary.PriceModifier | Should -Be 20.0
        }
        
        It "Should return item categories" {
            $categories = Get-ItemCategories
            $categories.Weapons.DefaultWeight | Should -Be 3.0
        }
        
        It "Should return standing price modifiers" {
            $mods = Get-StandingPriceModifiers
            $mods.Hostile | Should -Be 2.0
            $mods.Allied | Should -Be 0.8
        }
    }
}
