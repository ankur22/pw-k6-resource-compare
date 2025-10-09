// Custom Playwright Test fixtures for CDP connection to external Chrome
// Allows using Playwright Test framework with remote browser via CDP
import { test as base, chromium } from '@playwright/test';

/**
 * Connect to browserless Chrome via CDP
 * @returns {Promise<string>} WebSocket endpoint URL
 */
async function connectToBrowserless() {
  const cdpUrl = process.env.CHROME_CDP_URL || 'http://chrome:3000';
  
  console.log(`Connecting to browserless at: ${cdpUrl}`);
  
  // Get the WebSocket endpoint from browserless
  const response = await fetch(`${cdpUrl}/json/version`);
  const json = await response.json();
  const wsEndpoint = json.webSocketDebuggerUrl.replace('localhost', 'chrome');
  
  console.log(`Using WebSocket: ${wsEndpoint}`);
  
  return wsEndpoint;
}

/**
 * Custom test fixture that provides CDP-connected browser and page
 * 
 * Important: Each test gets a FRESH context to ensure isolation:
 * - No cache/cookies shared between --repeat-each iterations
 * - Consistent initial state for all test runs
 * - Prevents contamination in parallel worker scenarios
 * 
 * Usage: test('my test', async ({ page }) => { ... })
 */
export const test = base.extend({
  // Override browser fixture to use CDP connection
  browser: async ({}, use) => {
    const wsEndpoint = await connectToBrowserless();
    const browser = await chromium.connectOverCDP(wsEndpoint);
    await use(browser);
    await browser.close();
  },
  
  // Override context to create fresh context for each test
  // This ensures no cache/cookie contamination between --repeat-each iterations
  context: async ({ browser }, use) => {
    // Always create a NEW context for isolation
    const context = await browser.newContext();
    await use(context);
    // Close context after test to clean up state
    await context.close();
  },
  
  // Override page to create from CDP context
  page: async ({ context }, use) => {
    const page = await context.newPage();
    await use(page);
    await page.close();
  },
});

export { expect } from '@playwright/test';

