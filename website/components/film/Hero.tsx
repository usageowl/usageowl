import GaugeRing from './GaugeRing';
import { GITHUB_URL, MIN_MACOS } from '../content';
import type { ReleaseInfo } from '@/lib/release';

/**
 * 01 — HERO (static). The download CTA leads the page: amber mark, the
 * free-forever statement, credentials line, buttons, terminal install strip,
 * and the huge cropped O resting at 0% below the fold — calm.
 */
export default function Hero({ release }: { release: ReleaseInfo }) {
  return (
    <section id="top" className="relative min-h-screen overflow-hidden bg-bg text-ink" aria-label="UsageOwl">
      {/* huge cropped O below the viewport, arc at 0% */}
      <div
        className="pointer-events-none absolute left-1/2 top-[86%] w-[150vmin] -translate-x-1/2 text-ink"
        aria-hidden="true"
      >
        <GaugeRing
          className="h-full w-full"
          progress={0}
          ticks={96}
          strokeWidth={2.2}
          trackOpacity={0.1}
          tickOpacity={0.12}
          arc={false}
        />
      </div>

      <div className="relative flex min-h-screen flex-col px-6 pb-40 pt-32 sm:px-[6vw] lg:justify-center lg:pt-24">
        <span className="hero-in absolute left-6 top-20 font-display text-4xl uppercase leading-none tracking-[0.01em] text-owl sm:left-[6vw] sm:top-24" style={{ ['--d' as string]: '1.55s' }}>
          UsageOwl
        </span>

        {/*
          Both lines live inside the h1 so the page's one top-level heading
          leads with what the product *is* — crawlers and LLMs read the h1 as
          the subject of the page, and "Free forever. MIT licensed." alone
          never says this is a menu bar app. Visual hierarchy is unchanged:
          the eyebrow keeps .label, the statement keeps the display face.
        */}
        <h1 className="m-0">
          <span
            className="hero-in label m-0 mb-6 block text-green"
            style={{ ['--d' as string]: '1.65s' }}
          >
            Every AI subscription. One menu bar.
          </span>
          <span
            className="hero-in block font-display text-[clamp(2.6rem,6.2vw,6.4rem)] uppercase leading-[0.94] tracking-[0.01em] text-ink"
            style={{ ['--d' as string]: '1.72s' }}
          >
            Free forever.
            <br />
            MIT licensed.
          </span>
        </h1>
        <p className="hero-in m-0 mt-6 text-base text-fade" style={{ ['--d' as string]: '1.8s' }}>
          Your credentials never leave your Mac.
        </p>

        <div className="hero-in mt-10 flex flex-wrap items-center gap-4" style={{ ['--d' as string]: '1.88s' }}>
          {/*
            Straight to the file, not to the releases page. GitHub serves the
            asset with `content-disposition: attachment`, so this starts the
            download in place — no tab, no intermediate page, nothing to hunt
            for. Unlike the nav's install button this opens no menu: the hero
            CTA should be one click, and the strip below already states the
            version, OS floor and size that a menu would have carried.
          */}
          <a href={release.dmgUrl} download className="btn btn-green">
            Download for macOS
            <span className="cta-arrow" aria-hidden="true">
              →
            </span>
          </a>
          <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className="btn btn-ghost">
            View on GitHub
            <span className="cta-arrow inline-block" aria-hidden="true">
              ↗
            </span>
          </a>
        </div>

        {/*
          This strip used to advertise `brew install --cask usageowl`. No such
          cask is published (Homebrew is still a roadmap item), so the command
          failed for anyone who copied it. Restore the terminal form — `$` +
          the command — only once the cask is actually live in a tap.
        */}
        <div
          className="hero-in depth-2 mt-10 inline-flex w-fit items-center gap-3 rounded-xl border border-tline bg-term px-4 py-3 font-mono text-[13px] text-tpaper"
          style={{ ['--d' as string]: '1.96s' }}
        >
          <span className="font-semibold text-tgreen" aria-hidden="true">
            ✓
          </span>
          <span className="tnum">UsageOwl {release.version} · Signed &amp; notarized</span>
          <span className="tnum hidden text-tdim sm:inline">
            · {MIN_MACOS} · Universal · {release.size}
          </span>
        </div>

        {/* the product, live: the actual menu bar popup */}
        <div className="mt-14 w-[min(340px,100%)] lg:absolute lg:right-[6vw] lg:top-1/2 lg:mt-0 lg:-translate-y-1/2">
          <div className="hero-in" style={{ ['--d' as string]: '2.1s' }}>
            <div className="tilt">
              <div className="float-y">
                <img
                  src="/images/popup.png"
                  alt="UsageOwl menu bar popup: Claude's 5-hour window at 91% with a red bar, Kimi at 32%, Codex at 4%, Copilot at 41%, Moonshot balance $14.02, and per-provider menu bar toggles"
                  width={680}
                  height={1902}
                  className="depth-2 h-auto w-full rounded-2xl lg:h-[min(84vh,880px)] lg:w-auto"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
