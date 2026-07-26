/**
 * Regenerates public/images/{popup,menubar,notify}.png from product-renders.html.
 * Dev-only: requires Playwright installed globally (`npm i -g playwright`).
 * Run: node tools/render-screenshots.js
 */
const path = require('path');
const fs = require('fs');

let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  ({ chromium } = require('/opt/homebrew/lib/node_modules/playwright'));
}

(async () => {
  const root = path.resolve(__dirname, '..');
  const outDir = path.join(root, 'public', 'images');
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 800, height: 1200 }, deviceScaleFactor: 2 });
  await page.goto('file://' + path.join(root, 'tools', 'product-renders.html'));
  await page.waitForTimeout(400);

  for (const [id, name] of [
    ['shot-popup', 'popup'],
    ['shot-menubar', 'menubar'],
    ['shot-notify', 'notify'],
  ]) {
    await page.locator('#' + id).screenshot({ path: path.join(outDir, `${name}.png`), omitBackground: true });
    console.log(`${name}.png saved`);
  }
  await browser.close();
})();
