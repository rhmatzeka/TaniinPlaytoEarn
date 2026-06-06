import { expect, test } from '@playwright/test';

test('Flutter web build boots to the wallet login gate', async ({ page }) => {
  const baseUrl = process.env.TANIIN_E2E_BASE_URL ?? 'http://127.0.0.1:4173';
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') {
      errors.push(message.text());
    }
  });

  await page.goto(baseUrl, { waitUntil: 'networkidle' });

  await expect(page.locator('flt-glass-pane')).toHaveCount(1, {
    timeout: 30000,
  });
  await expect(page.locator('canvas').first()).toHaveCount(1);

  const canvasBox = await page.locator('canvas').first().boundingBox();
  expect(canvasBox?.width ?? 0).toBeGreaterThan(0);
  expect(canvasBox?.height ?? 0).toBeGreaterThan(0);
  expect(errors).toEqual([]);
});
