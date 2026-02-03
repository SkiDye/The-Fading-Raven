/**
 * THE FADING RAVEN - Visual Effects System
 * 화면 효과: 쉐이크, 플래시, 페이드, 파티클 등
 */

// ============================================
// SCREEN EFFECTS
// ============================================
const ScreenEffects = {
    shakeElement: null,
    flashElement: null,
    currentShake: null,

    init() {
        // 쉐이크용 래퍼 (body의 첫 번째 자식에 적용하거나 특정 요소 지정)
        this.shakeElement = document.querySelector('.page-container') || document.body;

        // 플래시 오버레이 생성
        this.flashElement = document.createElement('div');
        this.flashElement.className = 'screen-flash';
        document.body.appendChild(this.flashElement);

        console.log('ScreenEffects initialized');
    },

    /**
     * 화면 쉐이크
     * @param {Object} options
     * @param {number} options.intensity - 쉐이크 강도 (픽셀), 기본 10
     * @param {number} options.duration - 지속 시간 (ms), 기본 300
     * @param {string} options.type - 'horizontal' | 'vertical' | 'both', 기본 'both'
     * @param {number} options.frequency - 진동 빈도 (ms), 기본 50
     */
    shake(options = {}) {
        const {
            intensity = 10,
            duration = 300,
            type = 'both',
            frequency = 50
        } = options;

        // 이미 쉐이크 중이면 취소
        if (this.currentShake) {
            cancelAnimationFrame(this.currentShake.raf);
            // 이전 쉐이크 정리
            this.shakeElement.style.marginLeft = '';
            this.shakeElement.style.marginTop = '';
        }

        const startTime = performance.now();
        const element = this.shakeElement;

        // position: relative 설정 (클릭 오프셋 문제 해결)
        const originalPosition = element.style.position;
        if (!originalPosition || originalPosition === 'static') {
            element.style.position = 'relative';
        }

        const animate = (currentTime) => {
            const elapsed = currentTime - startTime;
            const progress = elapsed / duration;

            if (progress >= 1) {
                // 원래 상태로 복원
                element.style.left = '';
                element.style.top = '';
                if (!originalPosition || originalPosition === 'static') {
                    element.style.position = originalPosition || '';
                }
                this.currentShake = null;
                return;
            }

            // 감쇠 효과
            const decay = 1 - progress;
            const currentIntensity = intensity * decay;

            // 랜덤 오프셋 - left/top 사용 (클릭 좌표에 영향 없음)
            let offsetX = 0;
            let offsetY = 0;

            if (type === 'horizontal' || type === 'both') {
                offsetX = (Math.random() - 0.5) * 2 * currentIntensity;
            }
            if (type === 'vertical' || type === 'both') {
                offsetY = (Math.random() - 0.5) * 2 * currentIntensity;
            }

            // left/top으로 이동 (transform 대신 - 클릭 오프셋 문제 해결)
            element.style.left = `${offsetX}px`;
            element.style.top = `${offsetY}px`;

            this.currentShake = {
                raf: requestAnimationFrame(animate)
            };
        };

        this.currentShake = {
            raf: requestAnimationFrame(animate)
        };
    },

    /**
     * 화면 플래시
     * @param {Object} options
     * @param {string} options.color - 플래시 색상, 기본 'white'
     * @param {number} options.duration - 지속 시간 (ms), 기본 200
     * @param {number} options.intensity - 불투명도 (0-1), 기본 0.5
     */
    flash(options = {}) {
        const {
            color = 'white',
            duration = 200,
            intensity = 0.5
        } = options;

        this.flashElement.style.backgroundColor = color;
        this.flashElement.style.opacity = intensity;
        this.flashElement.classList.add('active');

        setTimeout(() => {
            this.flashElement.classList.remove('active');
        }, duration);
    },

    /**
     * 데미지 효과 (빨간 플래시 + 쉐이크)
     */
    damage(intensity = 'medium') {
        const presets = {
            light: { shake: 5, flash: 0.2 },
            medium: { shake: 10, flash: 0.3 },
            heavy: { shake: 20, flash: 0.5 }
        };
        const preset = presets[intensity] || presets.medium;

        this.shake({ intensity: preset.shake, duration: 200 });
        this.flash({ color: '#ff0000', intensity: preset.flash, duration: 150 });
    },

    /**
     * 힐 효과 (녹색 플래시)
     */
    heal() {
        this.flash({ color: '#48bb78', intensity: 0.3, duration: 300 });
    },

    /**
     * 크리티컬 히트 효과
     */
    criticalHit() {
        this.shake({ intensity: 15, duration: 150, type: 'horizontal' });
        this.flash({ color: '#f6ad55', intensity: 0.4, duration: 100 });
    },

    /**
     * 폭발 효과
     */
    explosion() {
        this.shake({ intensity: 25, duration: 400, type: 'both' });
        this.flash({ color: '#ff6b00', intensity: 0.6, duration: 100 });
    }
};

// ============================================
// TRANSITION EFFECTS
// ============================================
const TransitionEffects = {
    overlay: null,

    init() {
        this.overlay = document.createElement('div');
        this.overlay.className = 'transition-overlay';
        document.body.appendChild(this.overlay);

        console.log('TransitionEffects initialized');
    },

    /**
     * 페이드 아웃 -> 콜백 -> 페이드 인
     * @param {Function} callback - 화면 전환 중 실행할 콜백
     * @param {Object} options
     */
    async fade(callback, options = {}) {
        const {
            color = '#000',
            duration = 300
        } = options;

        this.overlay.style.backgroundColor = color;
        this.overlay.style.transition = `opacity ${duration}ms ease`;

        // 페이드 아웃
        this.overlay.classList.add('active');
        await this.wait(duration);

        // 콜백 실행
        if (callback) await callback();

        // 페이드 인
        this.overlay.classList.remove('active');
        await this.wait(duration);
    },

    /**
     * 슬라이드 전환
     * @param {string} direction - 'left' | 'right' | 'up' | 'down'
     */
    async slide(callback, direction = 'left', duration = 400) {
        const transforms = {
            left: 'translateX(-100%)',
            right: 'translateX(100%)',
            up: 'translateY(-100%)',
            down: 'translateY(100%)'
        };

        this.overlay.style.transform = transforms[direction];
        this.overlay.style.transition = `transform ${duration}ms ease`;
        this.overlay.classList.add('active', 'slide');

        await this.wait(duration / 2);

        // 콜백 실행
        if (callback) await callback();

        // 반대 방향으로 슬라이드 아웃
        const reverseTransforms = {
            left: 'translateX(100%)',
            right: 'translateX(-100%)',
            up: 'translateY(100%)',
            down: 'translateY(-100%)'
        };

        this.overlay.style.transform = reverseTransforms[direction];
        await this.wait(duration);

        this.overlay.classList.remove('active', 'slide');
        this.overlay.style.transform = '';
    },

    wait(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
};

// ============================================
// ELEMENT ANIMATIONS
// ============================================
const ElementAnimations = {
    /**
     * 요소 펄스 효과
     */
    pulse(element, options = {}) {
        const { scale = 1.1, duration = 300, repeat = 1 } = options;

        element.style.transition = `transform ${duration / 2}ms ease`;

        let count = 0;
        const animate = () => {
            if (count >= repeat * 2) {
                element.style.transform = '';
                return;
            }

            element.style.transform = count % 2 === 0 ? `scale(${scale})` : 'scale(1)';
            count++;
            setTimeout(animate, duration / 2);
        };

        animate();
    },

    /**
     * 요소 흔들기 (경고 등)
     */
    wiggle(element, options = {}) {
        const { intensity = 5, duration = 500 } = options;

        element.style.animation = `wiggle ${duration}ms ease`;
        element.style.setProperty('--wiggle-intensity', `${intensity}px`);

        setTimeout(() => {
            element.style.animation = '';
        }, duration);
    },

    /**
     * 요소 바운스
     */
    bounce(element, options = {}) {
        const { height = 10, duration = 400 } = options;

        element.style.animation = `bounce ${duration}ms ease`;
        element.style.setProperty('--bounce-height', `${height}px`);

        setTimeout(() => {
            element.style.animation = '';
        }, duration);
    },

    /**
     * 페이드 인
     */
    fadeIn(element, duration = 300) {
        element.style.opacity = '0';
        element.style.display = '';
        element.style.transition = `opacity ${duration}ms ease`;

        requestAnimationFrame(() => {
            element.style.opacity = '1';
        });

        return new Promise(resolve => setTimeout(resolve, duration));
    },

    /**
     * 페이드 아웃
     */
    fadeOut(element, duration = 300) {
        element.style.transition = `opacity ${duration}ms ease`;
        element.style.opacity = '0';

        return new Promise(resolve => {
            setTimeout(() => {
                element.style.display = 'none';
                resolve();
            }, duration);
        });
    },

    /**
     * 슬라이드 인
     */
    slideIn(element, direction = 'left', duration = 300) {
        const transforms = {
            left: 'translateX(-100%)',
            right: 'translateX(100%)',
            up: 'translateY(-100%)',
            down: 'translateY(100%)'
        };

        element.style.transform = transforms[direction];
        element.style.display = '';
        element.style.transition = `transform ${duration}ms ease`;

        requestAnimationFrame(() => {
            element.style.transform = 'translate(0, 0)';
        });

        return new Promise(resolve => setTimeout(resolve, duration));
    },

    /**
     * 타이핑 효과
     */
    typeText(element, text, options = {}) {
        const { speed = 50, cursor = true } = options;

        element.textContent = '';
        if (cursor) element.classList.add('typing-cursor');

        let i = 0;
        return new Promise(resolve => {
            const type = () => {
                if (i < text.length) {
                    element.textContent += text.charAt(i);
                    i++;
                    setTimeout(type, speed);
                } else {
                    if (cursor) {
                        setTimeout(() => {
                            element.classList.remove('typing-cursor');
                        }, 500);
                    }
                    resolve();
                }
            };
            type();
        });
    },

    /**
     * 숫자 카운트 애니메이션
     */
    countUp(element, from, to, options = {}) {
        const { duration = 1000, format = null } = options;
        const startTime = performance.now();
        const difference = to - from;

        const animate = (currentTime) => {
            const elapsed = currentTime - startTime;
            const progress = Math.min(elapsed / duration, 1);

            // 이징 함수 (ease-out)
            const easeOut = 1 - Math.pow(1 - progress, 3);
            const current = from + difference * easeOut;

            element.textContent = format ? format(current) : Math.round(current);

            if (progress < 1) {
                requestAnimationFrame(animate);
            }
        };

        requestAnimationFrame(animate);
    }
};

// ============================================
// PARTICLE SYSTEM (간단한 버전)
// ============================================
const ParticleSystem = {
    container: null,

    init() {
        this.container = document.createElement('div');
        this.container.className = 'particle-container';
        document.body.appendChild(this.container);

        console.log('ParticleSystem initialized');
    },

    /**
     * 파티클 방출
     * @param {number} x - X 좌표
     * @param {number} y - Y 좌표
     * @param {Object} options
     */
    emit(x, y, options = {}) {
        const {
            count = 10,
            colors = ['#4a9eff', '#48bb78', '#f6ad55'],
            size = { min: 4, max: 8 },
            speed = { min: 50, max: 150 },
            lifetime = { min: 500, max: 1000 },
            gravity = 100,
            spread = 360 // 방출 각도 (도)
        } = options;

        for (let i = 0; i < count; i++) {
            this.createParticle(x, y, {
                color: colors[Math.floor(Math.random() * colors.length)],
                size: size.min + Math.random() * (size.max - size.min),
                speed: speed.min + Math.random() * (speed.max - speed.min),
                lifetime: lifetime.min + Math.random() * (lifetime.max - lifetime.min),
                gravity,
                angle: (Math.random() - 0.5) * spread * (Math.PI / 180)
            });
        }
    },

    createParticle(x, y, config) {
        const particle = document.createElement('div');
        particle.className = 'particle';
        particle.style.left = `${x}px`;
        particle.style.top = `${y}px`;
        particle.style.width = `${config.size}px`;
        particle.style.height = `${config.size}px`;
        particle.style.backgroundColor = config.color;

        this.container.appendChild(particle);

        const startTime = performance.now();
        const vx = Math.sin(config.angle) * config.speed;
        let vy = -Math.cos(config.angle) * config.speed;

        const animate = (currentTime) => {
            const elapsed = (currentTime - startTime) / 1000;
            const progress = (currentTime - startTime) / config.lifetime;

            if (progress >= 1) {
                particle.remove();
                return;
            }

            // 물리 시뮬레이션
            vy += config.gravity * elapsed;

            const newX = x + vx * elapsed;
            const newY = y + vy * elapsed;

            particle.style.left = `${newX}px`;
            particle.style.top = `${newY}px`;
            particle.style.opacity = 1 - progress;
            particle.style.transform = `scale(${1 - progress * 0.5})`;

            requestAnimationFrame(animate);
        };

        requestAnimationFrame(animate);
    },

    /**
     * 프리셋: 폭발
     */
    explosion(x, y, color = '#ff6b00') {
        this.emit(x, y, {
            count: 20,
            colors: [color, '#ffaa00', '#ff4400'],
            size: { min: 3, max: 10 },
            speed: { min: 100, max: 250 },
            lifetime: { min: 400, max: 800 },
            gravity: 150
        });
    },

    /**
     * 프리셋: 스파클
     */
    sparkle(x, y) {
        this.emit(x, y, {
            count: 8,
            colors: ['#ffffff', '#ffd700', '#4a9eff'],
            size: { min: 2, max: 5 },
            speed: { min: 30, max: 80 },
            lifetime: { min: 300, max: 600 },
            gravity: -20,
            spread: 360
        });
    },

    /**
     * 프리셋: 크레딧 획득
     */
    credits(x, y) {
        this.emit(x, y, {
            count: 5,
            colors: ['#ffd700', '#ffea00'],
            size: { min: 4, max: 7 },
            speed: { min: 40, max: 100 },
            lifetime: { min: 600, max: 1000 },
            gravity: -50,
            spread: 90
        });
    },

    /**
     * 프리셋: 데미지
     */
    damage(x, y) {
        this.emit(x, y, {
            count: 6,
            colors: ['#fc8181', '#ff4444'],
            size: { min: 3, max: 6 },
            speed: { min: 60, max: 120 },
            lifetime: { min: 300, max: 500 },
            gravity: 200
        });
    }
};

// ============================================
// FLOATING TEXT
// ============================================
const FloatingText = {
    container: null,

    init() {
        this.container = document.createElement('div');
        this.container.className = 'floating-text-container';
        document.body.appendChild(this.container);

        console.log('FloatingText initialized');
    },

    /**
     * 플로팅 텍스트 생성
     * @param {number} x - X 좌표
     * @param {number} y - Y 좌표
     * @param {string} text - 표시할 텍스트
     * @param {Object} options
     */
    show(x, y, text, options = {}) {
        const {
            color = '#ffffff',
            fontSize = '1rem',
            duration = 1000,
            rise = 50,
            type = 'default' // 'default' | 'damage' | 'heal' | 'critical' | 'miss'
        } = options;

        const element = document.createElement('div');
        element.className = `floating-text floating-text-${type}`;
        element.textContent = text;
        element.style.left = `${x}px`;
        element.style.top = `${y}px`;
        element.style.color = color;
        element.style.fontSize = fontSize;

        this.container.appendChild(element);

        // 애니메이션
        const startTime = performance.now();
        const startY = y;

        const animate = (currentTime) => {
            const elapsed = currentTime - startTime;
            const progress = elapsed / duration;

            if (progress >= 1) {
                element.remove();
                return;
            }

            // 이징
            const easeOut = 1 - Math.pow(1 - progress, 2);
            const currentY = startY - (rise * easeOut);

            element.style.top = `${currentY}px`;
            element.style.opacity = 1 - progress;

            requestAnimationFrame(animate);
        };

        requestAnimationFrame(animate);
    },

    /**
     * 프리셋: 데미지 숫자
     */
    damage(x, y, amount) {
        this.show(x, y, `-${amount}`, {
            color: '#fc8181',
            fontSize: '1.2rem',
            type: 'damage'
        });
    },

    /**
     * 프리셋: 힐 숫자
     */
    heal(x, y, amount) {
        this.show(x, y, `+${amount}`, {
            color: '#48bb78',
            fontSize: '1.2rem',
            type: 'heal'
        });
    },

    /**
     * 프리셋: 크리티컬
     */
    critical(x, y, amount) {
        this.show(x, y, `${amount}!`, {
            color: '#f6ad55',
            fontSize: '1.5rem',
            type: 'critical',
            rise: 70
        });
    },

    /**
     * 프리셋: 미스
     */
    miss(x, y) {
        this.show(x, y, 'MISS', {
            color: '#888888',
            fontSize: '0.9rem',
            type: 'miss'
        });
    },

    /**
     * 프리셋: 크레딧 획득
     */
    credits(x, y, amount) {
        this.show(x, y, `+${amount}`, {
            color: '#ffd700',
            fontSize: '1.1rem',
            type: 'credits',
            duration: 1500,
            rise: 80
        });
    }
};

// ============================================
// EFFECTS SYSTEM 초기화
// ============================================
const Effects = {
    initialized: false,

    init() {
        if (this.initialized) return;

        ScreenEffects.init();
        TransitionEffects.init();
        ParticleSystem.init();
        FloatingText.init();

        this.initialized = true;
        console.log('Effects system initialized');
    },

    // 편의 접근자
    get screen() { return ScreenEffects; },
    get transition() { return TransitionEffects; },
    get element() { return ElementAnimations; },
    get particle() { return ParticleSystem; },
    get text() { return FloatingText; }
};

// 전역 노출
window.ScreenEffects = ScreenEffects;
window.TransitionEffects = TransitionEffects;
window.ElementAnimations = ElementAnimations;
window.ParticleSystem = ParticleSystem;
window.FloatingText = FloatingText;
window.Effects = Effects;

// DOM 로드 시 자동 초기화
document.addEventListener('DOMContentLoaded', () => {
    Effects.init();
});
