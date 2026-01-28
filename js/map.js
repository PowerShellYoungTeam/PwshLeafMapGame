// Map functionality using Leaflet
class GameMap {
    constructor(containerId, gameInstance) {
        this.game = gameInstance;
        this.markers = [];
        this.playerMarker = null;
        this.playerPosition = null;
        this.pathfindingManager = null;
        this.osmDataService = null;
        this.moveMode = 'foot'; // Default travel mode
        this.isMoving = false;
        this.transportStopMarkers = []; // For transit stop display
        this.footpathLayer = null; // For walkable paths overlay
        this.showingFootpaths = false;

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
     */
    async initOSMDataService() {
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
        };
        
        this.osmDataService.onLoadError = (error) => {
            console.error('OSM data load error:', error);
            this.updateGameStatus('Map data load failed, using fallback');
        };
        
        // Get current map bounds and initialize
        const bounds = this.map.getBounds();
        const osmBounds = {
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
        
        await this.osmDataService.initialize(osmBounds);
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
                dashArray: '5, 5'
            }).addTo(this.map);
        }
        
        console.log(`Displayed ${pathLines.length} footpaths`);
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
