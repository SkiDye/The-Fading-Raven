/**
 * THE FADING RAVEN - Battle Effects Integration
 * 기존 BattleController를 새 Effects 시스템과 통합
 */

const BattleEffectsIntegration = {
    initialized: false,

    init() {
        if (this.initialized) return;
        if (typeof BattleController === 'undefined') {
            // Only warn if we're on a battle page where BattleController is expected
            const isBattlePage = window.location.pathname.includes('battle');
            if (isBattlePage) {
                console.warn('BattleController not found on battle page, effects integration skipped');
            }
            // Silently skip on non-battle pages
            return;
        }

        this.patchBattleController();
        this.initialized = true;
        console.log('Battle Effects Integration initialized');
    },

    patchBattleController() {
        const bc = BattleController;

        // Store original methods
        const originalAddDamageNumber = bc.addDamageNumber?.bind(bc);
        const originalScreenShake = bc.screenShake?.bind(bc);

        // Enhanced addDamageNumber - use FloatingText if available
        bc.addDamageNumber = function(x, y, damage, isCrewDamage = false) {
            // Use new FloatingText system if available
            if (typeof FloatingText !== 'undefined') {
                const screenX = x;
                const screenY = y;

                if (damage === 'MISS') {
                    FloatingText.miss(screenX, screenY);
                } else if (damage === 'CRIT') {
                    FloatingText.critical(screenX, screenY, damage);
                } else if (isCrewDamage) {
                    FloatingText.damage(screenX, screenY, Math.abs(damage));
                    // Also add particle effect
                    if (typeof ParticleSystem !== 'undefined') {
                        ParticleSystem.damage(screenX, screenY);
                    }
                } else {
                    // Enemy damage - show in different style
                    FloatingText.show(screenX, screenY, `-${Math.floor(damage)}`, {
                        color: '#ffffff',
                        fontSize: '1rem',
                        type: 'default'
                    });
                }
            } else if (originalAddDamageNumber) {
                // Fallback to original
                originalAddDamageNumber(x, y, damage, isCrewDamage);
            }
        };

        // Enhanced screenShake - use ScreenEffects if available
        bc.screenShake = function(amount, duration) {
            // Check settings
            const shakeEnabled = typeof GameState !== 'undefined'
                ? GameState.getSetting?.('screenShake', true)
                : true;

            if (!shakeEnabled) return;

            if (typeof ScreenEffects !== 'undefined') {
                ScreenEffects.shake({
                    intensity: amount,
                    duration: duration,
                    type: 'both'
                });
            } else if (originalScreenShake) {
                originalScreenShake(amount, duration);
            }
        };

        // Add new helper methods
        bc.showCriticalHit = function(x, y, damage) {
            if (typeof FloatingText !== 'undefined') {
                FloatingText.critical(x, y, damage);
            }
            if (typeof ScreenEffects !== 'undefined') {
                ScreenEffects.criticalHit();
            }
            if (typeof ParticleSystem !== 'undefined') {
                ParticleSystem.sparkle(x, y);
            }
        };

        bc.showHeal = function(x, y, amount) {
            if (typeof FloatingText !== 'undefined') {
                FloatingText.heal(x, y, amount);
            }
            if (typeof ParticleSystem !== 'undefined') {
                ParticleSystem.emit(x, y, {
                    count: 5,
                    colors: ['#48bb78', '#68d391'],
                    size: { min: 3, max: 6 },
                    speed: { min: 30, max: 60 },
                    lifetime: { min: 500, max: 800 },
                    gravity: -30
                });
            }
        };

        bc.showCreditsGain = function(x, y, amount) {
            if (typeof FloatingText !== 'undefined') {
                FloatingText.credits(x, y, amount);
            }
            if (typeof ParticleSystem !== 'undefined') {
                ParticleSystem.credits(x, y);
            }
        };

        bc.showExplosion = function(x, y, color = '#ff6b00') {
            if (typeof ScreenEffects !== 'undefined') {
                ScreenEffects.explosion();
            }
            if (typeof ParticleSystem !== 'undefined') {
                ParticleSystem.explosion(x, y, color);
            }
        };

        bc.showEnemyDeath = function(x, y, enemyColor) {
            if (typeof ParticleSystem !== 'undefined') {
                ParticleSystem.emit(x, y, {
                    count: 8,
                    colors: [enemyColor, '#ffffff'],
                    size: { min: 2, max: 5 },
                    speed: { min: 50, max: 100 },
                    lifetime: { min: 300, max: 600 },
                    gravity: 100
                });
            }
        };

        bc.showCrewDeath = function(x, y, crewColor) {
            if (typeof ScreenEffects !== 'undefined') {
                ScreenEffects.damage('heavy');
            }
            if (typeof ParticleSystem !== 'undefined') {
                ParticleSystem.emit(x, y, {
                    count: 15,
                    colors: [crewColor, '#fc8181', '#ffffff'],
                    size: { min: 3, max: 8 },
                    speed: { min: 80, max: 150 },
                    lifetime: { min: 600, max: 1000 },
                    gravity: 80
                });
            }
            if (typeof Toast !== 'undefined') {
                Toast.warning('크루 전멸!', 2000);
            }
        };

        bc.showSkillActivation = function(crewX, crewY, skillName) {
            if (typeof FloatingText !== 'undefined') {
                FloatingText.show(crewX, crewY - 30, skillName, {
                    color: '#4a9eff',
                    fontSize: '1.1rem',
                    duration: 1200,
                    rise: 40
                });
            }
            if (typeof ParticleSystem !== 'undefined') {
                ParticleSystem.sparkle(crewX, crewY);
            }
        };

        bc.showWaveStart = function(waveNumber, subtitle) {
            // Use transition effect
            if (typeof TransitionEffects !== 'undefined') {
                // Quick flash
                if (typeof ScreenEffects !== 'undefined') {
                    ScreenEffects.flash({ color: '#4a9eff', duration: 150, intensity: 0.2 });
                }
            }
        };

        bc.showVictory = function() {
            if (typeof ScreenEffects !== 'undefined') {
                ScreenEffects.flash({ color: '#48bb78', duration: 300, intensity: 0.3 });
            }
            // Celebration particles
            if (typeof ParticleSystem !== 'undefined') {
                const canvas = bc.canvas;
                if (canvas) {
                    for (let i = 0; i < 5; i++) {
                        setTimeout(() => {
                            ParticleSystem.emit(
                                Math.random() * canvas.width,
                                Math.random() * canvas.height * 0.5,
                                {
                                    count: 15,
                                    colors: ['#ffd700', '#48bb78', '#4a9eff'],
                                    size: { min: 4, max: 8 },
                                    speed: { min: 60, max: 120 },
                                    lifetime: { min: 800, max: 1500 },
                                    gravity: 50
                                }
                            );
                        }, i * 300);
                    }
                }
            }
        };

        bc.showDefeat = function() {
            if (typeof ScreenEffects !== 'undefined') {
                ScreenEffects.damage('heavy');
            }
        };

        // Patch wave announcement if exists
        const originalShowWaveAnnouncement = bc.showWaveAnnouncement?.bind(bc);
        if (originalShowWaveAnnouncement) {
            bc.showWaveAnnouncement = function(waveNumber, isBoss = false) {
                originalShowWaveAnnouncement(waveNumber, isBoss);
                this.showWaveStart(waveNumber, isBoss ? '보스 등장!' : null);
            };
        }

        console.log('BattleController patched with enhanced effects');
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    // Wait a bit for BattleController to initialize first
    setTimeout(() => {
        BattleEffectsIntegration.init();
    }, 100);
});

// Also expose globally
window.BattleEffectsIntegration = BattleEffectsIntegration;
