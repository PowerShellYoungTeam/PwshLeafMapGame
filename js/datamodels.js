/**
 * JavaScript Data Models for PowerShell Leafmap Game
 * Client-side implementation of the core game entities
 */

// Base Entity Class
class GameEntity {
    constructor(data = {}) {
        this.Id = data.Id || this.generateGuid();
        this.Type = data.Type || 'Entity';
        this.Name = data.Name || '';
        this.Description = data.Description || '';
        this.Tags = data.Tags || {};
        this.Metadata = data.Metadata || {};
        this.CreatedAt = data.CreatedAt ? new Date(data.CreatedAt) : new Date();
        this.UpdatedAt = data.UpdatedAt ? new Date(data.UpdatedAt) : new Date();
        this.Version = data.Version || '1.0.0';
        this.IsActive = data.IsActive !== undefined ? data.IsActive : true;
        this.CustomProperties = data.CustomProperties || {};
    }

    generateGuid() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
            const r = Math.random() * 16 | 0;
            const v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    toPlainObject() {
        return {
            Id: this.Id,
            Type: this.Type,
            Name: this.Name,
            Description: this.Description,
            Tags: this.Tags,
            Metadata: this.Metadata,
            CreatedAt: this.CreatedAt.toISOString(),
            UpdatedAt: this.UpdatedAt.toISOString(),
            Version: this.Version,
            IsActive: this.IsActive,
            CustomProperties: this.CustomProperties
        };
    }

    toJSON() {
        return JSON.stringify(this.toPlainObject());
    }

    updateTimestamp() {
        this.UpdatedAt = new Date();
    }

    validate() {
        const errors = [];

        if (!this.Id || typeof this.Id !== 'string') {
            errors.push('Id is required and must be a string');
        }

        if (!this.Type || typeof this.Type !== 'string') {
            errors.push('Type is required and must be a string');
        }

        if (!this.Name || typeof this.Name !== 'string') {
            errors.push('Name is required and must be a string');
        }

        return {
            isValid: errors.length === 0,
            errors: errors
        };
    }
}

// Player Entity Class
class Player extends GameEntity {
    constructor(data = {}) {
        super(data);
        this.Type = 'Player';

        // Identity Properties
        this.Username = data.Username || '';
        this.Email = data.Email || '';
        this.DisplayName = data.DisplayName || '';

        // Character Properties
        this.Level = data.Level || 1;
        this.Experience = data.Experience || 0;
        this.ExperienceToNext = data.ExperienceToNext || 1000;
        this.Attributes = data.Attributes || this.getDefaultAttributes();
        this.Skills = data.Skills || this.getDefaultSkills();

        // Game State
        this.Location = data.Location || {};
        this.LastLocationId = data.LastLocationId || '';
        this.VisitedLocations = data.VisitedLocations || [];
        this.Score = data.Score || 0;
        this.GameState = data.GameState || 'Active';

        // Inventory & Equipment
        this.Inventory = data.Inventory || [];
        this.Equipment = data.Equipment || this.getDefaultEquipment();
        this.InventoryCapacity = data.InventoryCapacity || 30;
        this.Currency = data.Currency || 100;

        // Progress & Achievements
        this.Achievements = data.Achievements || [];
        this.QuestProgress = data.QuestProgress || {};
        this.Statistics = data.Statistics || this.getDefaultStatistics();
        this.CompletedQuests = data.CompletedQuests || [];

        // Social & Multiplayer
        this.Friends = data.Friends || [];
        this.GuildId = data.GuildId || null;
        this.Reputation = data.Reputation || {};

        // Preferences & Settings
        this.Preferences = data.Preferences || this.getDefaultPreferences();
        this.UISettings = data.UISettings || this.getDefaultUISettings();
        this.Theme = data.Theme || 'Default';

        // Session Data
        this.LastLogin = data.LastLogin ? new Date(data.LastLogin) : new Date();
        this.PlayTime = data.PlayTime || 0; // in milliseconds
        this.SessionStart = data.SessionStart ? new Date(data.SessionStart) : new Date();
        this.IsOnline = data.IsOnline !== undefined ? data.IsOnline : true;

        // Backup & Recovery
        this.BackupData = data.BackupData || '';
        this.LastBackup = data.LastBackup ? new Date(data.LastBackup) : new Date();
    }

    getDefaultAttributes() {
        return {
            Strength: { Base: 10, Current: 10, Modifiers: [], Maximum: 20 },
            Dexterity: { Base: 10, Current: 10, Modifiers: [], Maximum: 20 },
            Intelligence: { Base: 10, Current: 10, Modifiers: [], Maximum: 20 },
            Constitution: { Base: 10, Current: 10, Modifiers: [], Maximum: 20 },
            Wisdom: { Base: 10, Current: 10, Modifiers: [], Maximum: 20 },
            Charisma: { Base: 10, Current: 10, Modifiers: [], Maximum: 20 }
        };
    }

    getDefaultSkills() {
        return {
            Combat: { Level: 1, Experience: 0, Specializations: [] },
            Exploration: { Level: 1, Experience: 0, Specializations: [] },
            Social: { Level: 1, Experience: 0, Specializations: [] },
            Crafting: { Level: 1, Experience: 0, Specializations: [] }
        };
    }

    getDefaultEquipment() {
        return {
            Head: null, Chest: null, Legs: null, Feet: null,
            MainHand: null, OffHand: null, Ring1: null, Ring2: null
        };
    }

    getDefaultStatistics() {
        return {
            LocationsVisited: 0,
            QuestsCompleted: 0,
            ItemsCollected: 0,
            EnemiesDefeated: 0,
            DistanceTraveled: 0,
            TimePlayedHours: 0
        };
    }

    getDefaultPreferences() {
        return {
            AutoSave: true,
            ShowTutorials: true,
            DifficultyLevel: 'Normal',
            SoundEnabled: true,
            MusicEnabled: true
        };
    }

    getDefaultUISettings() {
        return {
            Theme: 'Default',
            FontSize: 'Medium',
            ShowMinimap: true,
            ShowHealthBar: true,
            ShowExperienceBar: true
        };
    }

    toPlainObject() {
        const baseData = super.toPlainObject();
        return {
            ...baseData,
            Username: this.Username,
            Email: this.Email,
            DisplayName: this.DisplayName,
            Level: this.Level,
            Experience: this.Experience,
            ExperienceToNext: this.ExperienceToNext,
            Attributes: this.Attributes,
            Skills: this.Skills,
            Location: this.Location,
            LastLocationId: this.LastLocationId,
            VisitedLocations: this.VisitedLocations,
            Score: this.Score,
            GameState: this.GameState,
            Inventory: this.Inventory,
            Equipment: this.Equipment,
            InventoryCapacity: this.InventoryCapacity,
            Currency: this.Currency,
            Achievements: this.Achievements,
            QuestProgress: this.QuestProgress,
            Statistics: this.Statistics,
            CompletedQuests: this.CompletedQuests,
            Friends: this.Friends,
            GuildId: this.GuildId,
            Reputation: this.Reputation,
            Preferences: this.Preferences,
            UISettings: this.UISettings,
            Theme: this.Theme,
            LastLogin: this.LastLogin.toISOString(),
            PlayTime: this.PlayTime,
            SessionStart: this.SessionStart.toISOString(),
            IsOnline: this.IsOnline,
            BackupData: this.BackupData,
            LastBackup: this.LastBackup.toISOString()
        };
    }

    addExperience(amount) {
        this.Experience += amount;
        this.updateTimestamp();

        // Check for level up
        while (this.Experience >= this.ExperienceToNext) {
            this.levelUp();
        }
    }

    levelUp() {
        this.Level++;
        this.Experience -= this.ExperienceToNext;
        this.ExperienceToNext = Math.floor(this.ExperienceToNext * 1.2);
        this.updateTimestamp();
    }

    visitLocation(locationId) {
        if (!this.VisitedLocations.includes(locationId)) {
            this.VisitedLocations.push(locationId);
        }
        this.LastLocationId = locationId;
        this.Statistics.LocationsVisited = this.VisitedLocations.length;
        this.updateTimestamp();
    }

    addAchievement(achievement) {
        this.Achievements.push(achievement);
        this.updateTimestamp();
    }

    hasAchievement(achievementId) {
        return this.Achievements.some(achievement => achievement.Id === achievementId);
    }

    validate() {
        const baseValidation = super.validate();
        const playerErrors = [];

        if (this.Level < 1 || this.Level > 100) {
            playerErrors.push('Player level must be between 1 and 100');
        }

        if (this.Experience < 0) {
            playerErrors.push('Player experience cannot be negative');
        }

        if (!this.Username || typeof this.Username !== 'string') {
            playerErrors.push('Username is required and must be a string');
        }

        return {
            isValid: baseValidation.isValid && playerErrors.length === 0,
            errors: [...baseValidation.errors, ...playerErrors]
        };
    }
}

// NPC Entity Class
class NPC extends GameEntity {
    constructor(data = {}) {
        super(data);
        this.Type = 'NPC';

        // Identity
        this.NPCType = data.NPCType || 'Generic';
        this.Race = data.Race || 'Human';
        this.Gender = data.Gender || 'Unknown';
        this.Age = data.Age || 'Adult';

        // Appearance
        this.Appearance = data.Appearance || {};
        this.Portrait = data.Portrait || '';
        this.Animations = data.Animations || [];

        // Behavior
        this.AIBehavior = data.AIBehavior || {};
        this.PersonalityType = data.PersonalityType || 'Neutral';
        this.DialogueOptions = data.DialogueOptions || [];
        this.Reactions = data.Reactions || {};

        // Location & Movement
        this.SpawnLocation = data.SpawnLocation || {};
        this.PatrolRoute = data.PatrolRoute || [];
        this.MovementSpeed = data.MovementSpeed || 1.0;
        this.IsStationary = data.IsStationary !== undefined ? data.IsStationary : true;

        // Interaction
        this.AvailableServices = data.AvailableServices || [];
        this.Inventory = data.Inventory || {};
        this.QuestsOffered = data.QuestsOffered || [];
        this.RelationshipData = data.RelationshipData || {};

        // Combat (if applicable)
        this.CombatStats = data.CombatStats || {};
        this.Abilities = data.Abilities || [];
        this.Faction = data.Faction || 'Neutral';
        this.HostilityLevel = data.HostilityLevel || 'Neutral';

        // Schedule & Availability
        this.Schedule = data.Schedule || {};
        this.AvailableHours = data.AvailableHours || [];
        this.IsCurrentlyAvailable = data.IsCurrentlyAvailable !== undefined ? data.IsCurrentlyAvailable : true;
    }

    toPlainObject() {
        const baseData = super.toPlainObject();
        return {
            ...baseData,
            NPCType: this.NPCType,
            Race: this.Race,
            Gender: this.Gender,
            Age: this.Age,
            Appearance: this.Appearance,
            Portrait: this.Portrait,
            Animations: this.Animations,
            AIBehavior: this.AIBehavior,
            PersonalityType: this.PersonalityType,
            DialogueOptions: this.DialogueOptions,
            Reactions: this.Reactions,
            SpawnLocation: this.SpawnLocation,
            PatrolRoute: this.PatrolRoute,
            MovementSpeed: this.MovementSpeed,
            IsStationary: this.IsStationary,
            AvailableServices: this.AvailableServices,
            Inventory: this.Inventory,
            QuestsOffered: this.QuestsOffered,
            RelationshipData: this.RelationshipData,
            CombatStats: this.CombatStats,
            Abilities: this.Abilities,
            Faction: this.Faction,
            HostilityLevel: this.HostilityLevel,
            Schedule: this.Schedule,
            AvailableHours: this.AvailableHours,
            IsCurrentlyAvailable: this.IsCurrentlyAvailable
        };
    }

    validate() {
        const baseValidation = super.validate();
        const npcErrors = [];

        if (!this.NPCType || typeof this.NPCType !== 'string') {
            npcErrors.push('NPCType is required and must be a string');
        }

        if (this.MovementSpeed < 0) {
            npcErrors.push('Movement speed cannot be negative');
        }

        return {
            isValid: baseValidation.isValid && npcErrors.length === 0,
            errors: [...baseValidation.errors, ...npcErrors]
        };
    }
}

// Item Entity Class
class Item extends GameEntity {
    constructor(data = {}) {
        super(data);
        this.Type = 'Item';

        // Core Properties
        this.ItemType = data.ItemType || 'Generic';
        this.Rarity = data.Rarity || 'Common';
        this.StackSize = data.StackSize || 1;
        this.Weight = data.Weight || 0.1;
        this.Value = data.Value || 1;
        this.IconPath = data.IconPath || '';

        // Usage Properties
        this.IsConsumable = data.IsConsumable !== undefined ? data.IsConsumable : false;
        this.IsEquippable = data.IsEquippable !== undefined ? data.IsEquippable : false;
        this.IsTradeable = data.IsTradeable !== undefined ? data.IsTradeable : true;
        this.IsDroppable = data.IsDroppable !== undefined ? data.IsDroppable : true;
        this.Durability = data.Durability || 100;
        this.MaxDurability = data.MaxDurability || 100;

        // Requirements
        this.Requirements = data.Requirements || {};
        this.LevelRequirement = data.LevelRequirement || 1;
        this.ClassRestrictions = data.ClassRestrictions || [];

        // Effects
        this.Effects = data.Effects || [];
        this.Bonuses = data.Bonuses || {};
        this.EnchantmentSlots = data.EnchantmentSlots || [];
        this.CurrentEnchantments = data.CurrentEnchantments || [];

        // Crafting
        this.IsCraftable = data.IsCraftable !== undefined ? data.IsCraftable : false;
        this.CraftingRecipe = data.CraftingRecipe || [];
        this.CraftingSkill = data.CraftingSkill || '';
        this.CraftingLevel = data.CraftingLevel || 1;

        // Lore & Story
        this.FlavorText = data.FlavorText || '';
        this.OriginStory = data.OriginStory || '';
        this.IsQuestItem = data.IsQuestItem !== undefined ? data.IsQuestItem : false;
        this.QuestId = data.QuestId || null;
    }

    toPlainObject() {
        const baseData = super.toPlainObject();
        return {
            ...baseData,
            ItemType: this.ItemType,
            Rarity: this.Rarity,
            StackSize: this.StackSize,
            Weight: this.Weight,
            Value: this.Value,
            IconPath: this.IconPath,
            IsConsumable: this.IsConsumable,
            IsEquippable: this.IsEquippable,
            IsTradeable: this.IsTradeable,
            IsDroppable: this.IsDroppable,
            Durability: this.Durability,
            MaxDurability: this.MaxDurability,
            Requirements: this.Requirements,
            LevelRequirement: this.LevelRequirement,
            ClassRestrictions: this.ClassRestrictions,
            Effects: this.Effects,
            Bonuses: this.Bonuses,
            EnchantmentSlots: this.EnchantmentSlots,
            CurrentEnchantments: this.CurrentEnchantments,
            IsCraftable: this.IsCraftable,
            CraftingRecipe: this.CraftingRecipe,
            CraftingSkill: this.CraftingSkill,
            CraftingLevel: this.CraftingLevel,
            FlavorText: this.FlavorText,
            OriginStory: this.OriginStory,
            IsQuestItem: this.IsQuestItem,
            QuestId: this.QuestId
        };
    }

    repairItem(amount = -1) {
        if (amount === -1) {
            this.Durability = this.MaxDurability;
        } else {
            this.Durability = Math.min(this.Durability + amount, this.MaxDurability);
        }
        this.updateTimestamp();
    }

    damageItem(amount) {
        this.Durability = Math.max(this.Durability - amount, 0);
        this.updateTimestamp();
    }

    isFullyRepaired() {
        return this.Durability === this.MaxDurability;
    }

    isBroken() {
        return this.Durability === 0;
    }

    validate() {
        const baseValidation = super.validate();
        const itemErrors = [];

        if (!this.ItemType || typeof this.ItemType !== 'string') {
            itemErrors.push('ItemType is required and must be a string');
        }

        if (this.Value < 0) {
            itemErrors.push('Item value cannot be negative');
        }

        if (this.Weight < 0) {
            itemErrors.push('Item weight cannot be negative');
        }

        if (this.StackSize < 1) {
            itemErrors.push('Stack size must be at least 1');
        }

        if (this.Durability < 0 || this.Durability > this.MaxDurability) {
            itemErrors.push('Durability must be between 0 and MaxDurability');
        }

        return {
            isValid: baseValidation.isValid && itemErrors.length === 0,
            errors: [...baseValidation.errors, ...itemErrors]
        };
    }
}

// Factory Functions
class EntityFactory {
    static createPlayer(username, email, displayName, additionalData = {}) {
        const playerData = {
            Username: username,
            Email: email,
            DisplayName: displayName,
            Name: displayName,
            Description: `Player character for ${username}`,
            ...additionalData
        };

        return new Player(playerData);
    }

    static createNPC(name, npcType, description = '', additionalData = {}) {
        const npcData = {
            Name: name,
            NPCType: npcType,
            Description: description,
            ...additionalData
        };

        return new NPC(npcData);
    }

    static createItem(name, itemType, description = '', additionalData = {}) {
        const itemData = {
            Name: name,
            ItemType: itemType,
            Description: description,
            ...additionalData
        };

        return new Item(itemData);
    }

    static fromJSON(jsonString, entityType = null) {
        try {
            const data = JSON.parse(jsonString);
            return this.fromPlainObject(data, entityType);
        } catch (error) {
            console.error('Failed to parse JSON:', error);
            return null;
        }
    }

    static fromPlainObject(data, entityType = null) {
        const type = entityType || data.Type;

        switch (type) {
            case 'Player':
                return new Player(data);
            case 'NPC':
                return new NPC(data);
            case 'Item':
                return new Item(data);
            default:
                return new GameEntity(data);
        }
    }
}

// Validation Utilities
class EntityValidator {
    static validateEntity(entity, entityType = null) {
        if (!entity) {
            return {
                isValid: false,
                errors: ['Entity is null or undefined'],
                warnings: []
            };
        }

        const validation = entity.validate();
        const warnings = [];

        // Type-specific warnings
        const typeToValidate = entityType || entity.Type;
        switch (typeToValidate) {
            case 'Player':
                if (entity.Level > 50) {
                    warnings.push('Player level is quite high, ensure this is intentional');
                }
                break;
            case 'NPC':
                if (entity.NPCType === 'Generic') {
                    warnings.push('NPC should have a more specific type defined');
                }
                break;
            case 'Item':
                if (entity.Value === 0) {
                    warnings.push('Item has no value, consider if this is intentional');
                }
                break;
        }

        return {
            isValid: validation.isValid,
            errors: validation.errors,
            warnings: warnings
        };
    }

    static validateCollection(entities) {
        const results = {
            totalEntities: entities.length,
            validEntities: 0,
            invalidEntities: 0,
            errors: [],
            warnings: []
        };

        entities.forEach((entity, index) => {
            const validation = this.validateEntity(entity);
            if (validation.isValid) {
                results.validEntities++;
            } else {
                results.invalidEntities++;
                validation.errors.forEach(error => {
                    results.errors.push(`Entity ${index}: ${error}`);
                });
            }

            validation.warnings.forEach(warning => {
                results.warnings.push(`Entity ${index}: ${warning}`);
            });
        });

        return results;
    }
}

// Communication Helper
class PowerShellBridge {
    static async sendEntityToPowerShell(entity, endpoint = '/api/entity') {
        try {
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: entity.toJSON()
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Failed to send entity to PowerShell:', error);
            throw error;
        }
    }

    static async getEntityFromPowerShell(entityId, entityType, endpoint = '/api/entity') {
        try {
            const response = await fetch(`${endpoint}/${entityId}?type=${entityType}`);

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            return EntityFactory.fromPlainObject(data);
        } catch (error) {
            console.error('Failed to get entity from PowerShell:', error);
            throw error;
        }
    }
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        GameEntity,
        Player,
        NPC,
        Item,
        EntityFactory,
        EntityValidator,
        PowerShellBridge
    };
}

// Export for browser environments
if (typeof window !== 'undefined') {
    window.GameModels = {
        GameEntity,
        Player,
        NPC,
        Item,
        EntityFactory,
        EntityValidator,
        PowerShellBridge
    };
}
