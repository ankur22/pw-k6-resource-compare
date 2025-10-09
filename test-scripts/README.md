# Test Scripts

Place your test scripts in this directory. They will be mounted as read-only volumes into both the k6-browser and playwright containers.

## File Structure

```
test-scripts/
├── k6/
│   └── test.js          # Your k6 browser test script
└── playwright/
    └── test.js          # Your Playwright test script
```

## Environment Variables Available

**k6 browser container:**
- `K6_BROWSER_WS_URL`: WebSocket URL to connect to external Chrome (automatically used by k6)
  - Set to: `ws://chrome:3000`

**Playwright container:**
- `CHROME_WS_URL`: WebSocket URL to connect to external Chrome (must be configured in `playwright.config.js`)
  - Set to: `ws://chrome:3000`
  - For Playwright Test, use the config file to read this variable
  - For plain Playwright, manually pass to `chromium.connect({ wsEndpoint: process.env.CHROME_WS_URL })`
