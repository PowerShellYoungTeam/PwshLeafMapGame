// Game logic and state management
class GameEngine {
    constructor() {
        this.gameState = {
            level: 1,
            experience: 0,
            health: 100,
            visitedLocations: [],
            completedQuests: [],
            achievements: []
        };

        this.questSystem = new QuestSystem();
    }

    processLocationVisit(location) {
        // Check if location was already visited
        if (this.gameState.visitedLocations.includes(location.id)) {
            return {
                success: false,
                message: 'You have already visited this location.'
            };
        }

        // Mark as visited
        this.gameState.visitedLocations.push(location.id);

        // Process location rewards
        let rewards = {
            experience: location.experience || 10,
            items: location.items || [],
            points: location.points || 0
        };

        // Add experience
        this.addExperience(rewards.experience);

        // Check for quest completion
        const questResult = this.questSystem.checkQuestCompletion(location);
        if (questResult.completed) {
            rewards.questReward = questResult.reward;
        }

        return {
            success: true,
            rewards: rewards,
            message: `Successfully visited ${location.name}!`
        };
    }

    addExperience(exp) {
        this.gameState.experience += exp;

        // Check for level up
        const newLevel = Math.floor(this.gameState.experience / 100) + 1;
        if (newLevel > this.gameState.level) {
            this.gameState.level = newLevel;
            return { leveledUp: true, newLevel: newLevel };
        }

        return { leveledUp: false };
    }

    saveGameState() {
        // Save to localStorage
        localStorage.setItem('pwshLeafmapGameState', JSON.stringify(this.gameState));
    }

    loadGameState() {
        const saved = localStorage.getItem('pwshLeafmapGameState');
        if (saved) {
            this.gameState = JSON.parse(saved);
            return true;
        }
        return false;
    }

    exportGameStateForPowerShell() {
        // Export game state in a format that PowerShell can easily process
        return JSON.stringify(this.gameState, null, 2);
    }
}

class QuestSystem {
    constructor() {
        this.activeQuests = [];
        this.questTemplates = [
            {
                id: 'explorer',
                name: 'Explorer',
                description: 'Visit 5 different locations',
                requirement: { type: 'visit_count', target: 5 },
                reward: { experience: 100, items: ['explorer_badge'] }
            },
            {
                id: 'treasure_hunter',
                name: 'Treasure Hunter',
                description: 'Find 3 treasures',
                requirement: { type: 'treasure_count', target: 3 },
                reward: { experience: 200, items: ['treasure_map'] }
            }
        ];
    }

    checkQuestCompletion(location) {
        // This would contain logic to check if visiting this location completes any quests
        // For now, return a simple response
        return { completed: false, reward: null };
    }

    getActiveQuests() {
        return this.activeQuests;
    }

    startQuest(questId) {
        const template = this.questTemplates.find(q => q.id === questId);
        if (template && !this.activeQuests.find(q => q.id === questId)) {
            this.activeQuests.push({ ...template, progress: 0, started: new Date() });
            return true;
        }
        return false;
    }
}

// Utility functions that can be called from PowerShell integration
window.GameUtils = {
    // Function to update game data from PowerShell script results
    updateGameFromPowerShell: function (jsonData) {
        try {
            const data = JSON.parse(jsonData);
            if (window.game && window.game.gameMap) {
                window.game.gameMap.addMarkersFromPowerShellData(JSON.stringify(data.locations));
                window.game.updateGameInfo('Game updated from PowerShell script!');
            }
            return { success: true, message: 'Game updated successfully' };
        } catch (error) {
            console.error('Error updating from PowerShell:', error);
            return { success: false, message: error.message };
        }
    },

    // Function to get current game state for PowerShell
    getGameStateForPowerShell: function () {
        if (window.game) {
            return {
                score: window.game.score,
                inventory: window.game.inventory,
                mapBounds: window.game.gameMap.getCurrentBounds(),
                gameData: window.game.gameData
            };
        }
        return null;
    },

    // Function to execute PowerShell commands (this would need backend integration)
    executePowerShellCommand: async function (command) {
        // This is a placeholder - in a real implementation, you'd need to:
        // 1. Send the command to a backend service
        // 2. Execute the PowerShell command server-side
        // 3. Return the result

        console.log(`Would execute PowerShell command: ${command}`);
        return {
            success: true,
            output: `Mock output for command: ${command}`,
            data: []
        };
    }
};
