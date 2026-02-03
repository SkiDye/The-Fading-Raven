/**
 * THE FADING RAVEN - Automated Test Runner
 * Puppeteer를 사용한 브라우저 통합 테스트
 *
 * 실행: node run-tests.js
 */

const puppeteer = require('puppeteer');

const TEST_URL = 'http://localhost:8080/pages/test.html';
const TIMEOUT = 60000;

async function runTests() {
    console.log('\n╔════════════════════════════════════════════╗');
    console.log('║   THE FADING RAVEN - Automated Test Runner ║');
    console.log('╚════════════════════════════════════════════╝\n');

    let browser;

    try {
        console.log('🚀 Launching browser...');
        browser = await puppeteer.launch({
            headless: 'new',
            args: ['--no-sandbox', '--disable-setuid-sandbox']
        });

        const page = await browser.newPage();

        // Collect console logs
        const logs = [];
        page.on('console', msg => {
            const text = msg.text();
            logs.push(text);
            // Print important messages
            if (text.includes('✓') || text.includes('✗') ||
                text.includes('===') || text.includes('통과') ||
                text.includes('실패') || text.includes('Error')) {
                console.log(text);
            }
        });

        // Collect errors
        page.on('pageerror', err => {
            console.log('❌ Page Error:', err.message);
        });

        console.log(`📄 Loading test page: ${TEST_URL}`);

        try {
            await page.goto(TEST_URL, {
                waitUntil: 'networkidle0',
                timeout: 30000
            });
        } catch (e) {
            console.log('❌ Failed to load test page. Is the server running?');
            console.log('   Start server: cd demo && python -m http.server 8080');
            throw e;
        }

        console.log('✓ Page loaded successfully\n');

        // Wait for modules to load
        await page.waitForFunction(() => {
            return typeof IntegrationTest !== 'undefined' &&
                   typeof BalanceValidator !== 'undefined';
        }, { timeout: 10000 });

        console.log('✓ Test modules loaded\n');
        console.log('═══════════════════════════════════════════');
        console.log('          Running Integration Tests         ');
        console.log('═══════════════════════════════════════════\n');

        // Run IntegrationTest.runAll()
        const testResult = await page.evaluate(async () => {
            try {
                const passed = await IntegrationTest.runAll();
                return {
                    success: true,
                    passed: passed,
                    results: IntegrationTest.results
                };
            } catch (e) {
                return {
                    success: false,
                    error: e.message
                };
            }
        });

        if (!testResult.success) {
            console.log('❌ Test execution failed:', testResult.error);
            return false;
        }

        // Analyze results
        const results = testResult.results;
        const passed = results.filter(r => r.passed).length;
        const failed = results.filter(r => !r.passed).length;
        const total = results.length;

        console.log('\n═══════════════════════════════════════════');
        console.log('              Test Results Summary          ');
        console.log('═══════════════════════════════════════════\n');

        // Group by category
        const byCategory = {};
        results.forEach(r => {
            if (!byCategory[r.category]) {
                byCategory[r.category] = { passed: 0, failed: 0, failures: [] };
            }
            if (r.passed) {
                byCategory[r.category].passed++;
            } else {
                byCategory[r.category].failed++;
                byCategory[r.category].failures.push(r);
            }
        });

        // Print category results
        for (const [cat, data] of Object.entries(byCategory)) {
            const status = data.failed === 0 ? '✓' : '✗';
            const color = data.failed === 0 ? '\x1b[32m' : '\x1b[31m';
            console.log(`${color}${status}\x1b[0m ${cat}: ${data.passed}/${data.passed + data.failed}`);

            if (data.failed > 0) {
                data.failures.forEach(f => {
                    console.log(`   \x1b[31m✗\x1b[0m ${f.name}${f.error ? ': ' + f.error : ''}`);
                });
            }
        }

        console.log('\n───────────────────────────────────────────');
        console.log(`Total: ${passed}/${total} tests passed (${((passed/total)*100).toFixed(1)}%)`);
        console.log('───────────────────────────────────────────\n');

        if (failed === 0) {
            console.log('\x1b[32m✓ ALL TESTS PASSED!\x1b[0m\n');
        } else {
            console.log(`\x1b[31m✗ ${failed} tests failed\x1b[0m\n`);
        }

        // Run Balance Validator summary
        console.log('═══════════════════════════════════════════');
        console.log('         Balance Validator Summary          ');
        console.log('═══════════════════════════════════════════\n');

        await page.evaluate(() => {
            if (typeof BalanceValidator !== 'undefined') {
                // Just run the class balance analysis as a quick check
                BalanceValidator.analyzeClassBalance();
            }
        });

        // Wait for logs to be collected
        await new Promise(r => setTimeout(r, 1000));

        return failed === 0;

    } catch (error) {
        console.error('❌ Test runner error:', error.message);
        return false;
    } finally {
        if (browser) {
            await browser.close();
        }
    }
}

// Run and exit with appropriate code
runTests().then(success => {
    process.exit(success ? 0 : 1);
}).catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});
