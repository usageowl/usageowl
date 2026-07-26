# UsageOwl — Website

Marketing site for [usageowl.com](https://usageowl.com). The download CTA leads; three short scroll-film moments (thresholds, spec index, amber climax) sit between static spinyield-style sections. Built with Next.js 15 (App Router, static export) + TypeScript + Tailwind CSS + GSAP ScrollTrigger. All artwork is inline SVG, all fonts are bundled at build time via `next/font/google`.

## Commands

```bash
npm install      # install dependencies
npm run dev      # local dev server at http://localhost:3000 (site only)
npm run build    # production build — static export written to out/
npm run preview  # build + serve out/ with the Pages Function (wrangler pages dev)
npm run deploy   # build + deploy out/ to Cloudflare Pages
```

Optional: `cp .dev.vars.example .dev.vars` and fill `STRIPE_SECRET_KEY` to make
the Buy-me-a-coffee tip jar functional in `npm run preview` (it degrades
gracefully without it).

## Deploy

Hosted on **Cloudflare Pages**: the site is a static export (`out/`) plus one
Pages Function (`functions/api/coffee.ts`, the Stripe tip checkout) that runs
on Cloudflare's edge.

- First deploy: `npm run deploy` (wrangler prompts for login + a project name).
- Env vars: Cloudflare Pages → your project → **Settings → Environment
  variables** → add `STRIPE_SECRET_KEY` (and `STRIPE_COFFEE_PRODUCT_ID`, see
  `tools/create-coffee-product.mjs`). Or `npx wrangler pages secret put
  STRIPE_SECRET_KEY --project-name <name>`.
- Custom domain: Pages project → **Custom domains** → add `usageowl.com`.
- No analytics, no tracking anywhere in that flow.

## Page flow

```
00  Loader        calibration line + CALIBRATING 000→100% (max ~1.5s)
01  Hero          STATIC — FREE FOREVER. MIT LICENSED. + CTAs + brew strip + product popup render
02  Providers     static — 5 provider cards + "your provider here"
03  Thresholds    FILM — pinned 25 → 50 → 75 → 90 (horizontal on desktop, vertical on mobile)
04  Features      static — WATCH / WARN / RESET cards + menu-bar & notification renders
05  Owl Index     FILM — huge O, spec rows cross its axis, green flash per row, compress to one line
06  Privacy       static — three ruled statements
07  Climax        FILM — amber scene: inside a giant S → STOP GUESSING. START WATCHING. → USAGEOWL
08  FAQ + Footer  static — accordion (answers verbatim from product docs) + grid-floor footer
```

## Product renders

`public/images/{popup,menubar,notify}.png` are faithful recreations of the real app UI
(SwiftUI layout in `app/Sources/UsageOwl/Views/MenuPopover.swift`), rendered at 2x from
`tools/product-renders.html`. Edit the HTML to change the data shown, then regenerate with
`node tools/render-screenshots.js` (requires Playwright).


## Visual system

- **Canvas** — spinyield light: `bg #F6F8FE`, `surface #FFFFFF`, `surface2 #EEF2FB`, `ink #111827`, hairlines `#E3E8F4`.
- **Terminal** — `#0C111B` / `#E9EEFB` / `#34D399` for the install strip and menu-bar chips.
- **Accents** — green `#16A34A` is the interactive/gauge color; UsageOwl amber `#F0B429` is reserved for the climax narrative.
- **Type** — Bangers (display), Poppins (body), IBM Plex Mono (labels, numerals — tabular everywhere) via `next/font/google`.
- **Chrome** — rounded chips/cards (`rounded-xl/2xl`), `depth-*` blue-tinted shadows, `card-hover` lift, `grid-floor` vanishing grid in footer, `btn-green`/`btn-ghost` button recipe.

## Structure

```
app/
  layout.tsx           metadata / OG tags / fonts (Bangers + Poppins + IBM Plex Mono)
  page.tsx             page flow: loader, nav, hero, statics, 3 film scenes, footer
  globals.css          tokens, nav theming, spinyield chrome, scene structure (static vs is-film)
  icon.svg             favicon (ring-gauge O)
  opengraph-image.tsx  OG image, generated at build time
  api/coffee/          (removed — endpoint now lives in functions/)
  coffee/thanks/       static post-payment thank-you page (noindex)
functions/
  api/coffee.ts        Pages Function — POST: creates the Stripe Checkout session for a tip
lib/
  coffee.ts            tip amounts ($3/$5/$10/$20 presets, $5 default, $1–$500 custom) + validator
components/
  content.ts           copy + data (specs, providers, privacy, FAQ answers)
  OwlLogo.tsx          owl mark (small sizes only: nav)
  film/
    gsap.ts            plugin registration + document.fonts.ready helper
    GaugeRing.tsx      the O: reusable ring-gauge SVG (track, arc, ticks)
    SiteNav.tsx        fixed menu-bar nav — theme (light/amber) + progress + active link
    Loader.tsx         calibration loader (max ~1.5s)
    Hero.tsx           static download hero with cropped O
    Providers.tsx      provider cards
    Thresholds.tsx     FILM — pinned threshold count
    Features.tsx       WATCH / WARN / RESET cards
    OwlIndex.tsx       FILM — spec index on the O's axis
    Privacy.tsx        privacy statements
    Climax.tsx         FILM — amber STOP GUESSING. START WATCHING.
    Faq.tsx            eyebrow + accordion wrapper
    FaqAccordion.tsx   keyboard-accessible accordion (client component)
    Footer.tsx         grid-floor footer (hosts the Buy me a coffee button)
    BuyCoffee.tsx      tip dialog — presets + custom amount → /api/coffee (client component)
    Eyebrow.tsx        numbered mono section eyebrow
```

## Motion engineering

- One GSAP timeline per film scene, `scrub` 0.9, pinned via ScrollTrigger; native scroll drives everything (no scroll-jacking).
- Timelines are built inside `gsap.context()` only after `document.fonts.ready`, with `gsap.matchMedia` for responsive variants (thresholds run horizontally ≥768px, vertically below).
- Gauge motion via `stroke-dashoffset` (pathLength=100); typography via transforms and `clip-path`.
- Default DOM of every film scene is a fully readable stacked layout. `.is-film` is added per scene only under `prefers-reduced-motion: no-preference` — reduced-motion users get all content with zero pinning or zoom; the static sections animate nothing at all (hero uses a one-time CSS fade-up, also gated).
- Nav state (light / amber themes, active link, scroll progress) is computed deterministically from pinned ranges and element positions, not from trigger callbacks.
- `ScrollTrigger.refresh()` after font load; `invalidateOnRefresh` for measurement-based transforms.


