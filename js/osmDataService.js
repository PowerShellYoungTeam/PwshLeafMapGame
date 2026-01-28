// osmDataService.js
// OpenStreetMap data service with Overpass API integration
// Handles terrain validation, building data, transport stops, and surface types

class OSMDataService {
    constructor() {
        // Overpass API endpoints with fallback chain
        this.overpassEndpoints = [
            'https://overpass-api.de/api/interpreter',
            'https://overpass.kumi.systems/api/interpreter'
        ];
        this.currentEndpointIndex = 0;
        
        // Cache settings
        this.CACHE_KEY = 'osmDataCache';
        this.CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
        
        // Cached data
        this.waterBodies = [];      // GeoJSON polygons for water
        this.buildings = [];         // Buildings with addresses
        this.transportStops = [];    // Bus stops, train stations, etc.
        this.footpaths = [];         // Walkable paths
        this.surfaceData = new Map(); // Road surface types
        
        // City bounds (will be set on init)
        this.bounds = null;
        
        // Loading state
        this.isLoading = false;
        this.isLoaded = false;
        this.loadError = null;
        
        // Event callbacks
        this.onLoadStart = null;
        this.onLoadComplete = null;
        this.onLoadError = null;
    }

    /**
     * Initialize the OSM data service for a city
     * @param {Object} bounds - {south, west, north, east} bounding box
     * @param {boolean} forceRefresh - Force refresh even if cache is valid
     */
    async initialize(bounds, forceRefresh = false) {
        this.bounds = bounds;
        this.isLoading = true;
        this.loadError = null;
        
        if (this.onLoadStart) this.onLoadStart();
        
        console.log('OSMDataService: Initializing for bounds:', bounds);
        
        // Check cache first
        if (!forceRefresh && this.loadFromCache()) {
            console.log('OSMDataService: Loaded from cache');
            this.isLoading = false;
            this.isLoaded = true;
            if (this.onLoadComplete) this.onLoadComplete({ source: 'cache' });
            return true;
        }
        
        // Try to fetch from Overpass API
        try {
            await this.fetchAllData();
            this.saveToCache();
            this.isLoading = false;
            this.isLoaded = true;
            if (this.onLoadComplete) this.onLoadComplete({ source: 'api' });
            return true;
        } catch (error) {
            console.error('OSMDataService: Failed to fetch from Overpass API:', error);
            this.loadError = error;
            
            // Try fallback endpoint
            if (this.currentEndpointIndex < this.overpassEndpoints.length - 1) {
                this.currentEndpointIndex++;
                console.log('OSMDataService: Trying fallback endpoint...');
                try {
                    await this.fetchAllData();
                    this.saveToCache();
                    this.isLoading = false;
                    this.isLoaded = true;
                    if (this.onLoadComplete) this.onLoadComplete({ source: 'api-fallback' });
                    return true;
                } catch (fallbackError) {
                    console.error('OSMDataService: Fallback also failed:', fallbackError);
                }
            }
            
            // Last resort: use random generation fallback
            console.warn('OSMDataService: All API endpoints failed, using random generation fallback');
            this.useRandomGenerationFallback();
            this.isLoading = false;
            this.isLoaded = true;
            if (this.onLoadComplete) this.onLoadComplete({ source: 'fallback-random' });
            return true;
        }
    }

    /**
     * Refresh map data (manual refresh)
     */
    async refreshMapData() {
        console.log('OSMDataService: Manual refresh requested');
        this.clearCache();
        this.currentEndpointIndex = 0;
        return await this.initialize(this.bounds, true);
    }

    /**
     * Get current Overpass endpoint
     */
    getEndpoint() {
        return this.overpassEndpoints[this.currentEndpointIndex];
    }

    /**
     * Execute an Overpass query with timeout
     */
    async queryOverpass(query, timeout = 30) {
        const endpoint = this.getEndpoint();
        const fullQuery = `[out:json][timeout:${timeout}];${query}`;
        
        console.log('OSMDataService: Querying Overpass:', endpoint);
        
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: 'data=' + encodeURIComponent(fullQuery)
        });
        
        if (!response.ok) {
            throw new Error(`Overpass API error: ${response.status} ${response.statusText}`);
        }
        
        return await response.json();
    }

    /**
     * Fetch all required data from Overpass
     */
    async fetchAllData() {
        const { south, west, north, east } = this.bounds;
        const bbox = `${south},${west},${north},${east}`;
        
        console.log('OSMDataService: Fetching all data for bbox:', bbox);
        
        // Fetch data in parallel where possible
        const [waterData, buildingData, transportData, footpathData, surfaceData] = await Promise.all([
            this.fetchWaterBodies(bbox),
            this.fetchBuildings(bbox),
            this.fetchTransportStops(bbox),
            this.fetchFootpaths(bbox),
            this.fetchSurfaceData(bbox)
        ]);
        
        this.waterBodies = waterData;
        this.buildings = buildingData;
        this.transportStops = transportData;
        this.footpaths = footpathData;
        this.processSurfaceData(surfaceData);
        
        console.log('OSMDataService: Data fetched successfully');
        console.log(`  - Water bodies: ${this.waterBodies.length}`);
        console.log(`  - Buildings: ${this.buildings.length}`);
        console.log(`  - Transport stops: ${this.transportStops.length}`);
        console.log(`  - Footpaths: ${this.footpaths.length}`);
        console.log(`  - Surface segments: ${this.surfaceData.size}`);
    }

    /**
     * Fetch water bodies (lakes, rivers, ocean)
     */
    async fetchWaterBodies(bbox) {
        const query = `
            (
                way["natural"="water"](${bbox});
                relation["natural"="water"](${bbox});
                way["natural"="wetland"](${bbox});
                way["waterway"~"river|stream|canal"](${bbox});
            );
            out geom;
        `;
        
        try {
            const data = await this.queryOverpass(query);
            return this.parseWaterBodies(data);
        } catch (error) {
            console.warn('OSMDataService: Failed to fetch water bodies:', error);
            return [];
        }
    }

    /**
     * Parse water body data into GeoJSON-like polygons
     */
    parseWaterBodies(data) {
        const waterBodies = [];
        
        for (const element of data.elements || []) {
            if (element.type === 'way' && element.geometry) {
                const coordinates = element.geometry.map(p => [p.lat, p.lng]);
                waterBodies.push({
                    type: 'polygon',
                    coordinates: coordinates,
                    tags: element.tags || {}
                });
            } else if (element.type === 'relation' && element.members) {
                // Handle multipolygon relations
                for (const member of element.members) {
                    if (member.type === 'way' && member.geometry) {
                        const coordinates = member.geometry.map(p => [p.lat, p.lng]);
                        waterBodies.push({
                            type: 'polygon',
                            coordinates: coordinates,
                            tags: element.tags || {}
                        });
                    }
                }
            }
        }
        
        return waterBodies;
    }

    /**
     * Fetch buildings with addresses
     */
    async fetchBuildings(bbox) {
        const query = `
            (
                way["building"]["addr:housenumber"](${bbox});
                way["building"]["addr:street"](${bbox});
                relation["building"]["addr:housenumber"](${bbox});
            );
            out center;
        `;
        
        try {
            const data = await this.queryOverpass(query);
            return this.parseBuildings(data);
        } catch (error) {
            console.warn('OSMDataService: Failed to fetch buildings:', error);
            return [];
        }
    }

    /**
     * Parse building data
     */
    parseBuildings(data) {
        const buildings = [];
        
        for (const element of data.elements || []) {
            if (element.center || (element.lat && element.lon)) {
                const lat = element.center?.lat || element.lat;
                const lng = element.center?.lon || element.lon;
                const tags = element.tags || {};
                
                buildings.push({
                    id: element.id,
                    lat: lat,
                    lng: lng,
                    type: tags.building || 'yes',
                    address: {
                        housenumber: tags['addr:housenumber'] || '',
                        street: tags['addr:street'] || '',
                        city: tags['addr:city'] || '',
                        postcode: tags['addr:postcode'] || ''
                    },
                    name: tags.name || '',
                    amenity: tags.amenity || '',
                    shop: tags.shop || ''
                });
            }
        }
        
        return buildings;
    }

    /**
     * Fetch transport stops (bus, train, subway)
     */
    async fetchTransportStops(bbox) {
        const query = `
            (
                node["highway"="bus_stop"](${bbox});
                node["public_transport"="platform"](${bbox});
                node["railway"="station"](${bbox});
                node["railway"="halt"](${bbox});
                node["railway"="subway_entrance"](${bbox});
                node["railway"="tram_stop"](${bbox});
                node["amenity"="ferry_terminal"](${bbox});
            );
            out;
        `;
        
        try {
            const data = await this.queryOverpass(query);
            return this.parseTransportStops(data);
        } catch (error) {
            console.warn('OSMDataService: Failed to fetch transport stops:', error);
            return [];
        }
    }

    /**
     * Parse transport stop data
     */
    parseTransportStops(data) {
        const stops = [];
        
        for (const element of data.elements || []) {
            if (element.lat && element.lon) {
                const tags = element.tags || {};
                
                // Determine stop type
                let stopType = 'unknown';
                if (tags.highway === 'bus_stop' || tags.bus === 'yes') {
                    stopType = 'bus';
                } else if (tags.railway === 'station') {
                    stopType = 'train';
                } else if (tags.railway === 'subway_entrance') {
                    stopType = 'subway';
                } else if (tags.railway === 'tram_stop') {
                    stopType = 'tram';
                } else if (tags.amenity === 'ferry_terminal') {
                    stopType = 'ferry';
                } else if (tags.public_transport === 'platform') {
                    stopType = tags.bus ? 'bus' : tags.train ? 'train' : 'transit';
                }
                
                stops.push({
                    id: element.id,
                    lat: element.lat,
                    lng: element.lon,
                    type: stopType,
                    name: tags.name || `${stopType.charAt(0).toUpperCase() + stopType.slice(1)} Stop`,
                    ref: tags.ref || '',
                    operator: tags.operator || '',
                    network: tags.network || '',
                    routes: tags.route_ref || ''
                });
            }
        }
        
        return stops;
    }

    /**
     * Fetch footpaths and walkable paths
     */
    async fetchFootpaths(bbox) {
        const query = `
            way["highway"~"footway|pedestrian|path|steps|cycleway"](${bbox});
            out geom;
        `;
        
        try {
            const data = await this.queryOverpass(query);
            return this.parseFootpaths(data);
        } catch (error) {
            console.warn('OSMDataService: Failed to fetch footpaths:', error);
            return [];
        }
    }

    /**
     * Parse footpath data
     */
    parseFootpaths(data) {
        const paths = [];
        
        for (const element of data.elements || []) {
            if (element.type === 'way' && element.geometry) {
                const coordinates = element.geometry.map(p => [p.lat, p.lon]);
                const tags = element.tags || {};
                
                paths.push({
                    id: element.id,
                    coordinates: coordinates,
                    type: tags.highway || 'path',
                    surface: tags.surface || 'unknown',
                    name: tags.name || ''
                });
            }
        }
        
        return paths;
    }

    /**
     * Fetch road surface data
     */
    async fetchSurfaceData(bbox) {
        const query = `
            way["highway"]["surface"](${bbox});
            out geom;
        `;
        
        try {
            const data = await this.queryOverpass(query);
            return data.elements || [];
        } catch (error) {
            console.warn('OSMDataService: Failed to fetch surface data:', error);
            return [];
        }
    }

    /**
     * Process surface data into lookup map
     */
    processSurfaceData(elements) {
        this.surfaceData.clear();
        
        for (const element of elements) {
            if (element.type === 'way' && element.geometry && element.tags?.surface) {
                // Store surface type with way geometry for lookup
                const coords = element.geometry.map(p => ({ lat: p.lat, lng: p.lon }));
                this.surfaceData.set(element.id, {
                    surface: element.tags.surface,
                    coordinates: coords,
                    highway: element.tags.highway || 'road'
                });
            }
        }
    }

    /**
     * Check if a point is on water
     * @param {number} lat - Latitude
     * @param {number} lng - Longitude
     * @returns {boolean} True if point is in water
     */
    isOnWater(lat, lng) {
        if (!this.isLoaded || this.waterBodies.length === 0) {
            return false; // Assume land if no data
        }
        
        // Use Turf.js if available, otherwise simple bounding box check
        if (typeof turf !== 'undefined') {
            const point = turf.point([lng, lat]);
            
            for (const water of this.waterBodies) {
                if (water.coordinates.length >= 3) {
                    try {
                        // Convert to GeoJSON polygon format [lng, lat]
                        const polygonCoords = water.coordinates.map(c => [c[1], c[0]]);
                        // Close the polygon if not closed
                        if (polygonCoords[0][0] !== polygonCoords[polygonCoords.length - 1][0] ||
                            polygonCoords[0][1] !== polygonCoords[polygonCoords.length - 1][1]) {
                            polygonCoords.push(polygonCoords[0]);
                        }
                        const polygon = turf.polygon([polygonCoords]);
                        if (turf.booleanPointInPolygon(point, polygon)) {
                            return true;
                        }
                    } catch (e) {
                        // Invalid polygon, skip
                    }
                }
            }
        } else {
            // Fallback: simple bounding box check
            for (const water of this.waterBodies) {
                if (this.pointInBoundingBox(lat, lng, water.coordinates)) {
                    return true;
                }
            }
        }
        
        return false;
    }

    /**
     * Simple bounding box check (fallback when Turf.js not available)
     */
    pointInBoundingBox(lat, lng, coordinates) {
        if (coordinates.length === 0) return false;
        
        let minLat = Infinity, maxLat = -Infinity;
        let minLng = Infinity, maxLng = -Infinity;
        
        for (const [pLat, pLng] of coordinates) {
            minLat = Math.min(minLat, pLat);
            maxLat = Math.max(maxLat, pLat);
            minLng = Math.min(minLng, pLng);
            maxLng = Math.max(maxLng, pLng);
        }
        
        return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
    }

    /**
     * Check if a point is on land (not water)
     * @param {number} lat - Latitude
     * @param {number} lng - Longitude
     * @returns {boolean} True if point is on land
     */
    isOnLand(lat, lng) {
        return !this.isOnWater(lat, lng);
    }

    /**
     * Validate a position for location placement
     * @param {number} lat - Latitude
     * @param {number} lng - Longitude
     * @param {string} locationType - Type of location (allows water for rig, platform, boat, dock)
     * @returns {boolean} True if position is valid
     */
    validatePosition(lat, lng, locationType = 'default') {
        const waterAllowedTypes = ['rig', 'platform', 'boat', 'dock', 'pier', 'marina'];
        
        if (waterAllowedTypes.includes(locationType.toLowerCase())) {
            return true; // Allow water positions for water-based locations
        }
        
        return this.isOnLand(lat, lng);
    }

    /**
     * Get nearby buildings
     * @param {number} lat - Center latitude
     * @param {number} lng - Center longitude
     * @param {number} radius - Search radius in meters
     * @returns {Array} Nearby buildings
     */
    getNearbyBuildings(lat, lng, radius = 500) {
        return this.buildings.filter(building => {
            const distance = this.calculateDistance(lat, lng, building.lat, building.lng);
            return distance <= radius;
        });
    }

    /**
     * Get buildings by type
     * @param {string} buildingType - Building type (commercial, residential, etc.)
     * @returns {Array} Matching buildings
     */
    getBuildingsByType(buildingType) {
        const typeMap = {
            'shop': ['commercial', 'retail', 'supermarket', 'kiosk'],
            'quest': ['residential', 'apartments', 'house'],
            'mission': ['industrial', 'warehouse', 'factory'],
            'safehouse': ['residential', 'apartments'],
            'landmark': ['public', 'civic', 'government', 'church', 'cathedral']
        };
        
        const matchingTypes = typeMap[buildingType] || [buildingType];
        
        return this.buildings.filter(building => {
            return matchingTypes.includes(building.type) || 
                   building.shop || 
                   building.amenity;
        });
    }

    /**
     * Get a random building suitable for a game location
     * @param {string} locationType - Game location type
     * @returns {Object|null} Building or null if none found
     */
    getRandomBuildingForLocation(locationType) {
        const buildings = this.getBuildingsByType(locationType);
        
        if (buildings.length === 0) {
            return null;
        }
        
        return buildings[Math.floor(Math.random() * buildings.length)];
    }

    /**
     * Get nearby transport stops
     * @param {number} lat - Center latitude
     * @param {number} lng - Center longitude
     * @param {number} radius - Search radius in meters
     * @returns {Array} Nearby transport stops
     */
    getNearbyTransportStops(lat, lng, radius = 200) {
        return this.transportStops.filter(stop => {
            const distance = this.calculateDistance(lat, lng, stop.lat, stop.lng);
            return distance <= radius;
        });
    }

    /**
     * Check if transit is available at a position
     * @param {number} lat - Latitude
     * @param {number} lng - Longitude
     * @param {number} radius - Search radius in meters (default 200m)
     * @returns {Object} Transit availability info
     */
    getTransitAvailability(lat, lng, radius = 200) {
        const nearbyStops = this.getNearbyTransportStops(lat, lng, radius);
        
        const types = new Set(nearbyStops.map(s => s.type));
        
        return {
            available: nearbyStops.length > 0,
            stops: nearbyStops,
            hasBus: types.has('bus'),
            hasTrain: types.has('train'),
            hasSubway: types.has('subway'),
            hasTram: types.has('tram'),
            hasFerry: types.has('ferry'),
            nearestStop: nearbyStops.length > 0 ? nearbyStops.reduce((nearest, stop) => {
                const dist = this.calculateDistance(lat, lng, stop.lat, stop.lng);
                if (!nearest || dist < nearest.distance) {
                    return { ...stop, distance: dist };
                }
                return nearest;
            }, null) : null
        };
    }

    /**
     * Get surface speed modifier for a position
     * @param {number} lat - Latitude
     * @param {number} lng - Longitude
     * @returns {number} Speed multiplier (0.4 to 1.0)
     */
    getSurfaceSpeedModifier(lat, lng) {
        // Speed modifiers by surface type
        const surfaceModifiers = {
            'asphalt': 1.0,
            'concrete': 1.0,
            'paved': 1.0,
            'paving_stones': 0.95,
            'sett': 0.9,
            'cobblestone': 0.85,
            'compacted': 0.85,
            'fine_gravel': 0.8,
            'gravel': 0.75,
            'pebblestone': 0.7,
            'dirt': 0.7,
            'earth': 0.65,
            'grass': 0.6,
            'sand': 0.5,
            'mud': 0.4,
            'unknown': 0.85
        };
        
        // Find nearest road segment and get its surface
        let nearestSurface = 'unknown';
        let minDistance = Infinity;
        
        for (const [id, data] of this.surfaceData) {
            for (const coord of data.coordinates) {
                const dist = this.calculateDistance(lat, lng, coord.lat, coord.lng);
                if (dist < minDistance && dist < 50) { // Within 50m
                    minDistance = dist;
                    nearestSurface = data.surface;
                }
            }
        }
        
        return surfaceModifiers[nearestSurface] || surfaceModifiers['unknown'];
    }

    /**
     * Calculate distance between two points in meters
     */
    calculateDistance(lat1, lng1, lat2, lng2) {
        const R = 6371000; // Earth's radius in meters
        const φ1 = lat1 * Math.PI / 180;
        const φ2 = lat2 * Math.PI / 180;
        const Δφ = (lat2 - lat1) * Math.PI / 180;
        const Δλ = (lng2 - lng1) * Math.PI / 180;

        const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
                  Math.cos(φ1) * Math.cos(φ2) *
                  Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return R * c;
    }

    /**
     * Get footpaths near a position
     * @param {number} lat - Latitude
     * @param {number} lng - Longitude
     * @param {number} radius - Search radius in meters
     * @returns {Array} Nearby footpaths
     */
    getNearbyFootpaths(lat, lng, radius = 100) {
        return this.footpaths.filter(path => {
            // Check if any point of the path is within radius
            for (const [pLat, pLng] of path.coordinates) {
                const distance = this.calculateDistance(lat, lng, pLat, pLng);
                if (distance <= radius) {
                    return true;
                }
            }
            return false;
        });
    }

    /**
     * Use random generation as fallback when APIs fail
     */
    useRandomGenerationFallback() {
        console.log('OSMDataService: Using random generation fallback');
        
        // Clear any partial data
        this.waterBodies = [];
        this.buildings = [];
        this.transportStops = [];
        this.footpaths = [];
        this.surfaceData.clear();
        
        // Generate some fake transport stops for gameplay
        if (this.bounds) {
            const { south, west, north, east } = this.bounds;
            const numStops = 20;
            
            for (let i = 0; i < numStops; i++) {
                const lat = south + Math.random() * (north - south);
                const lng = west + Math.random() * (east - west);
                const types = ['bus', 'train', 'subway'];
                const type = types[Math.floor(Math.random() * types.length)];
                
                this.transportStops.push({
                    id: `fallback-${i}`,
                    lat: lat,
                    lng: lng,
                    type: type,
                    name: `${type.charAt(0).toUpperCase() + type.slice(1)} Stop ${i + 1}`,
                    ref: `${i + 1}`,
                    operator: 'City Transit',
                    network: 'Metro',
                    routes: ''
                });
            }
        }
        
        console.log(`OSMDataService: Generated ${this.transportStops.length} fallback transport stops`);
    }

    /**
     * Load data from localStorage cache
     */
    loadFromCache() {
        try {
            const cached = localStorage.getItem(this.CACHE_KEY);
            if (!cached) return false;
            
            const data = JSON.parse(cached);
            
            // Check TTL
            if (Date.now() - data.timestamp > this.CACHE_TTL) {
                console.log('OSMDataService: Cache expired');
                this.clearCache();
                return false;
            }
            
            // Check bounds match
            if (JSON.stringify(data.bounds) !== JSON.stringify(this.bounds)) {
                console.log('OSMDataService: Cache bounds mismatch');
                return false;
            }
            
            // Restore data
            this.waterBodies = data.waterBodies || [];
            this.buildings = data.buildings || [];
            this.transportStops = data.transportStops || [];
            this.footpaths = data.footpaths || [];
            this.surfaceData = new Map(data.surfaceData || []);
            
            console.log('OSMDataService: Restored from cache');
            console.log(`  - Water bodies: ${this.waterBodies.length}`);
            console.log(`  - Buildings: ${this.buildings.length}`);
            console.log(`  - Transport stops: ${this.transportStops.length}`);
            console.log(`  - Footpaths: ${this.footpaths.length}`);
            
            return true;
        } catch (error) {
            console.warn('OSMDataService: Failed to load from cache:', error);
            return false;
        }
    }

    /**
     * Save data to localStorage cache
     */
    saveToCache() {
        try {
            const data = {
                timestamp: Date.now(),
                bounds: this.bounds,
                waterBodies: this.waterBodies,
                buildings: this.buildings,
                transportStops: this.transportStops,
                footpaths: this.footpaths,
                surfaceData: Array.from(this.surfaceData.entries())
            };
            
            localStorage.setItem(this.CACHE_KEY, JSON.stringify(data));
            console.log('OSMDataService: Saved to cache');
        } catch (error) {
            console.warn('OSMDataService: Failed to save to cache:', error);
        }
    }

    /**
     * Clear the cache
     */
    clearCache() {
        localStorage.removeItem(this.CACHE_KEY);
        console.log('OSMDataService: Cache cleared');
    }

    /**
     * Get cache info
     */
    getCacheInfo() {
        try {
            const cached = localStorage.getItem(this.CACHE_KEY);
            if (!cached) return { exists: false };
            
            const data = JSON.parse(cached);
            const age = Date.now() - data.timestamp;
            const ageHours = (age / (1000 * 60 * 60)).toFixed(1);
            const ttlRemaining = Math.max(0, this.CACHE_TTL - age);
            const ttlRemainingHours = (ttlRemaining / (1000 * 60 * 60)).toFixed(1);
            
            return {
                exists: true,
                age: age,
                ageHours: ageHours,
                ttlRemaining: ttlRemaining,
                ttlRemainingHours: ttlRemainingHours,
                isExpired: age > this.CACHE_TTL,
                bounds: data.bounds,
                stats: {
                    waterBodies: data.waterBodies?.length || 0,
                    buildings: data.buildings?.length || 0,
                    transportStops: data.transportStops?.length || 0,
                    footpaths: data.footpaths?.length || 0
                }
            };
        } catch (error) {
            return { exists: false, error: error.message };
        }
    }

    /**
     * Format an address from building data
     */
    formatAddress(building) {
        if (!building || !building.address) return null;
        
        const { housenumber, street, city, postcode } = building.address;
        const parts = [];
        
        if (housenumber && street) {
            parts.push(`${housenumber} ${street}`);
        } else if (street) {
            parts.push(street);
        }
        
        if (city) parts.push(city);
        if (postcode) parts.push(postcode);
        
        return parts.length > 0 ? parts.join(', ') : null;
    }
}

// Export for use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = OSMDataService;
}
