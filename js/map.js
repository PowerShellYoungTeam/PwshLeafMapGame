// Map functionality using Leaflet
class GameMap {
    constructor(containerId, gameInstance) {
        this.game = gameInstance;
        this.markers = [];

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

        console.log('GameMap initialized');
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

        // Create popup content
        const popupContent = this.createPopupContent(location);
        marker.bindPopup(popupContent);

        // Add click event
        marker.on('click', () => {
            this.game.visitLocation(location);
            this.updateMarkerAfterVisit(marker, location);
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

    createPopupContent(location) {
        let itemsList = '';
        if (location.items && location.items.length > 0) {
            itemsList = `
                <h4>Items:</h4>
                <ul>
                    ${location.items.map(item => `<li>${item.replace('_', ' ')}</li>`).join('')}
                </ul>
            `;
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
                <button onclick="window.game.visitLocation(${JSON.stringify(location).replace(/"/g, '&quot;')})"
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
