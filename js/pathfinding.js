// pathfinding.js
// Client-side pathfinding with multiple routing service support

class PathfindingManager {
    constructor(map) {
        this.map = map;
        // OSRM public server only supports 'driving' profile
        this.osrmUrl = 'https://router.project-osrm.org/route/v1';
        // OpenRouteService for pedestrian routing (free tier: 2000 req/day)
        // Get your free API key at: https://openrouteservice.org/dev/#/signup
        this.openRouteServiceUrl = 'https://api.openrouteservice.org/v2/directions';
        this.openRouteServiceApiKey = null; // Set via setOpenRouteServiceApiKey()
        this.routeCache = new Map();
        this.currentPath = null;
        this.pathLayer = null;
        this.osmDataService = null; // Will be set by GameMap
    }

    /**
     * Set OpenRouteService API key for pedestrian routing
     * Get a free key at: https://openrouteservice.org/dev/#/signup
     * @param {string} apiKey - Your ORS API key
     */
    setOpenRouteServiceApiKey(apiKey) {
        this.openRouteServiceApiKey = apiKey;
        console.log('OpenRouteService API key configured for pedestrian routing');
    }

    /**
     * Set the OSM data service for terrain/surface queries
     */
    setOSMDataService(service) {
        this.osmDataService = service;
    }

    /**
     * Find a path from start to destination
     * @param {L.LatLng} start - Starting position
     * @param {L.LatLng} destination - Target position
     * @param {string} travelMode - 'foot', 'car', 'motorcycle', 'van', 'aerial'
     * @returns {Promise<Object>} Path object with coordinates, distance, duration
     */
    async findPath(start, destination, travelMode = 'foot') {
        console.log(`Finding path from [${start.lat}, ${start.lng}] to [${destination.lat}, ${destination.lng}] via ${travelMode}`);

        // Calculate straight-line distance
        const distance = start.distanceTo(destination);

        // Short distance: use direct path
        if (distance < 500) {
            return this.getDirectPath(start, destination, travelMode);
        }

        // Aerial: always use direct path (ignores roads)
        if (travelMode === 'aerial') {
            return this.getDirectPath(start, destination, travelMode);
        }

        // Foot travel: use OpenRouteService (proper pedestrian routing)
        if (travelMode === 'foot') {
            try {
                const footPath = await this.getOpenRouteServicePath(start, destination);
                return footPath;
            } catch (error) {
                console.warn('OpenRouteService pedestrian routing failed:', error.message);
                // Fallback to OSRM driving as last resort (better than straight line)
                try {
                    console.log('Falling back to road-based routing...');
                    const roadPath = await this.getOSRMPath(start, destination, 'driving');
                    roadPath.travelMode = 'foot'; // Override mode for timing
                    roadPath.duration = roadPath.distance / 1.4; // Recalc for walking speed
                    return roadPath;
                } catch (e) {
                    console.warn('All routing failed, using direct path');
                    return this.getDirectPath(start, destination, travelMode);
                }
            }
        }

        // Vehicle travel: use OSRM (driving profile)
        try {
            const osrmPath = await this.getOSRMPath(start, destination, travelMode);
            return osrmPath;
        } catch (error) {
            console.warn('OSRM routing failed, falling back to direct path:', error);
            return this.getDirectPath(start, destination, travelMode);
        }
    }

    /**
     * Get pedestrian path from OpenRouteService
     * Uses sidewalks, crossings, avoids buildings/water/barriers
     */
    async getOpenRouteServicePath(start, destination) {
        // Check cache
        const cacheKey = `ors-foot-${start.lat},${start.lng}-${destination.lat},${destination.lng}`;
        if (this.routeCache.has(cacheKey)) {
            console.log('Using cached pedestrian route');
            return this.routeCache.get(cacheKey);
        }

        if (!this.openRouteServiceApiKey) {
            throw new Error('OpenRouteService API key not configured. Get a free key at https://openrouteservice.org/dev/#/signup');
        }

        // ORS foot-walking profile uses pedestrian infrastructure
        const url = `${this.openRouteServiceUrl}/foot-walking?api_key=${this.openRouteServiceApiKey}&start=${start.lng},${start.lat}&end=${destination.lng},${destination.lat}`;

        console.log('Fetching OpenRouteService pedestrian route...');

        const response = await fetch(url);

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`ORS API error ${response.status}: ${errorText}`);
        }

        const data = await response.json();

        if (!data.features || data.features.length === 0) {
            throw new Error('No pedestrian route found');
        }

        // Parse GeoJSON response
        const feature = data.features[0];
        const coordinates = feature.geometry.coordinates.map(c => L.latLng(c[1], c[0]));
        const properties = feature.properties.summary;

        const path = {
            coordinates: coordinates,
            distance: properties.distance, // meters
            duration: properties.duration, // seconds
            type: 'pedestrian',
            travelMode: 'foot',
            routingService: 'openrouteservice'
        };

        // Cache the route
        this.routeCache.set(cacheKey, path);

        console.log(`Pedestrian route found: ${path.distance.toFixed(0)}m, ${(path.duration / 60).toFixed(1)}min (via sidewalks/crossings)`);

        return path;
    }

    /**
     * Get road-based path from OSRM (driving only - public server limitation)
     */
    async getOSRMPath(start, destination, travelMode) {
        // Check cache
        const cacheKey = `osrm-${start.lat},${start.lng}-${destination.lat},${destination.lng}-${travelMode}`;
        if (this.routeCache.has(cacheKey)) {
            console.log('Using cached route');
            return this.routeCache.get(cacheKey);
        }

        // OSRM public demo only supports 'driving' profile
        const profile = 'driving';

        // Build OSRM URL
        const url = `${this.osrmUrl}/${profile}/${start.lng},${start.lat};${destination.lng},${destination.lat}?overview=full&geometries=geojson`;

        console.log('Fetching OSRM route:', url);

        const response = await fetch(url);
        const data = await response.json();

        if (data.code !== 'Ok' || !data.routes || data.routes.length === 0) {
            throw new Error(`OSRM routing failed: ${data.code || 'No routes found'}`);
        }

        // Parse route
        const route = data.routes[0];
        const coordinates = route.geometry.coordinates.map(c => L.latLng(c[1], c[0]));

        const path = {
            coordinates: coordinates,
            distance: route.distance, // meters
            duration: route.duration, // seconds
            type: 'road',
            travelMode: travelMode,
            routingService: 'osrm'
        };

        // Cache the route
        this.routeCache.set(cacheKey, path);

        console.log(`OSRM route found: ${path.distance}m, ${path.duration}s`);

        return path;
    }

    /**
     * Get direct line path (fallback)
     */
    getDirectPath(start, destination, travelMode) {
        const distance = start.distanceTo(destination);

        // Get surface modifier for the path
        const surfaceModifier = this.getPathSurfaceModifier([start, destination]);
        const duration = this.calculateTravelTime(distance, travelMode, surfaceModifier);

        const path = {
            coordinates: [start, destination],
            distance: distance,
            duration: duration,
            type: 'direct',
            travelMode: travelMode,
            surfaceModifier: surfaceModifier
        };

        console.log(`Direct path: ${path.distance}m, ${path.duration}s (surface modifier: ${surfaceModifier.toFixed(2)})`);

        return path;
    }

    /**
     * Calculate travel time based on mode and distance
     * @param {number} distance - Distance in meters
     * @param {string} travelMode - Travel mode
     * @param {number} surfaceModifier - Optional surface speed modifier (0.4 to 1.0)
     */
    calculateTravelTime(distance, travelMode, surfaceModifier = 1.0) {
        const speeds = {
            'foot': 1.4,        // m/s (5 km/h)
            'car': 13.9,        // m/s (50 km/h city)
            'motorcycle': 16.7, // m/s (60 km/h)
            'van': 11.1,        // m/s (40 km/h)
            'transit': 8.3,     // m/s (30 km/h average including stops)
            'aerial': 20        // m/s (72 km/h)
        };

        const speed = speeds[travelMode] || speeds['foot'];

        // Apply surface modifier (mainly affects foot/bike travel)
        const effectiveModifier = (travelMode === 'foot') ? surfaceModifier :
            (travelMode === 'motorcycle') ? Math.max(0.7, surfaceModifier) : 1.0;

        return distance / (speed * effectiveModifier); // seconds
    }

    /**
     * Get average surface modifier for a path
     * @param {Array} coordinates - Path coordinates
     * @returns {number} Average surface speed modifier
     */
    getPathSurfaceModifier(coordinates) {
        if (!this.osmDataService || coordinates.length < 2) {
            return 1.0;
        }

        let totalModifier = 0;
        let sampleCount = 0;

        // Calculate total path distance for dynamic sampling
        let totalDistance = 0;
        for (let i = 1; i < coordinates.length; i++) {
            const prev = coordinates[i - 1];
            const curr = coordinates[i];
            const prevLatLng = L.latLng(prev.lat || prev[0], prev.lng || prev[1]);
            const currLatLng = L.latLng(curr.lat || curr[0], curr.lng || curr[1]);
            totalDistance += prevLatLng.distanceTo(currLatLng);
        }

        // Dynamic sampling: 1 point per 50m, minimum 10, maximum 100 samples
        const targetSamples = Math.min(100, Math.max(10, Math.floor(totalDistance / 50)));
        const sampleInterval = Math.max(1, Math.floor(coordinates.length / targetSamples));

        for (let i = 0; i < coordinates.length; i += sampleInterval) {
            const coord = coordinates[i];
            const lat = coord.lat || coord[0];
            const lng = coord.lng || coord[1];

            const modifier = this.osmDataService.getSurfaceSpeedModifier(lat, lng);
            totalModifier += modifier;
            sampleCount++;
        }

        return sampleCount > 0 ? totalModifier / sampleCount : 1.0;
    }

    /**
     * Display path on map
     */
    showPath(path, color = '#3388ff') {
        // Remove existing path
        this.clearPath();

        // Create polyline
        this.pathLayer = L.polyline(path.coordinates, {
            color: color,
            weight: 4,
            opacity: 0.7,
            dashArray: path.type === 'direct' ? '10, 10' : null
        }).addTo(this.map);

        // Add markers
        const startMarker = L.circleMarker(path.coordinates[0], {
            radius: 6,
            fillColor: '#00ff00',
            fillOpacity: 1,
            color: '#ffffff',
            weight: 2
        }).addTo(this.map);

        const endMarker = L.circleMarker(path.coordinates[path.coordinates.length - 1], {
            radius: 8,
            fillColor: '#ff0000',
            fillOpacity: 1,
            color: '#ffffff',
            weight: 2
        }).addTo(this.map);

        // Store for cleanup
        this.currentPath = {
            layer: this.pathLayer,
            startMarker: startMarker,
            endMarker: endMarker,
            data: path
        };

        // Fit map to path
        this.map.fitBounds(this.pathLayer.getBounds(), { padding: [50, 50] });

        console.log(`Path displayed: ${path.type} (${path.distance}m, ${Math.round(path.duration)}s)`);

        return this.currentPath;
    }

    /**
     * Clear displayed path
     */
    clearPath() {
        if (this.currentPath) {
            if (this.currentPath.layer) {
                this.map.removeLayer(this.currentPath.layer);
            }
            if (this.currentPath.startMarker) {
                this.map.removeLayer(this.currentPath.startMarker);
            }
            if (this.currentPath.endMarker) {
                this.map.removeLayer(this.currentPath.endMarker);
            }
            this.currentPath = null;
        }
    }

    /**
     * Animate unit movement along path with smooth interpolation
     * @param {L.Marker} unitMarker - The marker to animate
     * @param {Object} path - Path object with coordinates array
     * @param {number} speed - Speed multiplier (1.0 = normal)
     * @param {Function} onComplete - Callback when animation completes
     * @param {Function} onProgress - Optional callback with progress updates
     * @returns {Object} Animation controller with pause/resume/cancel methods
     */
    animateMovement(unitMarker, path, speed = 1.0, onComplete = null, onProgress = null) {
        if (!path || !path.coordinates || path.coordinates.length < 2) {
            console.warn('Invalid path for animation');
            if (onComplete) onComplete();
            return null;
        }

        // Resample path for smoother animation (target ~60fps visual smoothness)
        const smoothedPath = this.resamplePath(path.coordinates, 50); // 50m between points max

        let currentIndex = 0;
        let animationFrame = null;
        let isPaused = false;
        let isCancelled = false;
        let lastTimestamp = null;
        let accumulatedTime = 0;

        // Calculate time per segment based on path duration
        const totalDuration = (path.duration / speed) * 1000; // ms
        const timePerPoint = totalDuration / smoothedPath.length;
        const startTime = performance.now();

        // Store initial position for cancel/return
        const startPosition = smoothedPath[0];

        const animate = (timestamp) => {
            if (isCancelled) return;
            if (isPaused) {
                animationFrame = requestAnimationFrame(animate);
                lastTimestamp = null;
                return;
            }

            if (!lastTimestamp) lastTimestamp = timestamp;
            const deltaTime = timestamp - lastTimestamp;
            lastTimestamp = timestamp;
            accumulatedTime += deltaTime;

            // Move to next point(s) based on accumulated time
            while (accumulatedTime >= timePerPoint && currentIndex < smoothedPath.length - 1) {
                accumulatedTime -= timePerPoint;
                currentIndex++;
            }

            if (currentIndex >= smoothedPath.length - 1) {
                // Ensure we end at exact destination
                unitMarker.setLatLng(smoothedPath[smoothedPath.length - 1]);
                console.log('Movement animation complete');
                if (onProgress) {
                    onProgress({
                        progress: 1.0,
                        currentPosition: smoothedPath[smoothedPath.length - 1],
                        distanceRemaining: 0,
                        timeRemaining: 0
                    });
                }
                if (onComplete) onComplete();
                return;
            }

            // Interpolate between current and next point for extra smoothness
            const currentPos = smoothedPath[currentIndex];
            const nextPos = smoothedPath[currentIndex + 1];
            const segmentProgress = accumulatedTime / timePerPoint;

            const interpolatedLat = currentPos.lat + (nextPos.lat - currentPos.lat) * segmentProgress;
            const interpolatedLng = currentPos.lng + (nextPos.lng - currentPos.lng) * segmentProgress;
            const interpolatedPos = L.latLng(interpolatedLat, interpolatedLng);

            unitMarker.setLatLng(interpolatedPos);

            // Update marker rotation to face direction of movement
            if (unitMarker.setRotationAngle) {
                const bearing = this.calculateBearing(currentPos, nextPos);
                unitMarker.setRotationAngle(bearing);
            }

            // Report progress
            if (onProgress) {
                const progress = currentIndex / (smoothedPath.length - 1);
                const elapsed = timestamp - startTime;
                const timeRemaining = Math.max(0, totalDuration - elapsed);
                const distanceRemaining = path.distance * (1 - progress);

                onProgress({
                    progress: progress,
                    currentPosition: interpolatedPos,
                    distanceRemaining: Math.round(distanceRemaining),
                    timeRemaining: Math.round(timeRemaining / 1000)
                });
            }

            animationFrame = requestAnimationFrame(animate);
        };

        // Start animation
        animationFrame = requestAnimationFrame(animate);

        // Return controller object
        return {
            pause: () => {
                isPaused = true;
                console.log('Movement paused');
            },
            resume: () => {
                isPaused = false;
                console.log('Movement resumed');
            },
            cancel: (returnToStart = false) => {
                isCancelled = true;
                if (animationFrame) cancelAnimationFrame(animationFrame);
                if (returnToStart) {
                    unitMarker.setLatLng(startPosition);
                }
                console.log('Movement cancelled');
            },
            setSpeed: (newSpeed) => {
                // Recalculate time per point for new speed
                speed = newSpeed;
            },
            isPaused: () => isPaused,
            getProgress: () => currentIndex / (smoothedPath.length - 1)
        };
    }

    /**
     * Resample path to have points at regular intervals
     * @param {Array} coordinates - Original coordinates
     * @param {number} maxDistance - Maximum distance between points in meters
     * @returns {Array} Resampled coordinates
     */
    resamplePath(coordinates, maxDistance = 50) {
        if (coordinates.length < 2) return coordinates;

        const result = [coordinates[0]];
        let accumulated = 0;

        for (let i = 1; i < coordinates.length; i++) {
            const prev = coordinates[i - 1];
            const curr = coordinates[i];
            const prevLatLng = L.latLng(prev.lat || prev[0], prev.lng || prev[1]);
            const currLatLng = L.latLng(curr.lat || curr[0], curr.lng || curr[1]);
            const segmentDist = prevLatLng.distanceTo(currLatLng);

            if (segmentDist > maxDistance) {
                // Add intermediate points
                const numPoints = Math.ceil(segmentDist / maxDistance);
                for (let j = 1; j <= numPoints; j++) {
                    const t = j / numPoints;
                    const lat = (prev.lat || prev[0]) + ((curr.lat || curr[0]) - (prev.lat || prev[0])) * t;
                    const lng = (prev.lng || prev[1]) + ((curr.lng || curr[1]) - (prev.lng || prev[1])) * t;
                    result.push(L.latLng(lat, lng));
                }
            } else {
                result.push(L.latLng(curr.lat || curr[0], curr.lng || curr[1]));
            }
        }

        return result;
    }

    /**
     * Calculate bearing between two points
     * @param {L.LatLng} start - Start position
     * @param {L.LatLng} end - End position
     * @returns {number} Bearing in degrees (0-360)
     */
    calculateBearing(start, end) {
        const startLat = (start.lat || start[0]) * Math.PI / 180;
        const startLng = (start.lng || start[1]) * Math.PI / 180;
        const endLat = (end.lat || end[0]) * Math.PI / 180;
        const endLng = (end.lng || end[1]) * Math.PI / 180;

        const dLng = endLng - startLng;
        const x = Math.sin(dLng) * Math.cos(endLat);
        const y = Math.cos(startLat) * Math.sin(endLat) - Math.sin(startLat) * Math.cos(endLat) * Math.cos(dLng);

        let bearing = Math.atan2(x, y) * 180 / Math.PI;
        return (bearing + 360) % 360;
    }

    /**
     * Get current path info
     */
    getCurrentPath() {
        return this.currentPath;
    }

    /**
     * Clear route cache
     */
    clearCache() {
        this.routeCache.clear();
        console.log('Route cache cleared');
    }
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = PathfindingManager;
}
