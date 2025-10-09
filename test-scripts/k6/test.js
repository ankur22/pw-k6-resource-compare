import { browser } from 'k6/browser';
import { expect } from "https://jslib.k6.io/k6-testing/0.5.0/index.js";

export const options = {
  scenarios: {
    ui: {
      vus: 15,
      iterations: 100,
      executor: 'shared-iterations',
      options: {
        browser: {
          type: 'chromium',
        },
      },
    },
  },
};

export default async function () {
  const page = await browser.newPage();
  await page.goto('https://quickpizza.grafana.com/');
  await expect(page.locator('h1')).toContainText('Looking to break out of your pizza routine?');
  await page.getByRole('button', { name: 'Pizza, Please!' }).click();
  await expect(page.locator('#pizza-name')).toContainText('Our recommendation:');
  await expect(page.getByRole('button', { name: 'No thanks' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Love it!' })).toBeVisible();
  
  await page.waitForTimeout(1000);
}
