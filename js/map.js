// Map functionality using Leaflet
class GameMap {
    constructor(containerId, gameInstance) {
        this.game = gameInstance;
        this.markers = [];
        this.playerMarker = null;
        this.playerPosition = null;
        this.pathfindingManager = null;
        this.osmDataService = null;
        this.mapConfig = null; // Configuration loaded from Data/Maps/config.json
        this.moveMode = 'foot'; // Default travel mode
        this.isMoving = false;

        // Map layers for different data types
        this.transportStopMarkers = []; // For transit stop display
        this.footpathLayer = null; // For walkable paths overlay
        this.amenityMarkers = []; // For amenity markers
        this.shopMarkers = []; // For shop markers
        this.poiMarkers = []; // For POI markers
        this.landUseLayer = null; // For land use zones

        // Layer visibility states
        this.showingFootpaths = false;
        this.showingAmenities = false;
        this.showingShops = false;
        this.showingPOIs = false;
        this.showingLandUse = false;

        // Initialize the map centered on New York City
        this.map = L.map(containerId).setView([40.7128, -74.0060], 11);

        // Add tile layer (you can change this to different map styles)
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '© OpenStreetMap contributors'
        }).addTo(this.map);

        // Initialize pathfinding
        this.pathfindingManager = new PathfindingManager(this.map);

        // Initialize OSM data service
        this.initOSMDataService();

        // Set up click-to-move
        this.setupClickToMove();

        console.log('GameMap initialized with pathfinding and OSM data service');
    }

    /**
     * Initialize the OSM data service
     * @param {string} cityName - Optional city name to load (matches config.cities key)
     */
    async initOSMDataService(cityName = null) {
        this.osmDataService = new OSMDataService();

        // Set up callbacks
        this.osmDataService.onLoadStart = () => {
            this.updateGameStatus('Loading map data...');
        };

        this.osmDataService.onLoadComplete = (info) => {
            console.log(`OSM data loaded from: ${info.source}`);
            this.updateGameStatus(`Map data loaded (${info.source})`);

            // Connect to pathfinding manager
            this.pathfindingManager.setOSMDataService(this.osmDataService);

            // Display transport stops if any
            this.displayTransportStops();

            // Apply layer defaults from config
            this.applyLayerDefaults();
        };

        this.osmDataService.onLoadError = (error) => {
            console.error('OSM data load error:', error);
            this.updateGameStatus('Map data load failed, using fallback');
        };

        // Try to load config first
        let osmBounds = null;
        console.log('GameMap: Loading config...');
        const config = await this.osmDataService.loadConfig();

        if (config) {
            console.log('GameMap: Config loaded successfully');
            console.log('GameMap: defaultCity from config:', config.defaultCity);
            this.mapConfig = config; // Store config for later use

            // Helper function to find city case-insensitively
            const findCity = (name) => {
                if (!name) return null;
                const lowerName = name.toLowerCase();
                for (const [key, value] of Object.entries(config.cities)) {
                    if (key.toLowerCase() === lowerName) {
                        return { key, config: value };
                    }
                }
                return null;
            };

            // If city specified, use its bounds; otherwise try to match or use default
            let cityConfig = null;
            let foundCity = cityName ? findCity(cityName) : null;

            if (foundCity) {
                cityConfig = foundCity.config;
                console.log(`GameMap: Using configured city: ${foundCity.key}`);
            } else {
                console.log(`GameMap: No cityName provided, looking for default: ${config.defaultCity}`);
                foundCity = findCity(config.defaultCity);
                if (foundCity) {
                    cityConfig = foundCity.config;
                    cityName = foundCity.key;
                    console.log(`GameMap: Using default city: ${foundCity.key}`);
                } else {
                    console.warn(`GameMap: Could not find city: ${config.defaultCity}`);
                }
            }

            if (cityConfig) {
                osmBounds = cityConfig.bounds;
                console.log('GameMap: City center:', cityConfig.center, 'zoom:', cityConfig.zoom);
                // Center map on configured city
                if (cityConfig.center) {
                    console.log(`GameMap: Setting view to [${cityConfig.center.lat}, ${cityConfig.center.lng}] zoom ${cityConfig.zoom || 11}`);
                    this.map.setView([cityConfig.center.lat, cityConfig.center.lng], cityConfig.zoom || 11);
                }
            }
        } else {
            console.warn('GameMap: Config is null, failed to load');
        }

        // Fall back to current map bounds if no config bounds available
        if (!osmBounds) {
            const bounds = this.map.getBounds();
            osmBounds = {
                south: bounds.getSouth(),
                west: bounds.getWest(),
                north: bounds.getNorth(),
                east: bounds.getEast()
            };

            // Expand bounds slightly for better coverage
            const latBuffer = (osmBounds.north - osmBounds.south) * 0.1;
            const lngBuffer = (osmBounds.east - osmBounds.west) * 0.1;
            osmBounds.south -= latBuffer;
            osmBounds.north += latBuffer;
            osmBounds.west -= lngBuffer;
            osmBounds.east += lngBuffer;
        }

        await this.osmDataService.initialize(osmBounds, false, cityName);
    }

    /**
     * Apply layer defaults from config to UI toggles
     */
    applyLayerDefaults() {
        if (!this.mapConfig || !this.mapConfig.settings?.layerDefaults) {
            return;
        }

        const defaults = this.mapConfig.settings.layerDefaults;
        console.log('GameMap: Applying layer defaults from config');

        // Apply footpaths default
        const footpathToggle = document.getElementById('toggleFootpaths');
        if (footpathToggle && defaults.footpaths !== undefined) {
            footpathToggle.checked = defaults.footpaths;
            if (defaults.footpaths && !this.showingFootpaths) {
                this.toggleFootpathLayer();
            }
        }

        // Apply amenities default
        const amenityToggle = document.getElementById('toggleAmenities');
        if (amenityToggle && defaults.amenities !== undefined) {
            amenityToggle.checked = defaults.amenities;
            if (defaults.amenities && !this.showingAmenities) {
                this.toggleAmenityLayer();
            }
        }

        // Apply shops default
        const shopToggle = document.getElementById('toggleShops');
        if (shopToggle && defaults.shops !== undefined) {
            shopToggle.checked = defaults.shops;
            if (defaults.shops && !this.showingShops) {
                this.toggleShopLayer();
            }
        }

        // Apply POIs default
        const poiToggle = document.getElementById('togglePOIs');
        if (poiToggle && defaults.pois !== undefined) {
            poiToggle.checked = defaults.pois;
            if (defaults.pois && !this.showingPOIs) {
                this.togglePOILayer();
            }
        }

        // Apply land use default
        const landUseToggle = document.getElementById('toggleLandUse');
        if (landUseToggle && defaults.landUse !== undefined) {
            landUseToggle.checked = defaults.landUse;
            if (defaults.landUse && !this.showingLandUse) {
                this.toggleLandUseLayer();
            }
        }
    }

    /**
     * Refresh OSM map data
     */
    async refreshMapData() {
        if (this.osmDataService) {
            this.updateGameStatus('Refreshing map data...');
            await this.osmDataService.refreshMapData();
            this.displayTransportStops();
        }
    }

    /**
     * Display transport stops on the map
     */
    displayTransportStops() {
        // Clear existing transport markers
        this.transportStopMarkers.forEach(marker => marker.remove());
        this.transportStopMarkers = [];

        if (!this.osmDataService || !this.osmDataService.transportStops) return;

        const stopIcons = {
            'bus': { emoji: '🚌', color: '#3498db' },
            'train': { emoji: '🚂', color: '#e74c3c' },
            'subway': { emoji: '🚇', color: '#9b59b6' },
            'tram': { emoji: '🚊', color: '#f39c12' },
            'ferry': { emoji: '⛴️', color: '#1abc9c' },
            'transit': { emoji: '🚏', color: '#95a5a6' },
            'unknown': { emoji: '🚏', color: '#95a5a6' }
        };

        for (const stop of this.osmDataService.transportStops) {
            const iconConfig = stopIcons[stop.type] || stopIcons['unknown'];

            const icon = L.divIcon({
                className: 'transport-stop-marker',
                html: `<div style="
                    background-color: ${iconConfig.color};
                    border: 2px solid white;
                    border-radius: 50%;
                    width: 24px;
                    height: 24px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 12px;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.3);
                ">${iconConfig.emoji}</div>`,
                iconSize: [24, 24],
                iconAnchor: [12, 12]
            });

            const marker = L.marker([stop.lat, stop.lng], { icon })
                .bindPopup(`
                    <strong>${stop.name}</strong><br>
                    Type: ${stop.type}<br>
                    ${stop.routes ? `Routes: ${stop.routes}` : ''}
                    ${stop.operator ? `<br>Operator: ${stop.operator}` : ''}
                `)
                .addTo(this.map);

            this.transportStopMarkers.push(marker);
        }

        console.log(`Displayed ${this.transportStopMarkers.length} transport stops`);
    }

    /**
     * Toggle footpath layer visibility
     */
    toggleFootpathLayer() {
        if (this.showingFootpaths) {
            // Hide footpaths
            if (this.footpathLayer) {
                this.map.removeLayer(this.footpathLayer);
            }
            this.showingFootpaths = false;
        } else {
            // Show footpaths
            this.displayFootpaths();
            this.showingFootpaths = true;
        }
        return this.showingFootpaths;
    }

    /**
     * Display footpaths on the map
     */
    displayFootpaths() {
        if (!this.osmDataService || !this.osmDataService.footpaths) return;

        // Remove existing layer
        if (this.footpathLayer) {
            this.map.removeLayer(this.footpathLayer);
        }

        const pathLines = [];

        for (const path of this.osmDataService.footpaths) {
            if (path.coordinates && path.coordinates.length >= 2) {
                pathLines.push(path.coordinates);
            }
        }

        if (pathLines.length > 0) {
            this.footpathLayer = L.polyline(pathLines, {
                color: '#27ae60',
                weight: 2,
                opacity: 0.6,
                dashArray: '5, 5',
                interactive: false  // Allow clicks to pass through
            }).addTo(this.map);
        }

        console.log(`Displayed ${pathLines.length} footpaths`);
    }

    // ========================================
    // NEW OSM LAYER DISPLAY METHODS
    // ========================================

    /**
     * Toggle amenities layer visibility
     */
    toggleAmenityLayer() {
        if (this.showingAmenities) {
            this.hideAmenities();
            this.showingAmenities = false;
        } else {
            this.displayAmenities();
            this.showingAmenities = true;
        }
        return this.showingAmenities;
    }

    /**
     * Display amenities on the map
     */
    displayAmenities() {
        this.hideAmenities();

        if (!this.osmDataService || !this.osmDataService.amenities) return;

        const amenityIcons = {
            // Food & Drink
            'restaurant': { emoji: '🍽️', color: '#e67e22' },
            'cafe': { emoji: '☕', color: '#d35400' },
            'bar': { emoji: '🍺', color: '#8e44ad' },
            'pub': { emoji: '🍻', color: '#9b59b6' },
            'fast_food': { emoji: '🍔', color: '#f39c12' },
            'food_court': { emoji: '🍴', color: '#e74c3c' },
            'ice_cream': { emoji: '🍦', color: '#f1c40f' },
            'biergarten': { emoji: '🍻', color: '#27ae60' },

            // Financial
            'bank': { emoji: '🏦', color: '#2c3e50' },
            'atm': { emoji: '💳', color: '#34495e' },
            'bureau_de_change': { emoji: '💱', color: '#1abc9c' },

            // Healthcare
            'hospital': { emoji: '🏥', color: '#e74c3c' },
            'clinic': { emoji: '⚕️', color: '#c0392b' },
            'pharmacy': { emoji: '💊', color: '#27ae60' },
            'doctors': { emoji: '👨‍⚕️', color: '#3498db' },
            'dentist': { emoji: '🦷', color: '#ecf0f1' },
            'veterinary': { emoji: '🐾', color: '#2ecc71' },
            'nursing_home': { emoji: '🏠', color: '#95a5a6' },

            // Education
            'school': { emoji: '🏫', color: '#3498db' },
            'university': { emoji: '🎓', color: '#2980b9' },
            'college': { emoji: '📚', color: '#9b59b6' },
            'kindergarten': { emoji: '💒', color: '#f1c40f' },
            'library': { emoji: '📖', color: '#e74c3c' },
            'language_school': { emoji: '🗣️', color: '#1abc9c' },
            'driving_school': { emoji: '🚗', color: '#7f8c8d' },
            'music_school': { emoji: '🎵', color: '#9b59b6' },

            // Public Services
            'police': { emoji: '👮', color: '#2c3e50' },
            'fire_station': { emoji: '🚒', color: '#e74c3c' },
            'post_office': { emoji: '📮', color: '#f39c12' },
            'townhall': { emoji: '🏛️', color: '#34495e' },
            'courthouse': { emoji: '⚖️', color: '#7f8c8d' },
            'prison': { emoji: '🔒', color: '#2c3e50' },
            'embassy': { emoji: '🏢', color: '#3498db' },
            'community_centre': { emoji: '🏘️', color: '#27ae60' },
            'social_facility': { emoji: '🤝', color: '#1abc9c' },

            // Religious
            'place_of_worship': { emoji: '⛪', color: '#9b59b6' },
            'church': { emoji: '⛪', color: '#9b59b6' },
            'chapel': { emoji: '⛪', color: '#8e44ad' },
            'cathedral': { emoji: '⛪', color: '#7d3c98' },
            'mosque': { emoji: '🕌', color: '#1abc9c' },
            'temple': { emoji: '🛕', color: '#f39c12' },
            'synagogue': { emoji: '✡️', color: '#3498db' },
            'monastery': { emoji: '🏛️', color: '#7f8c8d' },

            // Entertainment
            'cinema': { emoji: '🎬', color: '#e74c3c' },
            'theatre': { emoji: '🎭', color: '#9b59b6' },
            'nightclub': { emoji: '🎉', color: '#8e44ad' },
            'casino': { emoji: '🎰', color: '#f1c40f' },
            'arts_centre': { emoji: '🎨', color: '#e67e22' },
            'studio': { emoji: '🎤', color: '#3498db' },
            'events_venue': { emoji: '🎪', color: '#c0392b' },

            // Transportation
            'fuel': { emoji: '⛽', color: '#7f8c8d' },
            'parking': { emoji: '🅿️', color: '#3498db' },
            'bus_station': { emoji: '🚌', color: '#27ae60' },
            'taxi': { emoji: '🚕', color: '#f1c40f' },
            'car_rental': { emoji: '🚗', color: '#e67e22' },
            'car_wash': { emoji: '🚿', color: '#3498db' },
            'bicycle_rental': { emoji: '🚲', color: '#2ecc71' },
            'bicycle_parking': { emoji: '🚲', color: '#27ae60' },
            'ferry_terminal': { emoji: '⛴️', color: '#2980b9' },
            'charging_station': { emoji: '🔌', color: '#1abc9c' },

            // Other Services
            'toilets': { emoji: '🚻', color: '#95a5a6' },
            'shower': { emoji: '🚿', color: '#3498db' },
            'drinking_water': { emoji: '🚰', color: '#2980b9' },
            'telephone': { emoji: '📞', color: '#7f8c8d' },
            'recycling': { emoji: '♻️', color: '#27ae60' },
            'waste_disposal': { emoji: '🗑️', color: '#7f8c8d' },
            'bench': { emoji: '🪑', color: '#8e6c3a' },
            'shelter': { emoji: '🏚️', color: '#95a5a6' },
            'fountain': { emoji: '⛲', color: '#3498db' },
            'clock': { emoji: '🕐', color: '#34495e' },
            'marketplace': { emoji: '🏪', color: '#e67e22' },
            'vending_machine': { emoji: '🎰', color: '#7f8c8d' },

            'unknown': { emoji: '📍', color: '#95a5a6' }
        };

        for (const amenity of this.osmDataService.amenities) {
            const iconConfig = amenityIcons[amenity.type] || amenityIcons['unknown'];

            const icon = L.divIcon({
                className: 'amenity-marker',
                html: `<div style="
                    background-color: ${iconConfig.color};
                    border: 2px solid white;
                    border-radius: 50%;
                    width: 22px;
                    height: 22px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 11px;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.3);
                ">${iconConfig.emoji}</div>`,
                iconSize: [22, 22],
                iconAnchor: [11, 11]
            });

            const marker = L.marker([amenity.lat, amenity.lng], { icon })
                .bindPopup(`
                    <strong>${amenity.name}</strong><br>
                    Type: ${amenity.type}<br>
                    ${amenity.cuisine ? `Cuisine: ${amenity.cuisine}<br>` : ''}
                    ${amenity.openingHours ? `Hours: ${amenity.openingHours}` : ''}
                `)
                .addTo(this.map);

            this.amenityMarkers.push(marker);
        }

        console.log(`Displayed ${this.amenityMarkers.length} amenities`);
    }

    /**
     * Hide amenity markers
     */
    hideAmenities() {
        this.amenityMarkers.forEach(marker => marker.remove());
        this.amenityMarkers = [];
    }

    /**
     * Toggle shops layer visibility
     */
    toggleShopLayer() {
        if (this.showingShops) {
            this.hideShops();
            this.showingShops = false;
        } else {
            this.displayShops();
            this.showingShops = true;
        }
        return this.showingShops;
    }

    /**
     * Display shops on the map
     */
    displayShops() {
        this.hideShops();

        if (!this.osmDataService || !this.osmDataService.shops) return;

        const shopIcons = {
            // Food & Groceries
            'supermarket': { emoji: '🛒', color: '#27ae60' },
            'convenience': { emoji: '🏪', color: '#2ecc71' },
            'bakery': { emoji: '🥖', color: '#f39c12' },
            'butcher': { emoji: '🥩', color: '#c0392b' },
            'greengrocer': { emoji: '🥬', color: '#27ae60' },
            'deli': { emoji: '🥪', color: '#e67e22' },
            'seafood': { emoji: '🐟', color: '#3498db' },
            'cheese': { emoji: '🧀', color: '#f1c40f' },
            'confectionery': { emoji: '🍬', color: '#e91e63' },
            'chocolate': { emoji: '🍫', color: '#8e6c3a' },
            'coffee': { emoji: '☕', color: '#d35400' },
            'tea': { emoji: '🍵', color: '#27ae60' },
            'alcohol': { emoji: '🍷', color: '#8e44ad' },
            'beverages': { emoji: '🧃', color: '#e74c3c' },

            // Clothing & Fashion
            'clothes': { emoji: '👕', color: '#9b59b6' },
            'shoes': { emoji: '👟', color: '#7f8c8d' },
            'fashion': { emoji: '👗', color: '#e91e63' },
            'boutique': { emoji: '👔', color: '#9b59b6' },
            'bag': { emoji: '👜', color: '#8e44ad' },
            'jewelry': { emoji: '💎', color: '#f1c40f' },
            'watches': { emoji: '⌚', color: '#34495e' },
            'beauty': { emoji: '💄', color: '#e91e63' },
            'cosmetics': { emoji: '💅', color: '#ff69b4' },
            'perfumery': { emoji: '🧴', color: '#9b59b6' },
            'hairdresser': { emoji: '💇', color: '#e74c3c' },
            'tattoo': { emoji: '🎨', color: '#2c3e50' },

            // Electronics & Tech
            'electronics': { emoji: '📱', color: '#3498db' },
            'computer': { emoji: '💻', color: '#2980b9' },
            'mobile_phone': { emoji: '📱', color: '#1abc9c' },
            'hifi': { emoji: '🔊', color: '#34495e' },
            'appliance': { emoji: '🔌', color: '#7f8c8d' },

            // Home & Garden
            'hardware': { emoji: '🔧', color: '#7f8c8d' },
            'doityourself': { emoji: '🛠️', color: '#e67e22' },
            'furniture': { emoji: '🛋️', color: '#8e6c3a' },
            'kitchen': { emoji: '🍳', color: '#95a5a6' },
            'bed': { emoji: '🛏️', color: '#9b59b6' },
            'carpet': { emoji: '🟫', color: '#c0392b' },
            'curtain': { emoji: '🪟', color: '#3498db' },
            'garden_centre': { emoji: '🌻', color: '#27ae60' },
            'florist': { emoji: '💐', color: '#e91e63' },

            // Entertainment & Hobbies
            'books': { emoji: '📚', color: '#e74c3c' },
            'stationery': { emoji: '📝', color: '#3498db' },
            'newsagent': { emoji: '📰', color: '#7f8c8d' },
            'toys': { emoji: '🧸', color: '#f1c40f' },
            'games': { emoji: '🎮', color: '#9b59b6' },
            'video_games': { emoji: '🕹️', color: '#8e44ad' },
            'music': { emoji: '🎵', color: '#e74c3c' },
            'musical_instrument': { emoji: '🎸', color: '#f39c12' },
            'art': { emoji: '🎨', color: '#e67e22' },
            'craft': { emoji: '✂️', color: '#1abc9c' },
            'photo': { emoji: '📷', color: '#34495e' },
            'gift': { emoji: '🎁', color: '#e91e63' },
            'antiques': { emoji: '🏺', color: '#8e6c3a' },
            'second_hand': { emoji: '♻️', color: '#27ae60' },

            // Sports & Outdoors
            'sports': { emoji: '⚽', color: '#27ae60' },
            'outdoor': { emoji: '🏕️', color: '#2ecc71' },
            'bicycle': { emoji: '🚲', color: '#3498db' },
            'fishing': { emoji: '🎣', color: '#2980b9' },
            'hunting': { emoji: '🦌', color: '#8e6c3a' },

            // Vehicles
            'car': { emoji: '🚗', color: '#e74c3c' },
            'car_parts': { emoji: '⚙️', color: '#7f8c8d' },
            'car_repair': { emoji: '🔧', color: '#34495e' },
            'tyres': { emoji: '🛞', color: '#2c3e50' },
            'motorcycle': { emoji: '🏍️', color: '#c0392b' },

            // Health & Wellness
            'chemist': { emoji: '🧪', color: '#27ae60' },
            'medical_supply': { emoji: '🩺', color: '#e74c3c' },
            'optician': { emoji: '👓', color: '#3498db' },
            'hearing_aids': { emoji: '👂', color: '#9b59b6' },

            // Pet
            'pet': { emoji: '🐕', color: '#f39c12' },
            'pet_grooming': { emoji: '🐩', color: '#e91e63' },

            // Services & Other
            'laundry': { emoji: '🧺', color: '#3498db' },
            'dry_cleaning': { emoji: '👔', color: '#9b59b6' },
            'copyshop': { emoji: '🖨️', color: '#7f8c8d' },
            'travel_agency': { emoji: '✈️', color: '#1abc9c' },
            'estate_agent': { emoji: '🏠', color: '#e67e22' },
            'funeral_directors': { emoji: '⚰️', color: '#2c3e50' },
            'pawnbroker': { emoji: '💰', color: '#f1c40f' },
            'lottery': { emoji: '🎟️', color: '#e74c3c' },
            'tobacco': { emoji: '🚬', color: '#7f8c8d' },
            'e-cigarette': { emoji: '💨', color: '#95a5a6' },
            'variety_store': { emoji: '🏬', color: '#9b59b6' },
            'department_store': { emoji: '🏢', color: '#3498db' },
            'mall': { emoji: '🛍️', color: '#e67e22' },
            'kiosk': { emoji: '🏪', color: '#27ae60' },

            'general': { emoji: '🏬', color: '#34495e' }
        };
        for (const shop of this.osmDataService.shops) {
            const iconConfig = shopIcons[shop.shopType] || shopIcons['general'];

            const icon = L.divIcon({
                className: 'shop-marker',
                html: `<div style="
                    background-color: ${iconConfig.color};
                    border: 2px solid white;
                    border-radius: 4px;
                    width: 22px;
                    height: 22px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 11px;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.3);
                ">${iconConfig.emoji}</div>`,
                iconSize: [22, 22],
                iconAnchor: [11, 11]
            });

            const marker = L.marker([shop.lat, shop.lng], { icon })
                .bindPopup(`
                    <strong>${shop.name}</strong><br>
                    Type: ${shop.shopType}<br>
                    ${shop.brand ? `Brand: ${shop.brand}<br>` : ''}
                    ${shop.openingHours ? `Hours: ${shop.openingHours}` : ''}
                `)
                .addTo(this.map);

            this.shopMarkers.push(marker);
        }

        console.log(`Displayed ${this.shopMarkers.length} shops`);
    }

    /**
     * Hide shop markers
     */
    hideShops() {
        this.shopMarkers.forEach(marker => marker.remove());
        this.shopMarkers = [];
    }

    /**
     * Toggle POI layer visibility
     */
    togglePOILayer() {
        if (this.showingPOIs) {
            this.hidePOIs();
            this.showingPOIs = false;
        } else {
            this.displayPOIs();
            this.showingPOIs = true;
        }
        return this.showingPOIs;
    }

    /**
     * Display POIs on the map
     */
    displayPOIs() {
        this.hidePOIs();

        if (!this.osmDataService || !this.osmDataService.pois) return;

        const poiIcons = {
            'tourism': {
                'hotel': { emoji: '🏨', color: '#3498db' },
                'hostel': { emoji: '🛏️', color: '#2980b9' },
                'motel': { emoji: '🏩', color: '#1abc9c' },
                'guest_house': { emoji: '🏠', color: '#27ae60' },
                'apartment': { emoji: '🏢', color: '#7f8c8d' },
                'chalet': { emoji: '🏡', color: '#8e6c3a' },
                'camp_site': { emoji: '⛺', color: '#27ae60' },
                'caravan_site': { emoji: '🚐', color: '#f39c12' },
                'attraction': { emoji: '⭐', color: '#f39c12' },
                'museum': { emoji: '🏛️', color: '#9b59b6' },
                'gallery': { emoji: '🖼️', color: '#e67e22' },
                'zoo': { emoji: '🦁', color: '#f1c40f' },
                'aquarium': { emoji: '🐠', color: '#3498db' },
                'theme_park': { emoji: '🎢', color: '#e74c3c' },
                'viewpoint': { emoji: '👁️', color: '#e74c3c' },
                'artwork': { emoji: '🎨', color: '#9b59b6' },
                'picnic_site': { emoji: '🧺', color: '#27ae60' },
                'information': { emoji: 'ℹ️', color: '#95a5a6' },
                'alpine_hut': { emoji: '🏔️', color: '#2980b9' },
                'wilderness_hut': { emoji: '🛖', color: '#8e6c3a' }
            },
            'leisure': {
                'park': { emoji: '🌳', color: '#27ae60' },
                'garden': { emoji: '🌷', color: '#27ae60' },
                'nature_reserve': { emoji: '🦎', color: '#2ecc71' },
                'playground': { emoji: '🛝', color: '#f1c40f' },
                'sports_centre': { emoji: '🏀', color: '#e67e22' },
                'fitness_centre': { emoji: '💪', color: '#c0392b' },
                'stadium': { emoji: '🏟️', color: '#3498db' },
                'swimming_pool': { emoji: '🏊', color: '#3498db' },
                'water_park': { emoji: '🌊', color: '#2980b9' },
                'golf_course': { emoji: '⛳', color: '#27ae60' },
                'miniature_golf': { emoji: '🏌️', color: '#2ecc71' },
                'bowling_alley': { emoji: '🎳', color: '#9b59b6' },
                'ice_rink': { emoji: '⛸️', color: '#3498db' },
                'pitch': { emoji: '⚽', color: '#27ae60' },
                'track': { emoji: '🏃', color: '#e67e22' },
                'marina': { emoji: '⛵', color: '#2980b9' },
                'slipway': { emoji: '🛶', color: '#3498db' },
                'beach_resort': { emoji: '🏖️', color: '#f1c40f' },
                'fishing': { emoji: '🎣', color: '#2980b9' },
                'dog_park': { emoji: '🐕', color: '#8e6c3a' },
                'disc_golf_course': { emoji: '🥏', color: '#9b59b6' },
                'escape_game': { emoji: '🔐', color: '#e74c3c' },
                'hackerspace': { emoji: '💻', color: '#2c3e50' },
                'bird_hide': { emoji: '🦅', color: '#27ae60' },
                'bandstand': { emoji: '🎺', color: '#9b59b6' },
                'dance': { emoji: '💃', color: '#e91e63' },
                'amusement_arcade': { emoji: '🎰', color: '#f39c12' },
                'adult_gaming_centre': { emoji: '🎲', color: '#8e44ad' },
                'sauna': { emoji: '🧖', color: '#e67e22' },
                'horse_riding': { emoji: '🐴', color: '#8e6c3a' }
            },
            'historic': {
                'monument': { emoji: '🗿', color: '#7f8c8d' },
                'memorial': { emoji: '🏆', color: '#2c3e50' },
                'castle': { emoji: '🏰', color: '#8e44ad' },
                'ruins': { emoji: '🏚️', color: '#95a5a6' },
                'archaeological_site': { emoji: '🏺', color: '#8e6c3a' },
                'battlefield': { emoji: '⚔️', color: '#c0392b' },
                'boundary_stone': { emoji: '🪨', color: '#7f8c8d' },
                'building': { emoji: '🏛️', color: '#34495e' },
                'cannon': { emoji: '💥', color: '#2c3e50' },
                'church': { emoji: '⛪', color: '#9b59b6' },
                'city_gate': { emoji: '🚪', color: '#8e6c3a' },
                'citywalls': { emoji: '🧱', color: '#7f8c8d' },
                'fort': { emoji: '🏯', color: '#c0392b' },
                'manor': { emoji: '🏠', color: '#8e44ad' },
                'ship': { emoji: '🚢', color: '#2980b9' },
                'tomb': { emoji: '⚰️', color: '#2c3e50' },
                'tower': { emoji: '🗼', color: '#34495e' },
                'wayside_cross': { emoji: '✝️', color: '#9b59b6' },
                'wayside_shrine': { emoji: '⛩️', color: '#e74c3c' },
                'wreck': { emoji: '🚢', color: '#7f8c8d' },
                'aircraft': { emoji: '✈️', color: '#3498db' },
                'locomotive': { emoji: '🚂', color: '#2c3e50' },
                'milestone': { emoji: '🪧', color: '#95a5a6' },
                'pillory': { emoji: '⛓️', color: '#7f8c8d' }
            }
        };

        for (const poi of this.osmDataService.pois) {
            const categoryIcons = poiIcons[poi.category] || {};
            const iconConfig = categoryIcons[poi.subtype] || { emoji: '📍', color: '#34495e' };

            const icon = L.divIcon({
                className: 'poi-marker',
                html: `<div style="
                    background-color: ${iconConfig.color};
                    border: 2px solid white;
                    border-radius: 50%;
                    width: 24px;
                    height: 24px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 12px;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.3);
                ">${iconConfig.emoji}</div>`,
                iconSize: [24, 24],
                iconAnchor: [12, 12]
            });

            const marker = L.marker([poi.lat, poi.lng], { icon })
                .bindPopup(`
                    <strong>${poi.name}</strong><br>
                    Category: ${poi.category}<br>
                    Type: ${poi.subtype}<br>
                    ${poi.description ? `${poi.description}<br>` : ''}
                    ${poi.openingHours ? `Hours: ${poi.openingHours}` : ''}
                `)
                .addTo(this.map);

            this.poiMarkers.push(marker);
        }

        console.log(`Displayed ${this.poiMarkers.length} POIs`);
    }

    /**
     * Hide POI markers
     */
    hidePOIs() {
        this.poiMarkers.forEach(marker => marker.remove());
        this.poiMarkers = [];
    }

    /**
     * Toggle land use layer visibility
     */
    toggleLandUseLayer() {
        if (this.showingLandUse) {
            this.hideLandUse();
            this.showingLandUse = false;
        } else {
            this.displayLandUse();
            this.showingLandUse = true;
        }
        return this.showingLandUse;
    }

    /**
     * Display land use zones on the map
     */
    displayLandUse() {
        this.hideLandUse();

        if (!this.osmDataService || !this.osmDataService.landUse) return;

        const landUseColors = {
            'residential': '#f9e79f',
            'commercial': '#aed6f1',
            'industrial': '#d5dbdb',
            'retail': '#d2b4de',
            'farmland': '#a9dfbf',
            'forest': '#196f3d',
            'grass': '#82e0aa',
            'meadow': '#58d68d',
            'recreation_ground': '#f5b041',
            'unknown': '#bdc3c7'
        };

        const polygons = [];

        for (const zone of this.osmDataService.landUse) {
            if (zone.coordinates && zone.coordinates.length >= 3) {
                const color = landUseColors[zone.landUseType] || landUseColors['unknown'];

                const polygon = L.polygon(zone.coordinates, {
                    color: color,
                    fillColor: color,
                    fillOpacity: 0.3,
                    weight: 1,
                    interactive: false  // Allow clicks to pass through
                });

                // No popup since non-interactive
                polygons.push(polygon);
            }
        }

        if (polygons.length > 0) {
            this.landUseLayer = L.layerGroup(polygons).addTo(this.map);
        }

        console.log(`Displayed ${polygons.length} land use zones`);
    }

    /**
     * Hide land use layer
     */
    hideLandUse() {
        if (this.landUseLayer) {
            this.map.removeLayer(this.landUseLayer);
            this.landUseLayer = null;
        }
    }

    /**
     * Get all layer states for UI sync
     */
    getLayerStates() {
        return {
            footpaths: this.showingFootpaths,
            amenities: this.showingAmenities,
            shops: this.showingShops,
            pois: this.showingPOIs,
            landUse: this.showingLandUse
        };
    }

    /**
     * Set up click-to-move functionality
     */
    setupClickToMove() {
        this.map.on('click', async (e) => {
            // Don't process if clicking on a marker popup
            if (e.originalEvent && e.originalEvent.target.closest('.leaflet-popup')) {
                return;
            }

            // Create player if doesn't exist
            if (!this.playerMarker) {
                // Create player at the clicked location if no player exists
                this.setPlayerPosition(e.latlng.lat, e.latlng.lng);
                this.updateGameStatus('Player created! Click again to move.');
                return;
            }

            // Don't move if already moving
            if (this.isMoving) {
                console.log('Already moving, please wait...');
                return;
            }

            const destination = e.latlng;
            console.log(`Map clicked at [${destination.lat}, ${destination.lng}]`);

            // Check for transit mode requirements
            if (this.moveMode === 'transit') {
                const transitCheck = this.checkTransitAvailability(destination);
                if (!transitCheck.canUseTransit) {
                    this.updateGameStatus(transitCheck.message);
                    return;
                }
            }

            // Update status
            this.updateGameStatus('Calculating path...');

            // Find path
            const path = await this.pathfindingManager.findPath(
                this.playerPosition,
                destination,
                this.moveMode
            );

            // Show path
            this.pathfindingManager.showPath(path);

            // Show info
            const durationMinutes = Math.round(path.duration / 60);
            const distanceKm = (path.distance / 1000).toFixed(2);
            console.log(`Path: ${distanceKm}km, ~${durationMinutes} minutes via ${path.travelMode} (${path.type})`);

            // Emit movement started event
            if (this.game && this.game.eventManager) {
                this.game.eventManager.emit('movement.started', {
                    unitId: 'player',
                    destination: { lat: destination.lat, lng: destination.lng },
                    distance: path.distance,
                    duration: path.duration,
                    travelMode: path.travelMode,
                    pathType: path.type
                });
            }

            // Start movement animation
            this.startPlayerMovement(path);
        });
    }

    /**
     * Update game status display
     */
    updateGameStatus(status) {
        if (this.game && this.game.updateStatus) {
            this.game.updateStatus(status);
        }
        console.log(`Status: ${status}`);
    }

    /**
     * Set player position and create/update marker
     */
    setPlayerPosition(lat, lng) {
        const position = L.latLng(lat, lng);
        this.playerPosition = position;

        if (!this.playerMarker) {
            // Create player marker
            const playerIcon = L.divIcon({
                className: 'player-marker',
                html: `<div style="
                    background: radial-gradient(circle, #00ff00, #00aa00);
                    border: 3px solid #ffffff;
                    border-radius: 50%;
                    width: 20px;
                    height: 20px;
                    box-shadow: 0 0 10px rgba(0, 255, 0, 0.5), 0 2px 4px rgba(0,0,0,0.3);
                    animation: pulse 2s infinite;
                "></div>
                <style>
                    @keyframes pulse {
                        0%, 100% { transform: scale(1); opacity: 1; }
                        50% { transform: scale(1.2); opacity: 0.8; }
                    }
                </style>`,
                iconSize: [20, 20],
                iconAnchor: [10, 10]
            });

            this.playerMarker = L.marker(position, {
                icon: playerIcon,
                zIndexOffset: 1000 // Keep player on top
            }).addTo(this.map);

            this.playerMarker.bindPopup('<strong>Player</strong><br>Click map to move');

            console.log(`Player marker created at [${lat}, ${lng}]`);
        } else {
            // Update existing marker
            this.playerMarker.setLatLng(position);
            console.log(`Player marker moved to [${lat}, ${lng}]`);
        }

        // Center map on player
        this.map.setView(position, this.map.getZoom());
    }

    /**
     * Start player movement animation along path
     */
    startPlayerMovement(path) {
        if (!this.playerMarker) return;

        this.isMoving = true;
        this.updateGameStatus('Moving...');

        // Animate movement
        this.pathfindingManager.animateMovement(
            this.playerMarker,
            path,
            5.0, // Speed multiplier for demo
            () => {
                // On complete
                this.isMoving = false;
                this.playerPosition = path.coordinates[path.coordinates.length - 1];
                console.log(`Player arrived at [${this.playerPosition.lat}, ${this.playerPosition.lng}]`);

                this.updateGameStatus('Ready');

                // Update position display
                if (this.game && this.game.updatePositionDisplay) {
                    this.game.updatePositionDisplay({
                        lat: this.playerPosition.lat,
                        lng: this.playerPosition.lng
                    });
                }

                // Emit movement completed event
                if (this.game && this.game.eventManager) {
                    this.game.eventManager.emit('movement.completed', {
                        unitId: 'player',
                        position: {
                            lat: this.playerPosition.lat,
                            lng: this.playerPosition.lng
                        }
                    });
                }

                // Check if arrived at a location
                this.checkLocationArrival();

                // Refresh all popup distances now that player moved
                this.refreshPopups();

                // Clear path after arrival
                setTimeout(() => {
                    this.pathfindingManager.clearPath();
                    if (this.game && this.game.hidePathInfo) {
                        this.game.hidePathInfo();
                    }
                }, 2000);
            }
        );
    }

    /**
     * Check if player arrived at a game location
     */
    checkLocationArrival() {
        if (!this.playerPosition) return;

        const arrivalRadius = 50; // meters

        for (const marker of this.markers) {
            if (!marker.locationData) continue;

            const locPos = L.latLng(marker.locationData.lat, marker.locationData.lng);
            const distance = this.playerPosition.distanceTo(locPos);

            if (distance < arrivalRadius) {
                console.log(`Arrived at location: ${marker.locationData.name}`);

                // Show location popup
                marker.openPopup();

                // Emit location arrival event
                if (this.game && this.game.eventManager) {
                    this.game.eventManager.emit('location.arrived', {
                        location: marker.locationData,
                        distance: distance
                    });
                }

                break;
            }
        }
    }

    /**
     * Get distance from player to a location in meters
     */
    getDistanceToLocation(location) {
        if (!this.playerPosition) return Infinity;
        const locPos = L.latLng(location.lat, location.lng);
        return this.playerPosition.distanceTo(locPos);
    }

    /**
     * Check if player is within visit range of a location (100m)
     */
    isWithinVisitRange(location) {
        return this.getDistanceToLocation(location) <= 100;
    }

    /**
     * Set travel mode
     */
    setTravelMode(mode) {
        const validModes = ['foot', 'car', 'motorcycle', 'van', 'transit', 'aerial'];
        if (validModes.includes(mode)) {
            this.moveMode = mode;
            this.travelMode = mode; // Alias for compatibility
            console.log(`Travel mode set to: ${mode}`);

            // Check transit availability if switching to transit mode
            if (mode === 'transit' && this.playerPosition) {
                const transit = this.getTransitInfo();
                if (!transit.available) {
                    this.updateGameStatus('⚠️ No transit stops nearby! Walk to a stop first.');
                } else {
                    this.updateGameStatus(`Transit available: ${transit.nearestStop.name} (${Math.round(transit.nearestStop.distance)}m)`);
                }
            }
        } else {
            console.warn(`Invalid travel mode: ${mode}. Use one of: ${validModes.join(', ')}`);
        }
    }

    /**
     * Check transit availability for movement
     */
    checkTransitAvailability(destination) {
        if (!this.osmDataService || !this.playerPosition) {
            return { canUseTransit: false, message: 'Transit data not available' };
        }

        const playerLat = this.playerPosition.lat;
        const playerLng = this.playerPosition.lng;

        // Check if player is near a transit stop (200m)
        const nearPlayerStops = this.osmDataService.getNearbyTransportStops(playerLat, playerLng, 200);

        if (nearPlayerStops.length === 0) {
            return {
                canUseTransit: false,
                message: '🚌 No transit stops within 200m. Walk to a stop first!'
            };
        }

        // Check if destination is near a transit stop (200m)
        const nearDestStops = this.osmDataService.getNearbyTransportStops(destination.lat, destination.lng, 200);

        if (nearDestStops.length === 0) {
            return {
                canUseTransit: false,
                message: '🚌 No transit stops near destination. Choose a location near transit!'
            };
        }

        return {
            canUseTransit: true,
            startStop: nearPlayerStops[0],
            endStop: nearDestStops[0],
            message: `Transit: ${nearPlayerStops[0].name} → ${nearDestStops[0].name}`
        };
    }

    /**
     * Get transit info for current player position
     */
    getTransitInfo() {
        if (!this.osmDataService || !this.playerPosition) {
            return { available: false };
        }

        return this.osmDataService.getTransitAvailability(
            this.playerPosition.lat,
            this.playerPosition.lng,
            200
        );
    }

    /**
     * Refresh all location popups with current distance
     * Call this after player moves to update distances
     */
    refreshPopups() {
        this.markers.forEach((marker, index) => {
            if (marker.locationData) {
                marker.setPopupContent(this.createPopupContent(marker.locationData, index));
            }
        });
    }

    /**
     * Get current player position
     */
    getPlayerPosition() {
        if (!this.playerPosition) return null;
        return {
            lat: this.playerPosition.lat,
            lng: this.playerPosition.lng
        };
    }

    loadLocations(locations) {
        // Clear existing markers
        this.clearMarkers();

        locations.forEach(location => {
            this.addLocationMarker(location);
        });

        // Fit map to show all markers
        if (this.markers.length > 0) {
            const group = new L.featureGroup(this.markers);
            this.map.fitBounds(group.getBounds().pad(0.1));

            // Create player at the first location or center of map
            if (!this.playerMarker) {
                const firstLoc = locations[0];
                if (firstLoc) {
                    // Place player slightly offset from first location
                    this.setPlayerPosition(firstLoc.lat + 0.001, firstLoc.lng + 0.001);
                    this.updateGameStatus('Player ready! Click map to move.');
                }
            }
        }
    }

    addLocationMarker(location) {
        // Create custom icon based on location type
        const icon = this.createCustomIcon(location.type);

        // Create marker
        const marker = L.marker([location.lat, location.lng], { icon })
            .addTo(this.map);

        // Store location data on marker for later access
        marker.locationData = location;

        // Create popup content with unique ID
        const markerId = this.markers.length;
        const popupContent = this.createPopupContent(location, markerId);
        marker.bindPopup(popupContent);

        // Add click event to marker to set up button handler after popup opens
        marker.on('click', () => {
            // Refresh popup content with current distance
            marker.setPopupContent(this.createPopupContent(location, markerId));

            // Set up button click handler after popup opens
            setTimeout(() => {
                const button = document.getElementById(`visit-btn-${markerId}`);
                if (button) {
                    button.onclick = () => {
                        const action = button.getAttribute('data-action');
                        if (action === 'visit') {
                            // Player is nearby - allow visit
                            this.game.visitLocation(marker.locationData);
                            this.updateMarkerAfterVisit(marker, marker.locationData);
                        } else {
                            // Player is far - navigate to location
                            marker.closePopup();
                            this.navigateToLocation(marker.locationData);
                        }
                    };
                }
            }, 100);
        });

        // Store reference
        this.markers.push(marker);

        return marker;
    }

    createCustomIcon(type) {
        let iconColor = '#3498db'; // default blue
        let iconSymbol = '📍';

        switch (type) {
            case 'start':
                iconColor = '#2ecc71';
                iconSymbol = '🏠';
                break;
            case 'treasure':
                iconColor = '#f1c40f';
                iconSymbol = '💎';
                break;
            case 'quest':
                iconColor = '#9b59b6';
                iconSymbol = '⚔️';
                break;
            case 'shop':
                iconColor = '#e67e22';
                iconSymbol = '🏪';
                break;
        }

        return L.divIcon({
            className: 'custom-marker',
            html: `<div style="
                background-color: ${iconColor};
                border: 2px solid #fff;
                border-radius: 50%;
                width: 30px;
                height: 30px;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 16px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.3);
            ">${iconSymbol}</div>`,
            iconSize: [30, 30],
            iconAnchor: [15, 15],
            popupAnchor: [0, -15]
        });
    }

    createPopupContent(location, markerId) {
        // Handle items as string or array
        let itemsList = '';
        if (location.items) {
            const items = Array.isArray(location.items) ? location.items : [location.items];
            if (items.length > 0) {
                itemsList = `
                    <h4>Items:</h4>
                    <ul>
                        ${items.map(item => `<li>${String(item).replace(/_/g, ' ')}</li>`).join('')}
                    </ul>
                `;
            }
        }

        let pointsInfo = '';
        if (location.points) {
            pointsInfo = `<p><strong>Points:</strong> ${location.points}</p>`;
        }

        // Calculate distance and determine button state
        const distance = this.getDistanceToLocation(location);
        const isNearby = distance <= 100;
        const distanceText = distance < 1000
            ? `${Math.round(distance)}m away`
            : `${(distance / 1000).toFixed(1)}km away`;

        const buttonStyle = isNearby
            ? 'background-color: #2ecc71; color: white;'  // Green for visit
            : 'background-color: #3498db; color: white;'; // Blue for travel

        const buttonText = isNearby ? '✓ Visit Location' : '🚶 Go to Location';
        const buttonAction = isNearby ? 'visit' : 'goto';

        return `
            <div style="min-width: 200px;">
                <h3>${location.name}</h3>
                <p>${location.description}</p>
                <p style="color: ${isNearby ? '#2ecc71' : '#e74c3c'}; font-size: 0.9em;">
                    📍 ${isNearby ? 'Nearby' : distanceText} ${isNearby ? '(can visit)' : '(too far to visit)'}
                </p>
                ${pointsInfo}
                ${itemsList}
                <button id="visit-btn-${markerId}"
                        data-action="${buttonAction}"
                        style="
                            ${buttonStyle}
                            border: none;
                            padding: 8px 15px;
                            border-radius: 3px;
                            cursor: pointer;
                            margin-top: 10px;
                            font-weight: bold;
                        ">
                    ${buttonText}
                </button>
            </div>
        `;
    }

    /**
     * Navigate player to a location using pathfinding
     */
    navigateToLocation(location) {
        if (!this.playerPosition || !this.pathfindingManager) {
            console.error('Cannot navigate: player position or pathfinding not available');
            this.updateGameStatus('Cannot navigate - no player position');
            return;
        }

        const destination = L.latLng(location.lat, location.lng);
        console.log(`Navigating to: ${location.name}`);

        // Update game status
        this.updateGameStatus(`Traveling to ${location.name}...`);

        // Use the pathfinding system to move there
        this.pathfindingManager.findPath(
            this.playerPosition,
            destination,
            this.moveMode || 'foot'
        ).then(pathData => {
            if (pathData && pathData.coordinates && pathData.coordinates.length > 0) {
                // Draw the path using the correct method name
                this.pathfindingManager.showPath(pathData);

                // Update path info if game has the method
                if (this.game && this.game.updatePathInfo) {
                    this.game.updatePathInfo({
                        distance: pathData.distance,
                        duration: pathData.duration,
                        type: pathData.type
                    });
                }

                // Use existing movement method
                this.startPlayerMovement(pathData);
            } else {
                console.error('No path found to location');
                this.updateGameStatus('Could not find a path to that location');
            }
        }).catch(err => {
            console.error('Pathfinding error:', err);
            this.updateGameStatus('Error finding path: ' + err.message);
        });
    }

    updateMarkerAfterVisit(marker, location) {
        // Change marker appearance after visit
        const visitedIcon = L.divIcon({
            className: 'custom-marker visited',
            html: `<div style="
                background-color: #95a5a6;
                border: 2px solid #fff;
                border-radius: 50%;
                width: 30px;
                height: 30px;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 16px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.3);
                opacity: 0.7;
            ">✓</div>`,
            iconSize: [30, 30],
            iconAnchor: [15, 15],
            popupAnchor: [0, -15]
        });

        marker.setIcon(visitedIcon);
    }

    clearMarkers() {
        this.markers.forEach(marker => {
            this.map.removeLayer(marker);
        });
        this.markers = [];
    }

    clearMap() {
        this.clearMarkers();
    }

    // Method to add custom markers from PowerShell data
    addMarkersFromPowerShellData(data) {
        try {
            const locations = JSON.parse(data);
            this.loadLocations(locations);
        } catch (error) {
            console.error('Error parsing PowerShell data:', error);
        }
    }

    // Method to get current map bounds (useful for PowerShell scripts)
    getCurrentBounds() {
        const bounds = this.map.getBounds();
        return {
            north: bounds.getNorth(),
            south: bounds.getSouth(),
            east: bounds.getEast(),
            west: bounds.getWest()
        };
    }
}
