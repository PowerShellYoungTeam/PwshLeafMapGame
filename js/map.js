// Map functionality using Leaflet
class GameMap {
    constructor(containerId, gameInstance) {
        this.game = gameInstance;
        this.markers = [];
        this.playerMarker = null;
        this.playerPosition = null;
        this.pathfindingManager = null;
        this.moveMode = 'foot'; // Default travel mode

        // Initialize the map centered on New York City
        this.map = L.map(containerId).setView([40.7128, -74.0060], 11);

        // Add tile layer (you can change this to different map styles)
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '© OpenStreetMap contributors'
        }).addTo(this.map);

        // Alternative tile layers you can use:
        // Dark theme:
        // L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        //     attribution: '© OpenStreetMap contributors, © CARTO'
        // }).addTo(this.map);

        // Initialize pathfinding
        this.pathfindingManager = new PathfindingManager(this.map);

        // Set up click-to-move
        this.setupClickToMove();

        console.log('GameMap initialized with pathfinding');
    }

    /**
     * Set up click-to-move functionality
     */
    setupClickToMove() {
        this.map.on('click', async (e) => {
            if (!this.playerMarker) {
                console.warn('No player marker set. Call setPlayerPosition first.');
                return;
            }

            const destination = e.latlng;
            console.log(`Map clicked at [${destination.lat}, ${destination.lng}]`);

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

            // Start movement animation
            this.startPlayerMovement(path);
        });
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

        // Animate movement
        this.pathfindingManager.animateMovement(
            this.playerMarker,
            path,
            5.0, // Speed multiplier for demo
            () => {
                // On complete
                this.playerPosition = path.coordinates[path.coordinates.length - 1];
                console.log(`Player arrived at [${this.playerPosition.lat}, ${this.playerPosition.lng}]`);

                // Send completion to PowerShell
                if (this.game && this.game.communicationBridge) {
                    this.game.communicationBridge.sendEvent('movement.completed', {
                        unitId: 'player',
                        position: {
                            lat: this.playerPosition.lat,
                            lng: this.playerPosition.lng
                        }
                    });
                }

                // Clear path after arrival
                setTimeout(() => {
                    this.pathfindingManager.clearPath();
                }, 2000);
            }
        );
    }

    /**
     * Set travel mode
     */
    setTravelMode(mode) {
        const validModes = ['foot', 'car', 'motorcycle', 'van', 'aerial'];
        if (validModes.includes(mode)) {
            this.moveMode = mode;
            console.log(`Travel mode set to: ${mode}`);
        } else {
            console.warn(`Invalid travel mode: ${mode}. Use one of: ${validModes.join(', ')}`);
        }
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
            // Set up button click handler after popup opens
            setTimeout(() => {
                const button = document.getElementById(`visit-btn-${markerId}`);
                if (button) {
                    button.onclick = () => {
                        this.game.visitLocation(marker.locationData);
                        this.updateMarkerAfterVisit(marker, marker.locationData);
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

        return `
            <div style="min-width: 200px;">
                <h3>${location.name}</h3>
                <p>${location.description}</p>
                ${pointsInfo}
                ${itemsList}
                <button id="visit-btn-${markerId}"
                        style="
                            background-color: #3498db;
                            color: white;
                            border: none;
                            padding: 5px 10px;
                            border-radius: 3px;
                            cursor: pointer;
                            margin-top: 10px;
                        ">
                    Visit Location
                </button>
            </div>
        `;
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
