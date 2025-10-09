# Environment Variables for External Chrome Connection

## Summary

| Tool | Environment Variable | Auto-Used? | How to Use |
|------|---------------------|------------|------------|
| **k6 browser** | `K6_BROWSER_WS_URL` | ✅ Yes | k6 automatically reads and uses it |
| **Playwright Test** | `CHROME_WS_URL` | ❌ No | Must configure in `playwright.config.js` |
| **Playwright (plain)** | `CHROME_WS_URL` | ❌ No | Manually pass to `chromium.connect()` |

## k6 Browser

**Environment Variable:** `K6_BROWSER_WS_URL=ws://chrome:3000`

k6 browser **automatically** connects to the external browser when this environment variable is set. No additional configuration needed in your test script!

```javascript
import { browser } from 'k6/browser';

export default async function () {
  const page = await browser.newPage();
  // k6 automatically uses K6_BROWSER_WS_URL if set
  await page.goto('https://example.com');
}
```

## Playwright Test Framework

**Environment Variable:** `CHROME_WS_URL=ws://chrome:3000`

Playwright Test does **NOT** automatically use environment variables. You must configure it in `playwright.config.js`:

```javascript
// playwright.config.js
module.exports = defineConfig({
  use: {
    connectOptions: process.env.CHROME_WS_URL ? {
      wsEndpoint: process.env.CHROME_WS_URL,
    } : undefined,
  },
});
```

Then in your test:

```javascript
import { test, expect } from '@playwright/test';

test('my test', async ({ page }) => {
  // Playwright Test automatically uses the connectOptions from config
  await page.goto('https://example.com');
});
```

## Plain Playwright (Node.js Script)

**Environment Variable:** `CHROME_WS_URL=ws://chrome:3000` (custom, not built-in)

For plain Playwright scripts, you manually read the environment variable and pass it:

```javascript
const { chromium } = require('playwright');

async function run() {
  // Manually read and pass the WebSocket endpoint
  const browser = await chromium.connect({
    wsEndpoint: process.env.CHROME_WS_URL || 'ws://chrome:3000',
  });
  
  const page = await browser.newPage();
  await page.goto('https://example.com');
  await browser.close();
}

run();
```

## Current Configuration

In your `docker-compose.yml`:

```yaml
# k6-browser container
environment:
  - K6_BROWSER_WS_URL=ws://chrome:3000  # Automatically used by k6

# playwright container  
environment:
  - CHROME_WS_URL=ws://chrome:3000      # Must be configured in playwright.config.js
```

## Running Commands

**k6 browser:**
```bash
docker compose exec k6-browser k6 run /test-scripts/k6/test.js
```

**Playwright Test:**
```bash
docker compose exec playwright npx playwright test /test-scripts/playwright/test.js --config=/test-scripts/playwright/playwright.config.js
```

## Why the Difference?

- **k6** is built with cloud/distributed testing in mind, so it natively supports connecting to external browsers via environment variables
- **Playwright** is more flexible and lets you control the browser connection programmatically, so you explicitly configure it in code or config files

