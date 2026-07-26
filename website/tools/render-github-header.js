/**
 * Renders .github/header.png — the banner at the top of the repo README.
 *
 * Dark on purpose: GitHub renders READMEs on white or near-black depending on
 * the viewer's theme, and a dark banner with its own background reads
 * deliberately in both, where a light one glows on the dark theme.
 *
 * Dev-only: requires Playwright installed globally (`npm i -g playwright`).
 * Run: node tools/render-github-header.js
 */
const path = require('path');
const fs = require('fs');

let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  ({ chromium } = require('/opt/homebrew/lib/node_modules/playwright'));
}

const W = 1280;
const H = 440;

const PROVIDERS = ['CLAUDE', 'KIMI', 'CODEX', 'COPILOT', 'MOONSHOT'];

// Ring geometry, rounded to 3dp for the same reason GaugeRing.tsx does it.
const r3 = (n) => Math.round(n * 1000) / 1000;
const ticks = (count, r1, r2) =>
  Array.from({ length: count }, (_, i) => {
    const a = (i / count) * Math.PI * 2 - Math.PI / 2;
    const major = i % 5 === 0;
    const inner = major ? r1 - 2 : r1;
    return `<line x1="${r3(50 + Math.cos(a) * inner)}" y1="${r3(50 + Math.sin(a) * inner)}" x2="${r3(50 + Math.cos(a) * r2)}" y2="${r3(50 + Math.sin(a) * r2)}" stroke="#F0B429" stroke-width="${major ? 1 : 0.5}" opacity="0.32"/>`;
  }).join('');

const html = `
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Bangers&family=IBM+Plex+Mono:wght@400;600&display=swap" rel="stylesheet">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { width: ${W}px; height: ${H}px; overflow: hidden; }
  .wrap {
    position: relative; width: ${W}px; height: ${H}px;
    background: #0C111B;
    display: flex; align-items: center; justify-content: space-between;
    padding: 0 72px;
    font-family: 'IBM Plex Mono', ui-monospace, monospace;
    overflow: hidden;
  }
  /* faint grid, same motif as the site's background */
  .grid {
    position: absolute; inset: 0;
    background-image:
      linear-gradient(rgba(59,130,246,0.06) 1px, transparent 1px),
      linear-gradient(90deg, rgba(59,130,246,0.06) 1px, transparent 1px);
    background-size: 44px 44px;
  }
  .glow {
    position: absolute; width: 720px; height: 720px; right: -180px; top: -220px;
    background: radial-gradient(circle, rgba(240,180,41,0.13) 0%, transparent 62%);
  }
  .left { position: relative; z-index: 2; }
  .mark { display: flex; align-items: center; gap: 16px; margin-bottom: 26px; }
  .word {
    font-family: 'Bangers', system-ui; font-size: 82px; line-height: 0.86;
    letter-spacing: 0.02em; color: #F0B429; text-transform: uppercase;
  }
  .tag {
    font-size: 21px; font-weight: 600; color: #E9EEFB;
    letter-spacing: -0.01em; margin-bottom: 14px;
  }
  .sub { font-size: 13.5px; color: #9FB0CF; letter-spacing: 0.02em; margin-bottom: 30px; }
  .chips { display: flex; gap: 8px; margin-bottom: 26px; }
  .chip {
    font-size: 11px; font-weight: 600; letter-spacing: 0.13em;
    color: #C9D6F0; border: 1px solid #222D42; background: rgba(233,238,251,0.03);
    border-radius: 6px; padding: 6px 11px;
  }
  .badges { display: flex; gap: 22px; font-size: 12px; letter-spacing: 0.11em; }
  .badge { color: #5F7191; }
  .badge b { color: #34D399; font-weight: 600; }
  .right { position: relative; z-index: 2; width: 300px; height: 300px; }
  .pct {
    position: absolute; inset: 0; display: flex; flex-direction: column;
    align-items: center; justify-content: center;
  }
  .pct .n {
    font-family: 'Bangers', system-ui; font-size: 92px; color: #F0B429; line-height: 1;
  }
  .pct .l { font-size: 11px; letter-spacing: 0.2em; color: #9FB0CF; margin-top: 8px; }
</style>
<div class="wrap">
  <div class="grid"></div>
  <div class="glow"></div>

  <div class="left">
    <div class="mark">
      <svg width="60" height="60" viewBox="0 0 64 64">
        <rect width="64" height="64" rx="14" fill="#F0B429"/>
        <path d="M15 9 L26 19 L15 21 Z" fill="#0C111B"/>
        <path d="M49 9 L38 19 L49 21 Z" fill="#0C111B"/>
        <circle cx="32" cy="36" r="21" stroke="#0C111B" stroke-width="3.5" fill="none"/>
        <circle cx="24" cy="33" r="7" fill="#0C111B"/>
        <circle cx="40" cy="33" r="7" fill="#0C111B"/>
        <circle cx="24" cy="33" r="2.8" fill="#F0B429"/>
        <circle cx="40" cy="33" r="2.8" fill="#F0B429"/>
        <path d="M32 41 L28.5 46.5 L35.5 46.5 Z" fill="#0C111B"/>
      </svg>
      <div class="word">UsageOwl</div>
    </div>

    <div class="tag">Every AI subscription. One menu bar.</div>
    <div class="sub">Never hit a rate limit mid-task again.</div>

    <div class="chips">${PROVIDERS.map((p) => `<div class="chip">${p}</div>`).join('')}</div>

    <div class="badges">
      <div class="badge"><b>FREE</b> FOREVER</div>
      <div class="badge"><b>MIT</b> LICENSED</div>
      <div class="badge"><b>NO</b> TELEMETRY</div>
    </div>
  </div>

  <div class="right">
    <svg viewBox="0 0 100 100" width="300" height="300">
      <circle cx="50" cy="50" r="45" fill="none" stroke="#E9EEFB" stroke-width="3" opacity="0.09"/>
      <circle cx="50" cy="50" r="45" fill="none" stroke="#F0B429" stroke-width="3"
              pathLength="100" stroke-dasharray="100" stroke-dashoffset="9"
              stroke-linecap="round" transform="rotate(-90 50 50)"/>
      <g>${ticks(60, 37.5, 41.5)}</g>
    </svg>
    <div class="pct">
      <div class="n">91%</div>
      <div class="l">CLAUDE · 5-HOUR</div>
    </div>
  </div>
</div>
`;

(async () => {
  const outDir = path.resolve(__dirname, '..', '..', '.github');
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: W, height: H },
    deviceScaleFactor: 2,
  });
  await page.setContent(html, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(600);
  const out = path.join(outDir, 'header.png');
  await page.screenshot({ path: out });
  await browser.close();
  console.log('wrote', out, fs.statSync(out).size, 'bytes');
})();
