// Playwright Test that connects to external Chrome via CDP
// Uses custom fixtures to enable Playwright Test features (workers, retries, reporters)
// Run with: npx playwright test test.spec.js
import { test, expect } from './fixtures.js';

test('QuickPizza navigation and interaction', async ({ page }) => {
  page.on('request', (request) => {
    console.log(request.url(), request.method(), request.headers(), request.postData());
  });

  page.on('response', (response) => {
    console.log(response.url(), response.status(), response.body());
  });
  
  const r = await page.goto('https://quickpizza.grafana.com/');
  await expect(page.locator('h1')).toContainText('Looking to break out of your pizza routine?');
  await page.getByRole('button', { name: 'Pizza, Please!' }).click();
  await expect(page.locator('#pizza-name')).toContainText('Our recommendation:');
  await expect(page.getByRole('button', { name: 'No thanks' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Love it!' })).toBeVisible();

  await page.waitForTimeout(1000);
});
