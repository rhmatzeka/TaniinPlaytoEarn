import { chromium } from 'playwright';
import { mkdir, writeFile } from 'node:fs/promises';

const baseUrl = process.env.TANIIN_E2E_BASE_URL ?? 'http://127.0.0.1:4173';
const cdpUrl = process.env.TANIIN_E2E_CDP_URL ?? 'http://127.0.0.1:9223';

const browser = await chromium.connectOverCDP(cdpUrl);
const context = browser.contexts()[0] ?? await browser.newContext();
const page = context.pages()[0] ?? await context.newPage();
const errors = [];
const cdpErrors = [];

const session = await context.newCDPSession(page);
await session.send('Runtime.enable');
session.on('Runtime.exceptionThrown', ({ exceptionDetails }) => {
  cdpErrors.push(JSON.stringify(exceptionDetails, null, 2));
});

page.on('pageerror', (error) => errors.push(error.stack ?? error.message));
page.on('console', (message) => {
  if (message.type() === 'error') {
    errors.push(message.text());
  }
});

try {
  await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 45000 });
  await page.waitForSelector('flt-glass-pane', { state: 'attached' });
  await page.waitForSelector('canvas', { state: 'attached' });
  await page.waitForTimeout(3000);

  const canvasBox = await page.locator('canvas').first().boundingBox();
  if (!canvasBox || canvasBox.width <= 0 || canvasBox.height <= 0) {
    throw new Error('Canvas rendered with an empty bounding box.');
  }
  if (errors.length > 0) {
    await mkdir('test-results', { recursive: true });
    await writeFile(
      'test-results/web-smoke-cdp-errors.json',
      JSON.stringify({ errors, cdpErrors }, null, 2),
    );
    throw new Error(
      `Browser errors: ${errors.join(' | ')}\nCDP exceptions: ${cdpErrors.join('\n')}`,
    );
  }

  await mkdir('test-results', { recursive: true });
  await page.screenshot({ path: 'test-results/web-smoke-cdp.png' });
  console.log(`E2E web smoke passed at ${baseUrl}`);
} finally {
  await browser.close();
}
