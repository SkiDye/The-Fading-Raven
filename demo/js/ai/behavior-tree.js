/**
 * THE FADING RAVEN - AI Behavior Tree System
 * Handles enemy decision-making, targeting, and behavior patterns
 */

/**
 * Behavior Tree Node States
 */
const NodeState = {
    SUCCESS: 'success',
    FAILURE: 'failure',
    RUNNING: 'running',
};

// ==========================================
// Base Node Classes
// ==========================================

/**
 * Base Behavior Tree Node
 */
class BTNode {
    constructor(name = 'Node') {
        this.name = name;
    }

    tick(enemy, context) {
        return NodeState.FAILURE;
    }
}

/**
 * Composite Node - Has children
 */
class CompositeNode extends BTNode {
    constructor(name = 'Composite', children = []) {
        super(name);
        this.children = children;
    }

    addChild(node) {
        this.children.push(node);
        return this;
    }
}

/**
 * Decorator Node - Wraps single child
 */
class DecoratorNode extends BTNode {
    constructor(name = 'Decorator', child = null) {
        super(name);
        this.child = child;
    }

    setChild(node) {
        this.child = node;
        return this;
    }
}

// ==========================================
// Composite Nodes
// ==========================================

/**
 * Sequence - Run children in order, fail if any fails
 */
class SequenceNode extends CompositeNode {
    constructor(children = []) {
        super('Sequence', children);
        this.currentIndex = 0;
    }

    tick(enemy, context) {
        while (this.currentIndex < this.children.length) {
            const result = this.children[this.currentIndex].tick(enemy, context);

            if (result === NodeState.RUNNING) {
                return NodeState.RUNNING;
            }

            if (result === NodeState.FAILURE) {
                this.currentIndex = 0;
                return NodeState.FAILURE;
            }

            this.currentIndex++;
        }

        this.currentIndex = 0;
        return NodeState.SUCCESS;
    }
}

/**
 * Selector - Run children until one succeeds
 */
class SelectorNode extends CompositeNode {
    constructor(children = []) {
        super('Selector', children);
        this.currentIndex = 0;
    }

    tick(enemy, context) {
        while (this.currentIndex < this.children.length) {
            const result = this.children[this.currentIndex].tick(enemy, context);

            if (result === NodeState.RUNNING) {
                return NodeState.RUNNING;
            }

            if (result === NodeState.SUCCESS) {
                this.currentIndex = 0;
                return NodeState.SUCCESS;
            }

            this.currentIndex++;
        }

        this.currentIndex = 0;
        return NodeState.FAILURE;
    }
}

/**
 * Parallel - Run all children simultaneously
 */
class ParallelNode extends CompositeNode {
    constructor(successThreshold = 1, children = []) {
        super('Parallel', children);
        this.successThreshold = successThreshold;
    }

    tick(enemy, context) {
        let successCount = 0;
        let runningCount = 0;

        for (const child of this.children) {
            const result = child.tick(enemy, context);

            if (result === NodeState.SUCCESS) {
                successCount++;
            } else if (result === NodeState.RUNNING) {
                runningCount++;
            }
        }

        if (successCount >= this.successThreshold) {
            return NodeState.SUCCESS;
        }

        if (runningCount > 0) {
            return NodeState.RUNNING;
        }

        return NodeState.FAILURE;
    }
}

/**
 * RandomSelector - Randomly pick a child to run
 */
class RandomSelectorNode extends CompositeNode {
    constructor(children = [], rng = null) {
        super('RandomSelector', children);
        this.rng = rng;
    }

    tick(enemy, context) {
        if (this.children.length === 0) return NodeState.FAILURE;

        const randomFunc = this.rng ? () => this.rng.random() : Math.random;
        const index = Math.floor(randomFunc() * this.children.length);

        return this.children[index].tick(enemy, context);
    }
}

// ==========================================
// Decorator Nodes
// ==========================================

/**
 * Inverter - Invert child result
 */
class InverterNode extends DecoratorNode {
    constructor(child = null) {
        super('Inverter', child);
    }

    tick(enemy, context) {
        if (!this.child) return NodeState.FAILURE;

        const result = this.child.tick(enemy, context);

        if (result === NodeState.SUCCESS) return NodeState.FAILURE;
        if (result === NodeState.FAILURE) return NodeState.SUCCESS;
        return NodeState.RUNNING;
    }
}

/**
 * Repeater - Repeat child N times or until failure
 */
class RepeaterNode extends DecoratorNode {
    constructor(times = -1, child = null) {
        super('Repeater', child);
        this.times = times; // -1 = infinite
        this.count = 0;
    }

    tick(enemy, context) {
        if (!this.child) return NodeState.FAILURE;

        const result = this.child.tick(enemy, context);

        if (result === NodeState.RUNNING) {
            return NodeState.RUNNING;
        }

        if (result === NodeState.FAILURE) {
            this.count = 0;
            return NodeState.FAILURE;
        }

        this.count++;

        if (this.times > 0 && this.count >= this.times) {
            this.count = 0;
            return NodeState.SUCCESS;
        }

        return NodeState.RUNNING;
    }
}

/**
 * Succeeder - Always return success
 */
class SucceederNode extends DecoratorNode {
    tick(enemy, context) {
        if (this.child) {
            this.child.tick(enemy, context);
        }
        return NodeState.SUCCESS;
    }
}

/**
 * UntilFail - Run child until it fails
 */
class UntilFailNode extends DecoratorNode {
    tick(enemy, context) {
        if (!this.child) return NodeState.FAILURE;

        const result = this.child.tick(enemy, context);

        if (result === NodeState.FAILURE) {
            return NodeState.SUCCESS;
        }

        return NodeState.RUNNING;
    }
}

/**
 * Cooldown - Only allow child to run after cooldown
 */
class CooldownNode extends DecoratorNode {
    constructor(cooldownMs, child = null) {
        super('Cooldown', child);
        this.cooldownMs = cooldownMs;
        this.lastRunTime = 0;
    }

    tick(enemy, context) {
        if (!this.child) return NodeState.FAILURE;

        const now = Date.now();
        if (now - this.lastRunTime < this.cooldownMs) {
            return NodeState.FAILURE;
        }

        const result = this.child.tick(enemy, context);

        if (result !== NodeState.FAILURE) {
            this.lastRunTime = now;
        }

        return result;
    }
}

// ==========================================
// Condition Nodes
// ==========================================

/**
 * Generic condition node
 */
class ConditionNode extends BTNode {
    constructor(name, conditionFn) {
        super(name);
        this.conditionFn = conditionFn;
    }

    tick(enemy, context) {
        return this.conditionFn(enemy, context) ? NodeState.SUCCESS : NodeState.FAILURE;
    }
}

// Common conditions - Factory functions to avoid singleton sharing
const Conditions = {
    hasTarget: () => new ConditionNode('HasTarget', (enemy, ctx) => enemy.target !== null),

    targetInRange: () => new ConditionNode('TargetInRange', (enemy, ctx) =>
        enemy.target && enemy.isInAttackRange(enemy.target)
    ),

    healthBelow: (threshold) => new ConditionNode(`HealthBelow${threshold}`, (enemy, ctx) =>
        enemy.health / enemy.maxHealth < threshold
    ),

    canAttack: () => new ConditionNode('CanAttack', (enemy, ctx) =>
        enemy.attackCooldown <= 0
    ),

    canUseSpecial: () => new ConditionNode('CanUseSpecial', (enemy, ctx) =>
        enemy.shouldUseSpecial()
    ),

    isStunned: () => new ConditionNode('IsStunned', (enemy, ctx) =>
        enemy.isStunned
    ),

    hasEnemiesNearby: (range) => new ConditionNode(`HasEnemiesNearby${range}`, (enemy, ctx) => {
        if (!ctx.crews) return false;
        return ctx.crews.some(c => enemy.distanceTo(c) <= range);
    }),

    isBeingTargeted: () => new ConditionNode('IsBeingTargeted', (enemy, ctx) => {
        if (!ctx.crews) return false;
        return ctx.crews.some(c => c.target?.id === enemy.id);
    }),
};

// ==========================================
// Action Nodes
// ==========================================

/**
 * Generic action node
 */
class ActionNode extends BTNode {
    constructor(name, actionFn) {
        super(name);
        this.actionFn = actionFn;
    }

    tick(enemy, context) {
        return this.actionFn(enemy, context);
    }
}

// Common actions
const Actions = {
    /**
     * Find nearest target (crew or station)
     */
    findNearestTarget: new ActionNode('FindNearestTarget', (enemy, ctx) => {
        const targets = [...(ctx.crews || [])];

        if (enemy.canAttackStation() && ctx.station) {
            targets.push(ctx.station);
        }

        if (targets.length === 0) return NodeState.FAILURE;

        let nearest = null;
        let nearestDist = Infinity;

        for (const target of targets) {
            if (target.health <= 0) continue;

            const dist = enemy.distanceTo(target);
            if (dist < nearestDist) {
                nearestDist = dist;
                nearest = target;
            }
        }

        if (nearest) {
            enemy.target = nearest;
            return NodeState.SUCCESS;
        }

        return NodeState.FAILURE;
    }),

    /**
     * Find target based on priority
     */
    findPriorityTarget: new ActionNode('FindPriorityTarget', (enemy, ctx) => {
        const priority = enemy.getBehaviorData().priority;
        const crews = ctx.crews || [];
        const station = ctx.station;

        let target = null;

        switch (priority) {
            case 'nearest_crew':
                target = TargetingSystem.findNearest(enemy, crews);
                break;

            case 'highest_threat':
                target = TargetingSystem.findHighestThreat(enemy, crews);
                break;

            case 'lowest_health':
                target = TargetingSystem.findLowestHealth(enemy, crews);
                break;

            case 'crew_bypassing_defense':
                target = TargetingSystem.findBypassingDefense(enemy, crews, ctx);
                break;

            case 'nearest_turret':
                target = TargetingSystem.findNearestTurret(enemy, ctx.turrets || []);
                break;

            case 'safe_position':
                // For carriers/support - stay back
                target = null;
                break;

            case 'center_of_allies':
                // For shield generators
                target = null;
                break;

            default:
                target = TargetingSystem.findNearest(enemy, crews);
        }

        if (!target && enemy.canAttackStation() && station) {
            target = station;
        }

        enemy.target = target;
        return target ? NodeState.SUCCESS : NodeState.FAILURE;
    }),

    /**
     * Move towards target
     */
    moveToTarget: new ActionNode('MoveToTarget', (enemy, ctx) => {
        if (!enemy.target) return NodeState.FAILURE;

        const arrived = enemy.moveTowards(enemy.target.x, enemy.target.y, ctx.deltaTime);

        return arrived ? NodeState.SUCCESS : NodeState.RUNNING;
    }),

    /**
     * Move to attack range
     */
    moveToAttackRange: new ActionNode('MoveToAttackRange', (enemy, ctx) => {
        if (!enemy.target) return NodeState.FAILURE;

        // Already in range
        if (enemy.isInAttackRange(enemy.target)) {
            return NodeState.SUCCESS;
        }

        // Calculate position just within attack range
        const dx = enemy.target.x - enemy.x;
        const dy = enemy.target.y - enemy.y;
        const distance = Math.sqrt(dx * dx + dy * dy);

        if (distance === 0) return NodeState.SUCCESS;

        const targetDist = enemy.attackRange * 0.9; // Stay slightly inside range
        const ratio = (distance - targetDist) / distance;

        const targetX = enemy.x + dx * ratio;
        const targetY = enemy.y + dy * ratio;

        const arrived = enemy.moveTowards(targetX, targetY, ctx.deltaTime);

        return arrived ? NodeState.SUCCESS : NodeState.RUNNING;
    }),

    /**
     * Keep preferred distance (for ranged enemies)
     */
    keepDistance: new ActionNode('KeepDistance', (enemy, ctx) => {
        if (!enemy.target) return NodeState.FAILURE;

        const preferredRange = enemy.getBehaviorData().preferredRange || enemy.attackRange * 0.8;
        const currentDist = enemy.distanceTo(enemy.target);

        const tolerance = 20;

        if (Math.abs(currentDist - preferredRange) < tolerance) {
            return NodeState.SUCCESS;
        }

        // Calculate target position
        const dx = enemy.x - enemy.target.x;
        const dy = enemy.y - enemy.target.y;
        const distance = Math.sqrt(dx * dx + dy * dy);

        if (distance === 0) return NodeState.SUCCESS;

        const normalX = dx / distance;
        const normalY = dy / distance;

        const targetX = enemy.target.x + normalX * preferredRange;
        const targetY = enemy.target.y + normalY * preferredRange;

        enemy.moveTowards(targetX, targetY, ctx.deltaTime);

        return NodeState.RUNNING;
    }),

    /**
     * Attack current target
     */
    attackTarget: new ActionNode('AttackTarget', (enemy, ctx) => {
        if (!enemy.target) return NodeState.FAILURE;
        if (!enemy.isInAttackRange(enemy.target)) return NodeState.FAILURE;

        const success = enemy.attack(enemy.target);
        return success ? NodeState.SUCCESS : NodeState.FAILURE;
    }),

    /**
     * Use special ability
     */
    useSpecialAbility: new ActionNode('UseSpecialAbility', (enemy, ctx) => {
        if (!enemy.shouldUseSpecial()) return NodeState.FAILURE;

        const success = enemy.useSpecialAbility(ctx);
        return success ? NodeState.SUCCESS : NodeState.FAILURE;
    }),

    /**
     * Flee from danger
     */
    flee: new ActionNode('Flee', (enemy, ctx) => {
        const threats = ctx.crews?.filter(c => c.target?.id === enemy.id) || [];

        if (threats.length === 0) return NodeState.SUCCESS;

        // Calculate average threat direction
        let threatX = 0;
        let threatY = 0;

        for (const threat of threats) {
            threatX += threat.x;
            threatY += threat.y;
        }

        threatX /= threats.length;
        threatY /= threats.length;

        // Move away from threats
        const dx = enemy.x - threatX;
        const dy = enemy.y - threatY;
        const distance = Math.sqrt(dx * dx + dy * dy);

        if (distance === 0) return NodeState.SUCCESS;

        const fleeDistance = 200;
        const targetX = enemy.x + (dx / distance) * fleeDistance;
        const targetY = enemy.y + (dy / distance) * fleeDistance;

        enemy.moveTowards(targetX, targetY, ctx.deltaTime);

        return NodeState.RUNNING;
    }),

    /**
     * Stay back (for support units)
     */
    stayBack: new ActionNode('StayBack', (enemy, ctx) => {
        const allies = ctx.enemies?.filter(e => e.id !== enemy.id) || [];

        if (allies.length === 0) return NodeState.SUCCESS;

        // Find center of allies
        let centerX = 0;
        let centerY = 0;

        for (const ally of allies) {
            centerX += ally.x;
            centerY += ally.y;
        }

        centerX /= allies.length;
        centerY /= allies.length;

        // Stay behind allies (away from crews)
        const crews = ctx.crews || [];
        if (crews.length === 0) return NodeState.SUCCESS;

        let crewCenterX = 0;
        let crewCenterY = 0;

        for (const crew of crews) {
            crewCenterX += crew.x;
            crewCenterY += crew.y;
        }

        crewCenterX /= crews.length;
        crewCenterY /= crews.length;

        // Calculate position behind allies
        const dx = centerX - crewCenterX;
        const dy = centerY - crewCenterY;
        const distance = Math.sqrt(dx * dx + dy * dy);

        if (distance === 0) return NodeState.SUCCESS;

        const backDistance = 100;
        const targetX = centerX + (dx / distance) * backDistance;
        const targetY = centerY + (dy / distance) * backDistance;

        enemy.moveTowards(targetX, targetY, ctx.deltaTime);

        return NodeState.RUNNING;
    }),

    /**
     * Move to center of allies (for shield generators)
     */
    moveToCenterOfAllies: new ActionNode('MoveToCenterOfAllies', (enemy, ctx) => {
        const allies = ctx.enemies?.filter(e => e.id !== enemy.id && !e.isBoss) || [];

        if (allies.length === 0) return NodeState.SUCCESS;

        let centerX = 0;
        let centerY = 0;

        for (const ally of allies) {
            centerX += ally.x;
            centerY += ally.y;
        }

        centerX /= allies.length;
        centerY /= allies.length;

        const arrived = enemy.moveTowards(centerX, centerY, ctx.deltaTime);

        return arrived ? NodeState.SUCCESS : NodeState.RUNNING;
    }),

    /**
     * Idle/wait
     */
    idle: new ActionNode('Idle', (enemy, ctx) => {
        enemy.state = EnemyState.IDLE;
        return NodeState.SUCCESS;
    }),
};

// ==========================================
// Targeting System
// ==========================================

const TargetingSystem = {
    /**
     * Find nearest target
     */
    findNearest(enemy, targets) {
        let nearest = null;
        let nearestDist = Infinity;

        for (const target of targets) {
            if (target.health <= 0) continue;

            const dist = enemy.distanceTo(target);
            if (dist < nearestDist) {
                nearestDist = dist;
                nearest = target;
            }
        }

        return nearest;
    },

    /**
     * Find highest threat target (based on damage output)
     */
    findHighestThreat(enemy, targets) {
        let highest = null;
        let highestThreat = 0;

        for (const target of targets) {
            if (target.health <= 0) continue;

            // Calculate threat score (damage * attack speed factor)
            const threat = target.damage * (1000 / (target.attackSpeed || 1000));

            if (threat > highestThreat) {
                highestThreat = threat;
                highest = target;
            }
        }

        return highest;
    },

    /**
     * Find lowest health target
     */
    findLowestHealth(enemy, targets) {
        let lowest = null;
        let lowestHealth = Infinity;

        for (const target of targets) {
            if (target.health <= 0) continue;

            if (target.health < lowestHealth) {
                lowestHealth = target.health;
                lowest = target;
            }
        }

        return lowest;
    },

    /**
     * Find target that can be reached by bypassing defenses
     */
    findBypassingDefense(enemy, targets, ctx) {
        // For jumpers - find targets behind front line
        const frontLine = this.calculateFrontLine(targets);

        for (const target of targets) {
            if (target.health <= 0) continue;

            // Skip front line defenders (sentinels, guardians)
            if (target.classId === 'sentinel' || target.classId === 'guardian') {
                continue;
            }

            // Prefer rangers, engineers, bionics
            if (['ranger', 'engineer', 'bionic'].includes(target.classId)) {
                return target;
            }
        }

        // Fallback to nearest
        return this.findNearest(enemy, targets);
    },

    /**
     * Calculate front line position
     */
    calculateFrontLine(targets) {
        if (targets.length === 0) return 0;

        let minX = Infinity;
        for (const target of targets) {
            if (target.x < minX) {
                minX = target.x;
            }
        }

        return minX;
    },

    /**
     * Find nearest turret
     */
    findNearestTurret(enemy, turrets) {
        return this.findNearest(enemy, turrets);
    },

    /**
     * Find weakest target in range
     */
    findWeakestInRange(enemy, targets, range) {
        let weakest = null;
        let lowestHealth = Infinity;

        for (const target of targets) {
            if (target.health <= 0) continue;

            const dist = enemy.distanceTo(target);
            if (dist > range) continue;

            if (target.health < lowestHealth) {
                lowestHealth = target.health;
                weakest = target;
            }
        }

        return weakest;
    },
};

// ==========================================
// Behavior Patterns
// ==========================================

const BehaviorPatterns = {
    /**
     * Basic melee behavior
     */
    melee_basic: () => new SelectorNode([
        new SequenceNode([
            Conditions.hasTarget(),
            Conditions.targetInRange(),
            Conditions.canAttack(),
            Actions.attackTarget,
        ]),
        new SequenceNode([
            Actions.findPriorityTarget,
            Actions.moveToAttackRange,
        ]),
        Actions.findNearestTarget,
    ]),

    /**
     * Shielded melee behavior
     */
    melee_shielded: () => new SelectorNode([
        new SequenceNode([
            Conditions.hasTarget(),
            Conditions.targetInRange(),
            Conditions.canAttack(),
            Actions.attackTarget,
        ]),
        new SequenceNode([
            Actions.findPriorityTarget,
            Actions.moveToTarget,
        ]),
        Actions.findNearestTarget,
    ]),

    /**
     * Basic ranged behavior
     */
    ranged_basic: () => new SelectorNode([
        new SequenceNode([
            Conditions.hasTarget(),
            Actions.keepDistance,
        ]),
        new SequenceNode([
            Conditions.hasTarget(),
            Conditions.targetInRange(),
            Conditions.canAttack(),
            Actions.attackTarget,
        ]),
        new SequenceNode([
            Actions.findPriorityTarget,
            Actions.moveToAttackRange,
        ]),
    ]),

    /**
     * Jumper behavior
     */
    melee_jumper: () => new SelectorNode([
        // Try to use jump when available
        new SequenceNode([
            Conditions.canUseSpecial(),
            new ActionNode('Jump', (enemy, ctx) => {
                if (!enemy.canJump || !enemy.canJump()) return NodeState.FAILURE;

                const target = TargetingSystem.findBypassingDefense(enemy, ctx.crews || [], ctx);
                if (!target) return NodeState.FAILURE;

                const success = enemy.jump(target.x, target.y);
                return success ? NodeState.SUCCESS : NodeState.FAILURE;
            }),
        ]),
        // Normal melee when jump on cooldown
        new SequenceNode([
            Conditions.hasTarget(),
            Conditions.targetInRange(),
            Conditions.canAttack(),
            Actions.attackTarget,
        ]),
        new SequenceNode([
            Actions.findPriorityTarget,
            Actions.moveToAttackRange,
        ]),
    ]),

    /**
     * Heavy trooper behavior (with grenade)
     */
    melee_heavy: () => new SelectorNode([
        // Use grenade when enemies clustered
        new SequenceNode([
            Conditions.canUseSpecial(),
            new ActionNode('ThrowGrenade', (enemy, ctx) => {
                if (!enemy.canThrowGrenade || !enemy.canThrowGrenade()) {
                    return NodeState.FAILURE;
                }

                const crews = ctx.crews || [];
                const cluster = TargetingSystem.findNearest(enemy, crews);

                if (cluster) {
                    const success = enemy.throwGrenade(cluster.x, cluster.y);
                    return success ? NodeState.SUCCESS : NodeState.FAILURE;
                }

                return NodeState.FAILURE;
            }),
        ]),
        // Normal melee
        new SequenceNode([
            Conditions.hasTarget(),
            Conditions.targetInRange(),
            Conditions.canAttack(),
            Actions.attackTarget,
        ]),
        new SequenceNode([
            Actions.findPriorityTarget,
            Actions.moveToAttackRange,
        ]),
    ]),

    /**
     * Brute behavior (cleave attack)
     */
    melee_brute: () => new SelectorNode([
        new SequenceNode([
            Conditions.hasTarget(),
            Conditions.targetInRange(),
            Conditions.canAttack(),
            Actions.attackTarget,
        ]),
        new SequenceNode([
            Actions.findPriorityTarget,
            Actions.moveToTarget,
        ]),
    ]),

    /**
     * Hacker behavior
     */
    support_hacker: () => new SelectorNode([
        // Flee if being targeted
        new SequenceNode([
            Conditions.isBeingTargeted(),
            Actions.flee,
        ]),
        // Try to hack turret
        new SequenceNode([
            new ActionNode('FindTurret', (enemy, ctx) => {
                const turret = TargetingSystem.findNearestTurret(enemy, ctx.turrets || []);
                if (turret) {
                    enemy.target = turret;
                    return NodeState.SUCCESS;
                }
                return NodeState.FAILURE;
            }),
            new ActionNode('MoveToTurret', (enemy, ctx) => {
                if (!enemy.target) return NodeState.FAILURE;

                const hackRange = (enemy.special?.hackRange || 2) * 40;
                const dist = enemy.distanceTo(enemy.target);

                if (dist <= hackRange) {
                    return NodeState.SUCCESS;
                }

                enemy.moveTowards(enemy.target.x, enemy.target.y, ctx.deltaTime);
                return NodeState.RUNNING;
            }),
            new ActionNode('Hack', (enemy, ctx) => {
                if (!enemy.target || !enemy.startHacking) return NodeState.FAILURE;

                if (!enemy.isHacking) {
                    enemy.startHacking(enemy.target);
                }

                if (enemy.isHacking) {
                    enemy.updateHacking(ctx.deltaTime);
                    return NodeState.RUNNING;
                }

                return NodeState.SUCCESS;
            }),
        ]),
        // Stay back if no turrets
        Actions.stayBack,
    ]),

    /**
     * Sniper behavior
     */
    ranged_sniper: () => new SelectorNode([
        // Continue aiming if already started
        new SequenceNode([
            new ConditionNode('IsAiming', (enemy) => enemy.isAiming),
            new ActionNode('ContinueAiming', (enemy, ctx) => {
                enemy.updateAiming(ctx.deltaTime);
                return enemy.isAiming ? NodeState.RUNNING : NodeState.SUCCESS;
            }),
        ]),
        // Start aiming at high threat target
        new SequenceNode([
            Conditions.canAttack(),
            new ActionNode('StartAiming', (enemy, ctx) => {
                const target = TargetingSystem.findHighestThreat(enemy, ctx.crews || []);
                if (!target || !enemy.startAiming) return NodeState.FAILURE;

                enemy.startAiming(target);
                return NodeState.RUNNING;
            }),
        ]),
        // Stay back
        Actions.stayBack,
    ]),

    /**
     * Drone carrier behavior
     */
    support_carrier: () => new SelectorNode([
        // Spawn drones when possible
        new SequenceNode([
            new ConditionNode('CanSpawnDrones', (enemy) =>
                enemy.canSpawnDrones && enemy.canSpawnDrones()
            ),
            new ActionNode('SpawnDrones', (enemy, ctx) => {
                if (!enemy.spawnDrones) return NodeState.FAILURE;
                enemy.spawnDrones();
                return NodeState.SUCCESS;
            }),
        ]),
        // Ranged attack
        new SequenceNode([
            Conditions.hasTarget(),
            Conditions.targetInRange(),
            Conditions.canAttack(),
            Actions.attackTarget,
        ]),
        // Find target and stay back
        new SequenceNode([
            Actions.findPriorityTarget,
            Actions.stayBack,
        ]),
    ]),

    /**
     * Shield generator behavior
     */
    support_shield: () => new SelectorNode([
        // Update shields on nearby allies
        new SequenceNode([
            new ActionNode('UpdateShields', (enemy, ctx) => {
                if (!enemy.updateShields) return NodeState.SUCCESS;
                enemy.updateShields(ctx.enemies || []);
                return NodeState.SUCCESS;
            }),
        ]),
        // Move to center of allies
        Actions.moveToCenterOfAllies,
    ]),

    /**
     * Kamikaze behavior (Storm Creature)
     */
    kamikaze: () => new SelectorNode([
        // Check for explosion trigger
        new SequenceNode([
            new ActionNode('CheckTrigger', (enemy, ctx) => {
                if (!enemy.checkTrigger) return NodeState.FAILURE;

                const targets = [...(ctx.crews || [])];
                if (ctx.station) targets.push(ctx.station);

                const triggered = enemy.checkTrigger(targets);
                return triggered ? NodeState.SUCCESS : NodeState.FAILURE;
            }),
        ]),
        // Rush to nearest target
        new SequenceNode([
            Actions.findNearestTarget,
            Actions.moveToTarget,
        ]),
    ]),

    /**
     * Boss - Pirate Captain
     */
    boss_captain: () => new SelectorNode([
        // Use abilities based on phase
        new SequenceNode([
            new ActionNode('UseAbility', (enemy, ctx) => {
                if (!enemy.abilities || !enemy.useAbility) return NodeState.FAILURE;

                // Check each ability
                for (const ability of enemy.abilities) {
                    if (enemy.canUseAbility(ability.id)) {
                        enemy.useAbility(ability.id, ctx);
                        return NodeState.SUCCESS;
                    }
                }

                return NodeState.FAILURE;
            }),
        ]),
        // Normal combat
        new SequenceNode([
            Conditions.hasTarget(),
            Conditions.targetInRange(),
            Conditions.canAttack(),
            Actions.attackTarget,
        ]),
        new SequenceNode([
            Actions.findPriorityTarget,
            Actions.moveToTarget,
        ]),
    ]),

    /**
     * Boss - Storm Core (stationary)
     */
    boss_storm: () => new SequenceNode([
        // Storm Core just exists and pulses - handled in update()
        Actions.idle,
    ]),
};

// ==========================================
// AI Manager
// ==========================================

class AIManager {
    constructor() {
        this.behaviorTrees = new Map();
    }

    /**
     * Get or create behavior tree for enemy
     */
    getBehaviorTree(enemy) {
        if (this.behaviorTrees.has(enemy.id)) {
            return this.behaviorTrees.get(enemy.id);
        }

        const behaviorId = enemy.getBehaviorData().id;
        let patternFactory = BehaviorPatterns[behaviorId];

        if (!patternFactory) {
            console.warn(`Unknown behavior pattern: ${behaviorId}, using melee_basic`);
            patternFactory = BehaviorPatterns.melee_basic;
        }

        const tree = patternFactory();
        this.behaviorTrees.set(enemy.id, tree);

        return tree;
    }

    /**
     * Update single enemy AI
     */
    updateEnemy(enemy, context) {
        if (enemy.state === EnemyState.SPAWNING ||
            enemy.state === EnemyState.DYING ||
            enemy.state === EnemyState.DEAD ||
            enemy.isStunned) {
            return;
        }

        const tree = this.getBehaviorTree(enemy);
        tree.tick(enemy, context);
    }

    /**
     * Update all enemies
     */
    updateAll(enemies, context) {
        for (const enemy of enemies) {
            this.updateEnemy(enemy, {
                ...context,
                enemies: enemies,
            });
        }
    }

    /**
     * Remove enemy from tracking
     */
    removeEnemy(enemyId) {
        this.behaviorTrees.delete(enemyId);
    }

    /**
     * Clear all behavior trees
     */
    clear() {
        this.behaviorTrees.clear();
    }
}

// Make available globally
window.NodeState = NodeState;
window.BTNode = BTNode;
window.SequenceNode = SequenceNode;
window.SelectorNode = SelectorNode;
window.ParallelNode = ParallelNode;
window.RandomSelectorNode = RandomSelectorNode;
window.InverterNode = InverterNode;
window.RepeaterNode = RepeaterNode;
window.ConditionNode = ConditionNode;
window.ActionNode = ActionNode;
window.CooldownNode = CooldownNode;
window.Conditions = Conditions;
window.Actions = Actions;
window.TargetingSystem = TargetingSystem;
window.BehaviorPatterns = BehaviorPatterns;
window.AIManager = AIManager;
