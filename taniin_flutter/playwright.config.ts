import { defineConfig } from '@playwright/test';

const executablePath = process.env.TANIIN_E2E_BROWSER_PATH;

export default defineConfig({
  testDir: 'e2e',
  use: {
    launchOptions: executablePath ? { executablePath } : undefined,
  },
});
