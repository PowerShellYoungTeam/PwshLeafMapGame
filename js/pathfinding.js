// pathfinding.js
// Client-side pathfinding with OSRM and fallback options

class PathfindingManager {
    constructor(map) {
        this.map = map;
        this.osrmUrl = 'https://router.project-osrm.org/route/v1';
        this.routeCache = new Map();
        this.currentPath = null;
        this.pathLayer = null;
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

        // Long distance with vehicle: use OSRM
        if (travelMode !== 'foot') {
            try {
                const osrmPath = await this.getOSRMPath(start, destination, travelMode);
                return osrmPath;
            } catch (error) {
                console.warn('OSRM routing failed, falling back to direct path:', error);
                return this.getDirectPath(start, destination, travelMode);
            }
        }

        // Long distance on foot: warn but provide path
        return this.getDirectPath(start, destination, travelMode);
    }

    /**
     * Get road-based path from OSRM
     */
    async getOSRMPath(start, destination, travelMode) {
        // Check cache
        const cacheKey = `${start.lat},${start.lng}-${destination.lat},${destination.lng}-${travelMode}`;
        if (this.routeCache.has(cacheKey)) {
            console.log('Using cached route');
            return this.routeCache.get(cacheKey);
        }

        // Determine OSRM profile
        const profile = travelMode === 'foot' ? 'foot' : 'driving';

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
            travelMode: travelMode
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
        const duration = this.calculateTravelTime(distance, travelMode);

        const path = {
            coordinates: [start, destination],
            distance: distance,
            duration: duration,
            type: 'direct',
            travelMode: travelMode
        };

        console.log(`Direct path: ${path.distance}m, ${path.duration}s`);

        return path;
    }

    /**
     * Calculate travel time based on mode and distance
     */
    calculateTravelTime(distance, travelMode) {
        const speeds = {
            'foot': 1.4,        // m/s (5 km/h)
            'car': 13.9,        // m/s (50 km/h city)
            'motorcycle': 16.7, // m/s (60 km/h)
            'van': 11.1,        // m/s (40 km/h)
            'aerial': 20        // m/s (72 km/h)
        };

        const speed = speeds[travelMode] || speeds['foot'];
        return distance / speed; // seconds
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
     * Animate unit movement along path
     */
    animateMovement(unitMarker, path, speed = 1.0, onComplete = null) {
        if (!path || !path.coordinates || path.coordinates.length < 2) {
            console.warn('Invalid path for animation');
            if (onComplete) onComplete();
            return;
        }

        let currentIndex = 0;
        const totalPoints = path.coordinates.length;
        const baseInterval = 100; // ms per step
        const interval = baseInterval / speed;

        const moveStep = () => {
            if (currentIndex >= totalPoints) {
                console.log('Movement animation complete');
                if (onComplete) onComplete();
                return;
            }

            const currentPos = path.coordinates[currentIndex];
            unitMarker.setLatLng(currentPos);

            currentIndex++;
            setTimeout(moveStep, interval);
        };

        moveStep();
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
