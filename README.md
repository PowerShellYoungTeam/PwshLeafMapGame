# PowerShell Leafmap Game

An interactive map-based game that combines the power of PowerShell scripting with leaflet.js for dynamic, location-based gameplay.

## 🎮 Features

- **Interactive Map**: Built with Leaflet.js for smooth, responsive mapping
- **PowerShell Integration**: Use PowerShell scripts to generate game data and manage game state
- **Dynamic Content**: Locations, quests, and treasures generated programmatically
- **Responsive Design**: Works on desktop and mobile devices
- **Local Development**: No external dependencies required for basic gameplay

## 🚀 Quick Start

1. **Generate Game Data**:
   ```powershell
   .\scripts\Generate-GameData.ps1 -LocationCount 15 -City "New York"
   ```

2. **Start the Local Server**:
   ```powershell
   .\scripts\Start-Server.ps1 -Port 8080 -OpenBrowser
   ```

3. **Open your browser** to `http://localhost:8080` and start playing!

## 📁 Project Structure

```
PwshLeafMapGame/
├── index.html              # Main game interface
├── css/
│   └── style.css           # Game styling
├── js/
│   ├── app.js              # Main application logic
│   ├── map.js              # Leaflet map functionality
│   └── game.js             # Game engine and utilities
├── scripts/
│   ├── Generate-GameData.ps1   # Generate random game locations
│   ├── Game-Manager.ps1        # Manage game state and statistics
│   └── Start-Server.ps1        # Simple HTTP server
└── package.json            # Node.js dependencies (optional)
```

## 🎯 How to Play

1. **Load Game Data**: Click "Load Game Data" to populate the map with locations
2. **Explore**: Click on map markers to visit locations
3. **Collect Items**: Each location may contain items and award points
4. **Track Progress**: Your score and inventory are displayed in the sidebar

## 🔧 PowerShell Scripts

### Generate-GameData.ps1
Creates random game locations with various types:
- **Treasures**: High-value items and points
- **Quests**: Special challenges and rewards
- **Shops**: Places to trade items
- **Landmarks**: Cultural and historical sites
- **Mysteries**: Enigmatic locations with surprises

**Usage**:
```powershell
.\scripts\Generate-GameData.ps1 -LocationCount 20 -City "London" -OutputFile "london_game.json"
```

### Game-Manager.ps1
Manages game state and provides analytics:
- View game statistics
- Export data for web app
- Find nearby locations
- Track player progress

**Usage**:
```powershell
# Check game status
.\scripts\Game-Manager.ps1 -Action status -PlayerName "YourName"

# Export for web app
.\scripts\Game-Manager.ps1 -Action export

# Generate new data
.\scripts\Game-Manager.ps1 -Action generate
```

### Start-Server.ps1
Simple HTTP server for local development:
```powershell
.\scripts\Start-Server.ps1 -Port 8080 -OpenBrowser
```

## 🌍 Supported Cities

The game data generator includes coordinate bounds for:
- New York
- London
- Tokyo

You can easily add more cities by editing the `$cityBounds` hashtable in `Generate-GameData.ps1`.

## 💡 Customization Ideas

### Game Mechanics
- Add time-based challenges
- Implement player vs player features
- Create quest chains and storylines
- Add weather effects from real APIs

### PowerShell Integration
- Connect to real data sources (weather, traffic, events)
- Integrate with databases
- Create scheduled game events
- Build admin tools for game management

### Map Features
- Custom map tiles and themes
- Drawing tools for player annotations
- Geolocation for real-world integration
- Clustering for dense location areas

## 🔨 Development Setup

### Option 1: PowerShell Only (Recommended for beginners)
1. Use the included `Start-Server.ps1` script
2. No additional dependencies required

### Option 2: Node.js Development Server
1. Install Node.js
2. Run `npm install` to install dependencies
3. Use `npm start` to start the development server

## 📝 Game Data Format

The game uses JSON format for location data:

```json
{
  "id": "location_1",
  "lat": 40.7128,
  "lng": -74.0060,
  "name": "Treasure Cache #1",
  "type": "treasure",
  "description": "A hidden treasure awaits discovery!",
  "items": ["golden_coin", "precious_gem"],
  "points": 100,
  "experience": 50
}
```

## 🤝 Contributing

This is an experimental project perfect for learning and experimentation. Feel free to:
- Add new PowerShell scripts
- Enhance the web interface
- Create new game mechanics
- Improve the documentation

## 📜 License

MIT License - Feel free to use this code for learning and experimentation!

