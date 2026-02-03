/**
 * THE FADING RAVEN - Balance Validator Runner
 * 실행: node run-balance.js
 */

const puppeteer = require('puppeteer');

const TEST_URL = 'http://localhost:8080/pages/test.html';

async function runBalanceValidator() {
    console.log('\n╔════════════════════════════════════════════╗');
    console.log('║   THE FADING RAVEN - Balance Validator     ║');
    console.log('╚════════════════════════════════════════════╝\n');

    let browser;

    try {
        browser = await puppeteer.launch({
            headless: 'new',
            args: ['--no-sandbox', '--disable-setuid-sandbox']
        });

        const page = await browser.newPage();

        // Collect and print console logs
        page.on('console', msg => {
            const text = msg.text().replace(/%c/g, '').trim();
            if (text) console.log(text);
        });

        await page.goto(TEST_URL, { waitUntil: 'networkidle0', timeout: 30000 });

        // Wait for modules
        await page.waitForFunction(() => typeof BalanceValidator !== 'undefined', { timeout: 10000 });

        console.log('═══════════════════════════════════════════');
        console.log('         Running Balance Analysis          ');
        console.log('═══════════════════════════════════════════\n');

        // Run balance validator
        await page.evaluate(() => {
            BalanceValidator.runAll();
        });

        // Wait for all output
        await new Promise(r => setTimeout(r, 2000));

        console.log('\n═══════════════════════════════════════════');
        console.log('         Balance Analysis Complete          ');
        console.log('═══════════════════════════════════════════\n');

    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        if (browser) await browser.close();
    }
}

runBalanceValidator();
