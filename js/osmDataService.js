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

        // Rate limiting settings
        this.RATE_LIMIT_MS = 1000; // Minimum 1 second between API calls
        this.lastApiCall = 0;

        // Cached data
        this.waterBodies = [];      // GeoJSON polygons for water
        this.buildings = [];         // Buildings with addresses
        this.transportStops = [];    // Bus stops, train stations, etc.
        this.footpaths = [];         // Walkable paths
        this.surfaceData = new Map(); // Road surface types
        this.amenities = [];         // Points of interest (amenities)
        this.shops = [];             // Retail locations
        this.pois = [];              // General points of interest
        this.landUse = [];           // Land use zones

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
     * Rate limit API calls to avoid overwhelming the server
     */
    async rateLimit() {
        const now = Date.now();
        const timeSinceLastCall = now - this.lastApiCall;

        if (timeSinceLastCall < this.RATE_LIMIT_MS) {
            const waitTime = this.RATE_LIMIT_MS - timeSinceLastCall;
            console.log(`OSMDataService: Rate limiting - waiting ${waitTime}ms`);
            await this.delay(waitTime);
        }

        this.lastApiCall = Date.now();
    }

    /**
     * Load configuration from config.json
     * @param {string} configPath - Path to config file (default: 'Data/Maps/config.json')
     * @returns {Object|null} Configuration object or null if failed
     */
    async loadConfig(configPath = 'Data/Maps/config.json') {
        try {
            // Add cache-busting query parameter
            const cacheBuster = `?_=${Date.now()}`;
            const response = await fetch(configPath + cacheBuster);
            if (!response.ok) {
                console.warn(`OSMDataService: Config file not found at ${configPath}`);
                return null;
            }
            const config = await response.json();
            console.log('OSMDataService: Loaded config from', configPath);
            console.log('OSMDataService: Default city is:', config.defaultCity);
            console.log('OSMDataService: Available cities:', Object.keys(config.cities));
            return config;
        } catch (error) {
            console.warn('OSMDataService: Failed to load config:', error);
            return null;
        }
    }

    /**
     * Load OSM data from pre-downloaded local file
     * @param {string} cityName - Name of city to load (matches config.cities key)
     * @param {Object} config - Configuration object (optional, will load if not provided)
     * @returns {boolean} True if loaded successfully
     */
    async loadFromFile(cityName = null, config = null) {
        try {
            // Load config if not provided
            if (!config) {
                config = await this.loadConfig();
                if (!config) return false;
            }

            // Check if local file loading is enabled
            if (!config.settings?.useLocalFile) {
                console.log('OSMDataService: Local file loading disabled in config');
                return false;
            }

            // Determine which city to load
            let cityConfig = null;
            let dataFilePath = null;
            const osmDataPath = config.settings?.osmDataPath || 'Data/Maps/';

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

            let foundCity = cityName ? findCity(cityName) : null;
            if (foundCity) {
                cityConfig = foundCity.config;
                dataFilePath = osmDataPath + cityConfig.osmDataFile;
            } else {
                // Try to find matching city by bounds
                for (const [name, city] of Object.entries(config.cities)) {
                    if (this.boundsMatch(city.bounds, this.bounds)) {
                        cityConfig = city;
                        dataFilePath = osmDataPath + city.osmDataFile;
                        console.log(`OSMDataService: Matched bounds to city: ${name}`);
                        break;
                    }
                }
            }

            if (!dataFilePath) {
                console.log('OSMDataService: No matching local data file found for current bounds');
                return false;
            }

            // Fetch the OSM data file
            console.log(`OSMDataService: Loading from local file: ${dataFilePath}`);
            const response = await fetch(dataFilePath);
            if (!response.ok) {
                console.warn(`OSMDataService: Data file not found at ${dataFilePath}`);
                return false;
            }

            const data = await response.json();

            // Validate data structure
            if (!data.metadata || !data.bounds) {
                console.warn('OSMDataService: Invalid data file structure');
                return false;
            }

            // Optional: Check if bounds approximately match
            if (this.bounds && !this.boundsOverlap(data.bounds, this.bounds)) {
                console.warn('OSMDataService: Data file bounds do not overlap with requested bounds');
                if (!config.settings?.fallbackToApi) {
                    return false;
                }
            }

            // Apply maxItemsPerLayer limits from config
            const limits = config.settings?.maxItemsPerLayer || {};

            // Restore data with limits
            this.waterBodies = this.limitArray(data.waterBodies, limits.waterBodies);
            this.buildings = this.limitArray(data.buildings, limits.buildings);
            this.transportStops = this.limitArray(data.transportStops, limits.transportStops);
            this.footpaths = this.limitArray(data.footpaths, limits.footpaths);
            this.surfaceData = new Map(data.surfaceData || []);
            this.amenities = this.limitArray(data.amenities, limits.amenities);
            this.shops = this.limitArray(data.shops, limits.shops);
            this.pois = this.limitArray(data.pois, limits.pois);
            this.landUse = this.limitArray(data.landUse, limits.landUse);

            console.log('OSMDataService: Restored from local file');
            console.log(`  - Water bodies: ${this.waterBodies.length}`);
            console.log(`  - Buildings: ${this.buildings.length}`);
            console.log(`  - Transport stops: ${this.transportStops.length}`);
            console.log(`  - Footpaths: ${this.footpaths.length}`);
            console.log(`  - Amenities: ${this.amenities.length}`);
            console.log(`  - Shops: ${this.shops.length}`);
            console.log(`  - POIs: ${this.pois.length}`);
            console.log(`  - Land use zones: ${this.landUse.length}`);
            console.log(`  - Generated: ${data.metadata?.generatedAt || 'unknown'}`);

            return true;
        } catch (error) {
            console.warn('OSMDataService: Failed to load from file:', error);
            return false;
        }
    }

    /**
     * Check if two bounds objects match exactly
     */
    boundsMatch(bounds1, bounds2) {
        if (!bounds1 || !bounds2) return false;
        return bounds1.south === bounds2.south &&
            bounds1.west === bounds2.west &&
            bounds1.north === bounds2.north &&
            bounds1.east === bounds2.east;
    }

    /**
     * Check if two bounds objects overlap
     */
    boundsOverlap(bounds1, bounds2) {
        if (!bounds1 || !bounds2) return false;
        return !(bounds1.east < bounds2.west ||
            bounds1.west > bounds2.east ||
            bounds1.north < bounds2.south ||
            bounds1.south > bounds2.north);
    }

    /**
     * Limit array size for performance
     */
    limitArray(arr, limit) {
        if (!arr) return [];
        if (!limit || limit <= 0) return arr;
        return arr.slice(0, limit);
    }

    /**
     * Initialize the OSM data service for a city
     * @param {Object} bounds - {south, west, north, east} bounding box
     * @param {boolean} forceRefresh - Force refresh even if cache is valid
     * @param {string} cityName - Optional city name to load specific pre-downloaded data
     */
    async initialize(bounds, forceRefresh = false, cityName = null) {
        this.bounds = bounds;
        this.isLoading = true;
        this.loadError = null;

        if (this.onLoadStart) this.onLoadStart();

        console.log('OSMDataService: Initializing for bounds:', bounds);

        // Priority 1: Try to load from pre-downloaded local file
        if (!forceRefresh && await this.loadFromFile(cityName)) {
            console.log('OSMDataService: Loaded from local file');
            this.isLoading = false;
            this.isLoaded = true;
            if (this.onLoadComplete) this.onLoadComplete({ source: 'local-file' });
            return true;
        }

        // Priority 2: Check localStorage cache
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
     * Execute an Overpass query with timeout and retry logic
     * @param {string} query - Overpass QL query
     * @param {number} timeout - Server-side timeout in seconds
     * @param {number} maxRetries - Maximum number of retry attempts
     * @returns {Promise<Object>} Query results
     */
    async queryOverpass(query, timeout = 30, maxRetries = 2) {
        // Apply rate limiting before each API call
        await this.rateLimit();

        const endpoint = this.getEndpoint();
        const fullQuery = `[out:json][timeout:${timeout}];${query}`;

        console.log('OSMDataService: Querying Overpass:', endpoint);

        let lastError = null;

        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                // Client-side timeout using AbortController
                const controller = new AbortController();
                const clientTimeout = setTimeout(() => controller.abort(), (timeout + 10) * 1000);

                // Wait before retry (exponential backoff)
                if (attempt > 0) {
                    const delay = Math.min(1000 * Math.pow(2, attempt - 1), 5000);
                    console.log(`OSMDataService: Retry attempt ${attempt} after ${delay}ms delay`);
                    await this.delay(delay);
                }

                const response = await fetch(endpoint, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded'
                    },
                    body: 'data=' + encodeURIComponent(fullQuery),
                    signal: controller.signal
                });

                clearTimeout(clientTimeout);

                if (!response.ok) {
                    // Handle rate limiting (429) with longer backoff
                    if (response.status === 429) {
                        const retryAfter = response.headers.get('Retry-After') || 60;
                        console.warn(`OSMDataService: Rate limited, waiting ${retryAfter}s`);
                        if (attempt < maxRetries) {
                            await this.delay(parseInt(retryAfter) * 1000);
                            continue;
                        }
                    }
                    throw new Error(`Overpass API error: ${response.status} ${response.statusText}`);
                }

                const data = await response.json();

                // Validate response has expected structure
                if (!data || typeof data !== 'object') {
                    throw new Error('Invalid response format from Overpass API');
                }

                return data;

            } catch (error) {
                lastError = error;

                // Handle abort specifically
                if (error.name === 'AbortError') {
                    console.warn(`OSMDataService: Request timed out after ${timeout + 10}s`);
                    lastError = new Error('Request timed out');
                }

                // Don't retry on certain errors
                if (attempt === maxRetries || error.message.includes('Invalid response format')) {
                    break;
                }

                console.warn(`OSMDataService: Query attempt ${attempt + 1} failed:`, error.message);
            }
        }

        throw lastError || new Error('Query failed after all retries');
    }

    /**
     * Delay helper for retry logic
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * Fetch all required data from Overpass
     * Fetches sequentially to respect rate limiting
     */
    async fetchAllData() {
        const { south, west, north, east } = this.bounds;
        const bbox = `${south},${west},${north},${east}`;

        console.log('OSMDataService: Fetching all data for bbox:', bbox);

        // Fetch data sequentially to respect rate limiting
        // Critical data first, then enhanced data

        // Phase 1: Core data (required for basic gameplay)
        console.log('OSMDataService: Fetching core data...');
        this.waterBodies = await this.fetchWaterBodies(bbox);
        this.buildings = await this.fetchBuildings(bbox);
        this.transportStops = await this.fetchTransportStops(bbox);

        // Phase 2: Movement data
        console.log('OSMDataService: Fetching movement data...');
        this.footpaths = await this.fetchFootpaths(bbox);
        const surfaceElements = await this.fetchSurfaceData(bbox);
        this.processSurfaceData(surfaceElements);

        // Phase 3: Enhanced data (optional, for richer gameplay)
        console.log('OSMDataService: Fetching enhanced data...');
        try {
            this.amenities = await this.fetchAmenities(bbox);
            this.shops = await this.fetchShops(bbox);
            this.pois = await this.fetchPOIs(bbox);
            this.landUse = await this.fetchLandUse(bbox);
        } catch (error) {
            console.warn('OSMDataService: Enhanced data fetch failed (non-critical):', error);
            // Set defaults if enhanced data fails
            this.amenities = this.amenities || [];
            this.shops = this.shops || [];
            this.pois = this.pois || [];
            this.landUse = this.landUse || [];
        }

        console.log('OSMDataService: Data fetched successfully');
        console.log(`  - Water bodies: ${this.waterBodies.length}`);
        console.log(`  - Buildings: ${this.buildings.length}`);
        console.log(`  - Transport stops: ${this.transportStops.length}`);
        console.log(`  - Footpaths: ${this.footpaths.length}`);
        console.log(`  - Surface segments: ${this.surfaceData.size}`);
        console.log(`  - Amenities: ${this.amenities.length}`);
        console.log(`  - Shops: ${this.shops.length}`);
        console.log(`  - POIs: ${this.pois.length}`);
        console.log(`  - Land use zones: ${this.landUse.length}`);
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

        if (!data?.elements) {
            console.warn('OSMDataService: No water body elements in response');
            return waterBodies;
        }

        for (const element of data.elements) {
            try {
                if (element.type === 'way' && element.geometry?.length >= 3) {
                    const coordinates = element.geometry
                        .filter(p => this.isValidCoordinate(p.lat, p.lon))
                        .map(p => [p.lat, p.lon]);

                    if (coordinates.length >= 3) {
                        waterBodies.push({
                            type: 'polygon',
                            coordinates: coordinates,
                            tags: element.tags || {}
                        });
                    }
                } else if (element.type === 'relation' && element.members) {
                    // Handle multipolygon relations
                    for (const member of element.members) {
                        if (member.type === 'way' && member.geometry?.length >= 3) {
                            const coordinates = member.geometry
                                .filter(p => this.isValidCoordinate(p.lat, p.lon))
                                .map(p => [p.lat, p.lon]);

                            if (coordinates.length >= 3) {
                                waterBodies.push({
                                    type: 'polygon',
                                    coordinates: coordinates,
                                    tags: element.tags || {}
                                });
                            }
                        }
                    }
                }
            } catch (error) {
                console.warn('OSMDataService: Error parsing water body element:', error);
            }
        }

        return waterBodies;
    }

    /**
     * Validate that a coordinate pair is valid
     */
    isValidCoordinate(lat, lon) {
        return typeof lat === 'number' && !isNaN(lat) &&
            typeof lon === 'number' && !isNaN(lon) &&
            lat >= -90 && lat <= 90 &&
            lon >= -180 && lon <= 180;
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

        if (!data?.elements) {
            console.warn('OSMDataService: No building elements in response');
            return buildings;
        }

        for (const element of data.elements) {
            try {
                const lat = element.center?.lat || element.lat;
                const lon = element.center?.lon || element.lon;

                if (!this.isValidCoordinate(lat, lon)) {
                    continue;
                }

                const tags = element.tags || {};

                buildings.push({
                    id: element.id,
                    lat: lat,
                    lng: lon,
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
            } catch (error) {
                console.warn('OSMDataService: Error parsing building element:', error);
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

        if (!data?.elements) {
            console.warn('OSMDataService: No transport stop elements in response');
            return stops;
        }

        for (const element of data.elements) {
            try {
                if (!this.isValidCoordinate(element.lat, element.lon)) {
                    continue;
                }

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
            } catch (error) {
                console.warn('OSMDataService: Error parsing transport stop element:', error);
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

        if (!data?.elements) {
            console.warn('OSMDataService: No footpath elements in response');
            return paths;
        }

        for (const element of data.elements) {
            try {
                if (element.type === 'way' && element.geometry?.length >= 2) {
                    const coordinates = element.geometry
                        .filter(p => this.isValidCoordinate(p.lat, p.lon))
                        .map(p => [p.lat, p.lon]);

                    if (coordinates.length >= 2) {
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
            } catch (error) {
                console.warn('OSMDataService: Error parsing footpath element:', error);
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

        if (!Array.isArray(elements)) {
            console.warn('OSMDataService: Invalid surface data elements');
            return;
        }

        for (const element of elements) {
            try {
                if (element.type === 'way' && element.geometry?.length >= 2 && element.tags?.surface) {
                    // Store surface type with way geometry for lookup
                    const coords = element.geometry
                        .filter(p => this.isValidCoordinate(p.lat, p.lon))
                        .map(p => ({ lat: p.lat, lng: p.lon }));

                    if (coords.length >= 2) {
                        this.surfaceData.set(element.id, {
                            surface: element.tags.surface,
                            coordinates: coords,
                            highway: element.tags.highway || 'road'
                        });
                    }
                }
            } catch (error) {
                console.warn('OSMDataService: Error processing surface data element:', error);
            }
        }
    }

    // ========================================
    // NEW OSM DATA TYPES
    // ========================================

    /**
     * Fetch amenities (restaurants, ATMs, hospitals, etc.)
     * @param {string} bbox - Bounding box string
     * @returns {Promise<Array>} Array of amenity objects
     */
    async fetchAmenities(bbox) {
        const query = `
            (
                node["amenity"~"restaurant|cafe|bar|pub|fast_food|bank|atm|hospital|clinic|pharmacy|fuel|parking"](${bbox});
                way["amenity"~"restaurant|cafe|bar|pub|fast_food|bank|atm|hospital|clinic|pharmacy|fuel|parking"](${bbox});
            );
            out center;
        `;

        try {
            const data = await this.queryOverpass(query);
            return this.parseAmenities(data);
        } catch (error) {
            console.warn('OSMDataService: Failed to fetch amenities:', error);
            return [];
        }
    }

    /**
     * Parse amenity data
     */
    parseAmenities(data) {
        const amenities = [];

        if (!data?.elements) {
            console.warn('OSMDataService: No amenity elements in response');
            return amenities;
        }

        for (const element of data.elements) {
            try {
                const lat = element.center?.lat || element.lat;
                const lon = element.center?.lon || element.lon;

                if (!this.isValidCoordinate(lat, lon)) {
                    continue;
                }

                const tags = element.tags || {};

                amenities.push({
                    id: element.id,
                    lat: lat,
                    lng: lon,
                    type: tags.amenity || 'unknown',
                    name: tags.name || this.formatAmenityName(tags.amenity),
                    cuisine: tags.cuisine || '',
                    openingHours: tags.opening_hours || '',
                    wheelchair: tags.wheelchair || '',
                    phone: tags.phone || '',
                    website: tags.website || ''
                });
            } catch (error) {
                console.warn('OSMDataService: Error parsing amenity element:', error);
            }
        }

        return amenities;
    }

    /**
     * Format amenity type into readable name
     */
    formatAmenityName(amenityType) {
        if (!amenityType) return 'Unknown';
        return amenityType
            .split('_')
            .map(word => word.charAt(0).toUpperCase() + word.slice(1))
            .join(' ');
    }

    /**
     * Fetch shops and retail locations
     * @param {string} bbox - Bounding box string
     * @returns {Promise<Array>} Array of shop objects
     */
    async fetchShops(bbox) {
        const query = `
            (
                node["shop"](${bbox});
                way["shop"](${bbox});
            );
            out center;
        `;

        try {
            const data = await this.queryOverpass(query);
            return this.parseShops(data);
        } catch (error) {
            console.warn('OSMDataService: Failed to fetch shops:', error);
            return [];
        }
    }

    /**
     * Parse shop data
     */
    parseShops(data) {
        const shops = [];

        if (!data?.elements) {
            console.warn('OSMDataService: No shop elements in response');
            return shops;
        }

        for (const element of data.elements) {
            try {
                const lat = element.center?.lat || element.lat;
                const lon = element.center?.lon || element.lon;

                if (!this.isValidCoordinate(lat, lon)) {
                    continue;
                }

                const tags = element.tags || {};

                shops.push({
                    id: element.id,
                    lat: lat,
                    lng: lon,
                    shopType: tags.shop || 'general',
                    name: tags.name || this.formatShopName(tags.shop),
                    brand: tags.brand || '',
                    openingHours: tags.opening_hours || '',
                    wheelchair: tags.wheelchair || '',
                    phone: tags.phone || '',
                    website: tags.website || ''
                });
            } catch (error) {
                console.warn('OSMDataService: Error parsing shop element:', error);
            }
        }

        return shops;
    }

    /**
     * Format shop type into readable name
     */
    formatShopName(shopType) {
        if (!shopType) return 'Shop';
        return shopType
            .split('_')
            .map(word => word.charAt(0).toUpperCase() + word.slice(1))
            .join(' ');
    }

    /**
     * Fetch general points of interest (tourism, leisure, historic)
     * @param {string} bbox - Bounding box string
     * @returns {Promise<Array>} Array of POI objects
     */
    async fetchPOIs(bbox) {
        const query = `
            (
                node["tourism"~"hotel|hostel|motel|attraction|museum|viewpoint|information"](${bbox});
                node["leisure"~"park|playground|sports_centre|fitness_centre|swimming_pool"](${bbox});
                node["historic"~"monument|memorial|castle|ruins"](${bbox});
                way["tourism"](${bbox});
                way["leisure"~"park|playground|sports_centre"](${bbox});
            );
            out center;
        `;

        try {
            const data = await this.queryOverpass(query);
            return this.parsePOIs(data);
        } catch (error) {
            console.warn('OSMDataService: Failed to fetch POIs:', error);
            return [];
        }
    }

    /**
     * Parse POI data
     */
    parsePOIs(data) {
        const pois = [];

        if (!data?.elements) {
            console.warn('OSMDataService: No POI elements in response');
            return pois;
        }

        for (const element of data.elements) {
            try {
                const lat = element.center?.lat || element.lat;
                const lon = element.center?.lon || element.lon;

                if (!this.isValidCoordinate(lat, lon)) {
                    continue;
                }

                const tags = element.tags || {};

                // Determine POI category
                let category = 'unknown';
                let subtype = '';

                if (tags.tourism) {
                    category = 'tourism';
                    subtype = tags.tourism;
                } else if (tags.leisure) {
                    category = 'leisure';
                    subtype = tags.leisure;
                } else if (tags.historic) {
                    category = 'historic';
                    subtype = tags.historic;
                }

                pois.push({
                    id: element.id,
                    lat: lat,
                    lng: lon,
                    category: category,
                    subtype: subtype,
                    name: tags.name || this.formatPOIName(subtype),
                    description: tags.description || '',
                    openingHours: tags.opening_hours || '',
                    fee: tags.fee || '',
                    wheelchair: tags.wheelchair || '',
                    website: tags.website || ''
                });
            } catch (error) {
                console.warn('OSMDataService: Error parsing POI element:', error);
            }
        }

        return pois;
    }

    /**
     * Format POI subtype into readable name
     */
    formatPOIName(subtype) {
        if (!subtype) return 'Point of Interest';
        return subtype
            .split('_')
            .map(word => word.charAt(0).toUpperCase() + word.slice(1))
            .join(' ');
    }

    /**
     * Fetch land use zones (residential, commercial, industrial, etc.)
     * @param {string} bbox - Bounding box string
     * @returns {Promise<Array>} Array of land use zone objects
     */
    async fetchLandUse(bbox) {
        const query = `
            (
                way["landuse"~"residential|commercial|industrial|retail|farmland|forest|grass|meadow|recreation_ground"](${bbox});
                relation["landuse"](${bbox});
            );
            out geom;
        `;

        try {
            const data = await this.queryOverpass(query);
            return this.parseLandUse(data);
        } catch (error) {
            console.warn('OSMDataService: Failed to fetch land use data:', error);
            return [];
        }
    }

    /**
     * Parse land use data
     */
    parseLandUse(data) {
        const landUse = [];

        if (!data?.elements) {
            console.warn('OSMDataService: No land use elements in response');
            return landUse;
        }

        for (const element of data.elements) {
            try {
                if (element.type === 'way' && element.geometry?.length >= 3) {
                    const coordinates = element.geometry
                        .filter(p => this.isValidCoordinate(p.lat, p.lon))
                        .map(p => [p.lat, p.lon]);

                    if (coordinates.length >= 3) {
                        const tags = element.tags || {};

                        landUse.push({
                            id: element.id,
                            type: 'polygon',
                            landUseType: tags.landuse || 'unknown',
                            coordinates: coordinates,
                            name: tags.name || '',
                            speedModifier: this.getLandUseSpeedModifier(tags.landuse)
                        });
                    }
                } else if (element.type === 'relation' && element.members) {
                    // Handle multipolygon relations
                    for (const member of element.members) {
                        if (member.type === 'way' && member.geometry?.length >= 3 && member.role === 'outer') {
                            const coordinates = member.geometry
                                .filter(p => this.isValidCoordinate(p.lat, p.lon))
                                .map(p => [p.lat, p.lon]);

                            if (coordinates.length >= 3) {
                                const tags = element.tags || {};

                                landUse.push({
                                    id: element.id,
                                    type: 'polygon',
                                    landUseType: tags.landuse || 'unknown',
                                    coordinates: coordinates,
                                    name: tags.name || '',
                                    speedModifier: this.getLandUseSpeedModifier(tags.landuse)
                                });
                            }
                        }
                    }
                }
            } catch (error) {
                console.warn('OSMDataService: Error parsing land use element:', error);
            }
        }

        return landUse;
    }

    /**
     * Get speed modifier for land use type
     */
    getLandUseSpeedModifier(landUseType) {
        const modifiers = {
            'residential': 1.0,
            'commercial': 1.0,
            'industrial': 0.9,
            'retail': 1.0,
            'farmland': 0.7,
            'forest': 0.5,
            'grass': 0.7,
            'meadow': 0.6,
            'recreation_ground': 0.9,
            'unknown': 0.8
        };
        return modifiers[landUseType] || modifiers['unknown'];
    }

    // ========================================
    // HELPER METHODS FOR NEW DATA TYPES
    // ========================================

    /**
     * Get nearby amenities
     * @param {number} lat - Center latitude
     * @param {number} lng - Center longitude
     * @param {number} radius - Search radius in meters
     * @param {string} type - Optional amenity type filter
     * @returns {Array} Nearby amenities
     */
    getNearbyAmenities(lat, lng, radius = 500, type = null) {
        return this.amenities.filter(amenity => {
            const distance = this.calculateDistance(lat, lng, amenity.lat, amenity.lng);
            if (distance > radius) return false;
            if (type && amenity.type !== type) return false;
            return true;
        });
    }

    /**
     * Get nearby shops
     * @param {number} lat - Center latitude
     * @param {number} lng - Center longitude
     * @param {number} radius - Search radius in meters
     * @param {string} shopType - Optional shop type filter
     * @returns {Array} Nearby shops
     */
    getNearbyShops(lat, lng, radius = 500, shopType = null) {
        return this.shops.filter(shop => {
            const distance = this.calculateDistance(lat, lng, shop.lat, shop.lng);
            if (distance > radius) return false;
            if (shopType && shop.shopType !== shopType) return false;
            return true;
        });
    }

    /**
     * Get nearby POIs
     * @param {number} lat - Center latitude
     * @param {number} lng - Center longitude
     * @param {number} radius - Search radius in meters
     * @param {string} category - Optional category filter (tourism, leisure, historic)
     * @returns {Array} Nearby POIs
     */
    getNearbyPOIs(lat, lng, radius = 500, category = null) {
        return this.pois.filter(poi => {
            const distance = this.calculateDistance(lat, lng, poi.lat, poi.lng);
            if (distance > radius) return false;
            if (category && poi.category !== category) return false;
            return true;
        });
    }

    /**
     * Get land use type at position
     * @param {number} lat - Latitude
     * @param {number} lng - Longitude
     * @returns {Object|null} Land use info or null if not in any zone
     */
    getLandUseAt(lat, lng) {
        if (!this.isLoaded || this.landUse.length === 0) {
            return null;
        }

        // Use Turf.js if available for accurate polygon check
        if (typeof turf !== 'undefined') {
            const point = turf.point([lng, lat]);

            for (const zone of this.landUse) {
                if (zone.coordinates.length >= 3) {
                    try {
                        const polygonCoords = zone.coordinates.map(c => [c[1], c[0]]);
                        if (polygonCoords[0][0] !== polygonCoords[polygonCoords.length - 1][0] ||
                            polygonCoords[0][1] !== polygonCoords[polygonCoords.length - 1][1]) {
                            polygonCoords.push(polygonCoords[0]);
                        }
                        const polygon = turf.polygon([polygonCoords]);
                        if (turf.booleanPointInPolygon(point, polygon)) {
                            return zone;
                        }
                    } catch (e) {
                        // Invalid polygon, skip
                    }
                }
            }
        }

        return null;
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
        this.amenities = [];
        this.shops = [];
        this.pois = [];
        this.landUse = [];

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
            this.amenities = data.amenities || [];
            this.shops = data.shops || [];
            this.pois = data.pois || [];
            this.landUse = data.landUse || [];

            console.log('OSMDataService: Restored from cache');
            console.log(`  - Water bodies: ${this.waterBodies.length}`);
            console.log(`  - Buildings: ${this.buildings.length}`);
            console.log(`  - Transport stops: ${this.transportStops.length}`);
            console.log(`  - Footpaths: ${this.footpaths.length}`);
            console.log(`  - Amenities: ${this.amenities.length}`);
            console.log(`  - Shops: ${this.shops.length}`);
            console.log(`  - POIs: ${this.pois.length}`);
            console.log(`  - Land use zones: ${this.landUse.length}`);

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
                surfaceData: Array.from(this.surfaceData.entries()),
                amenities: this.amenities,
                shops: this.shops,
                pois: this.pois,
                landUse: this.landUse
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
                    footpaths: data.footpaths?.length || 0,
                    amenities: data.amenities?.length || 0,
                    shops: data.shops?.length || 0,
                    pois: data.pois?.length || 0,
                    landUse: data.landUse?.length || 0
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
