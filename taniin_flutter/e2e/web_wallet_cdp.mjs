import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';

const baseUrl = process.env.TANIIN_E2E_BASE_URL ?? 'http://127.0.0.1:4174';
const cdpUrl = process.env.TANIIN_E2E_CDP_URL ?? 'http://127.0.0.1:9223';
const walletAddress = '0x1234567890abcdef1234567890abcdef12345678';

const browser = await chromium.connectOverCDP(cdpUrl);
const context = browser.contexts()[0] ?? await browser.newContext();
const page = context.pages()[0] ?? await context.newPage();
const errors = [];

page.on('pageerror', (error) => errors.push(error.stack ?? error.message));
page.on('console', (message) => {
  if (message.type() === 'error') {
    const text = message.text();
    if (text.includes('Failed to load resource') && text.includes('404')) {
      return;
    }
    errors.push(text);
  }
});
page.on('response', (response) => {
  if (response.status() === 404 && !response.url().endsWith('/health')) {
    errors.push(`404 ${response.url()}`);
  }
});

try {
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.addInitScript((address) => {
    localStorage.clear();
    window.__taniinEthereumRequests = [];
    window.__taniinAudioPlayCount = 0;
    window.__taniinAudioPlaySources = [];
    window.__taniinWalkBufferStartCount = 0;

    Object.defineProperty(window, 'ethereum', {
      configurable: true,
      value: {
        isMetaMask: true,
        async request(payload) {
          window.__taniinEthereumRequests.push(payload.method);
          if (payload.method === 'eth_requestAccounts') {
            return [address];
          }
          if (payload.method === 'eth_chainId') {
            return '0xaa36a7';
          }
          if (payload.method === 'wallet_switchEthereumChain') {
            return null;
          }
          return null;
        },
      },
    });

    const originalPlay = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function play() {
      window.__taniinAudioPlayCount += 1;
      window.__taniinAudioPlaySources.push(this.currentSrc || this.src || '');
      if (originalPlay) {
        try {
          const result = originalPlay.call(this);
          if (result && typeof result.catch === 'function') {
            result.catch(() => {});
          }
        } catch (_) {}
      }
      return Promise.resolve();
    };

    const originalBufferStart = AudioBufferSourceNode.prototype.start;
    AudioBufferSourceNode.prototype.start = function start(...args) {
      if (this.loop) {
        window.__taniinWalkBufferStartCount += 1;
      }
      return originalBufferStart.apply(this, args);
    };
  }, walletAddress);

  await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 45000 });
  await page.waitForSelector('flt-glass-pane', { state: 'attached' });
  await page.waitForSelector('canvas', { state: 'attached' });
  await page.waitForTimeout(3000);

  const metaMaskText = page.getByText('MetaMask').first();
  if ((await metaMaskText.count()) > 0) {
    await metaMaskText.click({ timeout: 5000 });
  } else {
    await page.mouse.click(280, 310);
  }

  await page.waitForFunction(
    () => window.__taniinEthereumRequests.includes('eth_requestAccounts'),
    null,
    { timeout: 10000 },
  );
  await page.waitForFunction(() => window.__taniinAudioPlayCount > 0, null, {
    timeout: 10000,
  });

  await page.keyboard.down('KeyW');
  await page.keyboard.down('KeyD');
  await page.waitForFunction(
    () => window.__taniinWalkBufferStartCount >= 1,
    null,
    { timeout: 10000 },
  );
  await page.keyboard.up('KeyD');
  await page.keyboard.up('KeyW');

  await mkdir('test-results', { recursive: true });
  await page.screenshot({ path: 'test-results/web-wallet-cdp.png' });

  if (errors.length > 0) {
    throw new Error(`Browser errors: ${errors.join(' | ')}`);
  }

  console.log(`E2E web wallet passed at ${baseUrl}`);
} finally {
  await browser.close();
}
