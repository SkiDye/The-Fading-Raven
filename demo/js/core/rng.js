/**
 * THE FADING RAVEN - Seeded Random Number Generator
 * Xorshift128+ implementation for deterministic randomness
 */

class SeededRNG {
    constructor(seed) {
        // Initialize state from seed using splitmix64
        this.state = new BigUint64Array(2);
        this.state[0] = this._splitmix64(BigInt(seed));
        this.state[1] = this._splitmix64(BigInt(seed) + 0x9E3779B97F4A7C15n);
    }

    /**
     * Splitmix64 for seed initialization
     */
    _splitmix64(x) {
        x = (x ^ (x >> 30n)) * 0xBF58476D1CE4E5B9n;
        x = (x ^ (x >> 27n)) * 0x94D049BB133111EBn;
        x = (x ^ (x >> 31n));
        return x & 0xFFFFFFFFFFFFFFFFn;
    }

    /**
     * Generate next random 64-bit integer
     */
    _next() {
        let s0 = this.state[0];
        let s1 = this.state[1];
        const result = (s0 + s1) & 0xFFFFFFFFFFFFFFFFn;

        s1 ^= s0;
        this.state[0] = ((s0 << 24n) | (s0 >> 40n)) ^ s1 ^ (s1 << 16n);
        this.state[1] = (s1 << 37n) | (s1 >> 27n);

        return result;
    }

    /**
     * Random float between 0 and 1
     */
    random() {
        return Number(this._next() & 0x1FFFFFFFFFFFFFn) / 0x20000000000000;
    }

    /**
     * Random integer between min (inclusive) and max (inclusive)
     */
    range(min, max) {
        return Math.floor(this.random() * (max - min + 1)) + min;
    }

    /**
     * Random float between min and max
     */
    rangeFloat(min, max) {
        return this.random() * (max - min) + min;
    }

    /**
     * Returns true with given probability (0-1)
     */
    chance(probability) {
        return this.random() < probability;
    }

    /**
     * Pick random element from array
     */
    pick(array) {
        return array[this.range(0, array.length - 1)];
    }

    /**
     * Pick multiple unique elements from array
     */
    pickMultiple(array, count) {
        const shuffled = this.shuffle([...array]);
        return shuffled.slice(0, Math.min(count, array.length));
    }

    /**
     * Weighted random pick
     */
    weightedPick(items, weights) {
        const totalWeight = weights.reduce((sum, w) => sum + w, 0);
        let random = this.random() * totalWeight;

        for (let i = 0; i < items.length; i++) {
            random -= weights[i];
            if (random <= 0) {
                return items[i];
            }
        }
        return items[items.length - 1];
    }

    /**
     * Fisher-Yates shuffle
     */
    shuffle(array) {
        const result = [...array];
        for (let i = result.length - 1; i > 0; i--) {
            const j = this.range(0, i);
            [result[i], result[j]] = [result[j], result[i]];
        }
        return result;
    }

    /**
     * Normal distribution (Box-Muller transform)
     */
    normal(mean = 0, stddev = 1) {
        const u1 = this.random();
        const u2 = this.random();
        const z0 = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
        return mean + z0 * stddev;
    }

    /**
     * Gaussian distribution clamped to range
     */
    gaussian(mean, stddev, min, max) {
        let value;
        do {
            value = this.normal(mean, stddev);
        } while (value < min || value > max);
        return value;
    }
}

/**
 * Seed string utilities
 */
const SeedUtils = {
    CHARS: '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ',

    /**
     * Generate random seed string (XXXX-XXXX-XXXX format)
     */
    generateSeedString() {
        const randomInt = () => Math.floor(Math.random() * 1679616); // 36^4
        const toBase36 = (n) => {
            let result = '';
            for (let i = 0; i < 4; i++) {
                result = this.CHARS[n % 36] + result;
                n = Math.floor(n / 36);
            }
            return result;
        };

        const part1 = toBase36(randomInt());
        const part2 = toBase36(randomInt());
        const part3 = toBase36(randomInt());

        return `${part1}-${part2}-${part3}`;
    },

    /**
     * Parse seed string to number
     */
    parseSeedString(seedString) {
        const clean = seedString.toUpperCase().replace(/-/g, '');
        if (clean.length !== 12) {
            throw new Error('Invalid seed format');
        }

        let result = 0n;
        for (const char of clean) {
            const index = this.CHARS.indexOf(char);
            if (index === -1) {
                throw new Error('Invalid character in seed');
            }
            result = result * 36n + BigInt(index);
        }

        return Number(result);
    },

    /**
     * Validate seed string format
     */
    isValidSeedString(seedString) {
        const pattern = /^[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$/i;
        return pattern.test(seedString);
    },

    /**
     * Format seed string with dashes
     */
    formatSeedString(input) {
        const clean = input.toUpperCase().replace(/[^0-9A-Z]/g, '').slice(0, 12);
        const parts = [];
        for (let i = 0; i < clean.length; i += 4) {
            parts.push(clean.slice(i, i + 4));
        }
        return parts.join('-');
    }
};

/**
 * Multi-stream RNG manager
 * Separates randomness by purpose to prevent cross-system interference
 */
class MultiStreamRNG {
    constructor(masterSeed) {
        this.masterSeed = masterSeed;
        this.streams = {
            sectorMap: new SeededRNG(masterSeed ^ 0xAAAAAAAA),
            stationLayout: new SeededRNG(masterSeed ^ 0xBBBBBBBB),
            enemyWaves: new SeededRNG(masterSeed ^ 0xCCCCCCCC),
            items: new SeededRNG(masterSeed ^ 0xDDDDDDDD),
            traits: new SeededRNG(masterSeed ^ 0xEEEEEEEE),
            combat: new SeededRNG(masterSeed ^ 0x11111111),
            visual: new SeededRNG(masterSeed ^ 0xFFFFFFFF),
        };
    }

    get(streamName) {
        if (!this.streams[streamName]) {
            throw new Error(`Unknown RNG stream: ${streamName}`);
        }
        return this.streams[streamName];
    }

    /**
     * Create a new temporary stream from an existing one
     */
    fork(streamName, subSeed) {
        const baseStream = this.get(streamName);
        return new SeededRNG(this.masterSeed ^ subSeed);
    }
}

// Make available globally
window.SeededRNG = SeededRNG;
window.SeedUtils = SeedUtils;
window.MultiStreamRNG = MultiStreamRNG;
