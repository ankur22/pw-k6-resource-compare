// Playwright Test configuration for connecting to external Chrome
// @ts-check

/**
 * Read environment variables from file.
 * https://github.com/motdotla/dotenv
 */
// require('dotenv').config();

/**
 * @see https://playwright.dev/docs/test-configuration
 */
module.exports = {
  testDir: '.',
  
  /* Match test files - includes test.js */
  testMatch: ['test.js', '*.spec.js', '*.test.js'],
  
  /* Run tests in files in parallel */
  fullyParallel: false,
  
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  
  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,
  
  /* Configure workers - can run tests in parallel */
  workers: 1,  // Adjust based on needs (1 for sequential, 2+ for parallel)
  
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: 'list',
  
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    // baseURL: 'http://127.0.0.1:3000',

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',
    
    /* Timeout settings */
    timeout: 30000,
  },

  /* Configure projects for major browsers */
  /* Note: Browser connection is handled by custom fixtures in fixtures.js */
  /* This allows Playwright Test to work with external Chrome via CDP */
  projects: [
    {
      name: 'chromium',
    },
  ],
};

