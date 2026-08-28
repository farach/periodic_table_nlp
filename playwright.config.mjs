import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  testMatch: /accessibility[.]spec[.]mjs/,
  timeout: 60000,
  fullyParallel: false,
  forbidOnly: true,
  retries: 0,
  reporter: "line",
  use: {
    baseURL: "http://127.0.0.1:48272",
    browserName: "chromium",
    headless: true,
    trace: "retain-on-failure"
  },
  webServer: {
    command: "python -m http.server 48272 --bind 127.0.0.1 --directory _site",
    url: "http://127.0.0.1:48272",
    reuseExistingServer: true,
    timeout: 30000,
    stdout: "ignore",
    stderr: "ignore"
  }
});
