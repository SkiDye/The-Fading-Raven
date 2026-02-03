# Data Definitions - Session 1

## Overview

This document defines all game data structures for The Fading Raven.

---

## Crew Class Data Structure

```javascript
{
    id: string,           // Class identifier
    name: string,         // Display name (Korean)
    nameEn: string,       // Display name (English)
    baseSquadSize: number,// Default squad size
    weapon: string,       // Weapon description
    role: string,         // Role description
    color: string,        // Hex color code

    // Base stats
    stats: {
        damage: number,
        attackSpeed: number,   // ms between attacks
        moveSpeed: number,     // pixels per second
        attackRange: number,   // pixels
    },

    // Skill definition
    skill: {
        id: string,
        name: string,
        type: string,         // 'direction' | 'position' | 'self'
        baseCooldown: number, // ms
        levels: [
            { effect: object, cost: number },
            { effect: object, cost: number },
            { effect: object, cost: number },
        ]
    },

    // Strengths and weaknesses
    strengths: string[],
    weaknesses: string[],
}
```

---

## Equipment Data Structure

```javascript
{
    id: string,
    name: string,         // Korean name
    nameEn: string,       // English name
    desc: string,         // Description
    type: string,         // 'passive' | 'active_cooldown' | 'active_charges'
    baseCost: number,     // Purchase cost
    recommendedClass: string[], // Recommended classes

    levels: [
        {
            effect: object,     // Level-specific effect
            upgradeCost: number,// Cost to upgrade to this level
        },
        // ... up to 3 levels
    ],

    // For active equipment
    cooldown?: number,    // ms (for active_cooldown)
    charges?: number,     // Uses per stage (for active_charges)
}
```

---

## Trait Data Structure

```javascript
{
    id: string,
    name: string,         // Korean name
    nameEn: string,       // English name
    category: string,     // 'combat' | 'utility' | 'economy'
    desc: string,         // Description

    effect: {
        type: string,     // Effect type identifier
        value: number,    // Effect value
        target: string,   // What it affects
    },

    recommendedClasses: string[],
    conflictsWith?: string[], // Traits that can't coexist
}
```

---

## Enemy Data Structure

```javascript
{
    id: string,
    name: string,         // Korean name
    nameEn: string,       // English name
    tier: number,         // 1-3 or 'boss'

    stats: {
        health: number,   // Base health
        damage: number,   // Base damage
        speed: number,    // Movement speed
        attackSpeed: number,
        attackRange: number,
    },

    visual: {
        color: string,    // Hex color
        size: number,     // Radius in pixels
        icon?: string,    // Optional emoji/icon
    },

    behavior: {
        id: string,       // AI behavior pattern ID
        priority: string, // Target priority
        special?: object, // Special mechanics
    },

    cost: number,         // Wave budget cost
    minDepth: number,     // Minimum depth to appear
    counters: string[],   // Classes that counter this enemy
    threats: string[],    // Classes this enemy threatens
}
```

---

## Facility Data Structure

```javascript
{
    id: string,
    name: string,         // Korean name
    nameEn: string,       // English name
    desc: string,         // Description

    credits: number,      // Credit value when defended
    size: string,         // 'small' | 'medium' | 'large'

    effect?: {
        type: string,
        value: number,
        scope: string,    // 'stage' | 'global'
    },

    spawnWeight: number,  // Generation weight
}
```

---

## Balance Constants Structure

```javascript
{
    difficulty: {
        normal: { enemyMultiplier, waveMultiplier, ... },
        hard: { ... },
        veryhard: { ... },
        nightmare: { ... },
    },

    economy: {
        healCost: number,
        skillUpgradeCosts: number[],
        rankUpCosts: { standard: n, veteran: n },
        equipmentBaseCost: number,
    },

    combat: {
        slowMotionFactor: number,
        skillCooldownBase: number,
        criticalMultiplier: number,
        knockbackBase: number,
    },

    wave: {
        baseBudget: number,
        budgetPerDepth: number,
        minEnemies: number,
        maxEnemies: number,
    },

    progression: {
        turnsPerSector: number,
        stormAdvanceRate: number,
        bossInterval: number,
    },
}
```
