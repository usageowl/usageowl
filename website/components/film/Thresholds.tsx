'use client';

import { useEffect, useRef } from 'react';
import { gsap, ScrollTrigger, afterFonts } from './gsap';
import GaugeRing from './GaugeRing';

const PANELS = [
  {
    n: '25',
    head: 'FIRST NOTICE — EARLY WARNING',
    rows: ['CLAUDE · 5H WINDOW — 25% USED', 'RESET IN 4H 02M'],
  },
  {
    n: '50',
    head: 'HALF — PACE YOURSELF',
    rows: ['KIMI · WEEKLY — 50% USED', 'RESETS MON 9:00'],
  },
  {
    n: '75',
    head: 'PLAN THE FINISH',
    rows: ['CODEX · PRIMARY — 75% USED', 'RESET IN 1H 17M'],
  },
];

const STEPS = [25, 50, 75, 90];

/**
 * 03 — THRESHOLDS. Warm paper. Vertical scroll drives horizontal movement
 * (vertical on mobile): 25 → 50 → 75 → 90, numerals as architecture. The "0"
 * of 90 enlarges into a ring-mask revealing the dark scene that follows.
 */
export default function Thresholds() {
  const root = useRef<HTMLElement>(null);

  useEffect(() => {
    let ctx: gsap.Context | undefined;
    const cancel = afterFonts(() => {
      const el = root.current;
      if (!el) return;
      ctx = gsap.context(() => {
        const mm = gsap.matchMedia();
        mm.add(
          {
            noMotion: '(prefers-reduced-motion: no-preference)',
            desktop: '(min-width: 768px)',
            mobile: '(max-width: 767px)',
          },
          (mctx) => {
            if (!mctx.conditions?.noMotion) return;
            el.classList.add('is-film');
            const q = gsap.utils.selector(el);
            const track = q('.t-track')[0] as HTMLElement;
            const portal = q('.t-portal')[0] as HTMLElement;
            const readout = q('.t-readout-num')[0] as HTMLElement;
            const isDesktop = !!mctx.conditions.desktop;

            const travel = () =>
              isDesktop
                ? track.scrollWidth - window.innerWidth
                : track.scrollHeight - window.innerHeight;

            const portalScale = () => {
              const d = Math.hypot(window.innerWidth, window.innerHeight);
              return (d * 1.35) / portal.getBoundingClientRect().width || 10;
            };

            const tl = gsap.timeline({
              defaults: { ease: 'none' },
              scrollTrigger: {
                trigger: el,
                start: 'top top',
                end: '+=240%',
                pin: true,
                scrub: 0.9,
                anticipatePin: 1,
                invalidateOnRefresh: true,
              },
            });

            // the count: 25 → 50 → 75 → 90
            tl.to(track, isDesktop ? { x: () => -travel(), duration: 0.78 } : { y: () => -travel(), duration: 0.78 }, 0)
              .from(q('.t-head'), { opacity: 0, y: -12, duration: 0.06 }, 0)
              .from(q('.t-foot'), { opacity: 0, y: 12, duration: 0.06 }, 0)
              // the final "0" of 90 enlarges into the ring-mask
              .fromTo(
                portal,
                { scale: 0 },
                { scale: portalScale, duration: 0.2, ease: 'power1.in' },
                0.8,
              )
              .to(q('.t-head, .t-foot, .t-readout'), { opacity: 0, duration: 0.08 }, 0.84);

            // instrument readout follows the count
            tl.eventCallback('onUpdate', () => {
              if (!readout) return;
              const p = tl.progress();
              const idx = Math.min(3, Math.max(0, Math.round((p / 0.78) * 4 - 0.5)));
              const txt = String(STEPS[idx]).padStart(3, '0');
              if (readout.textContent !== txt) readout.textContent = txt;
            });

            return () => {
              tl.kill();
              el.classList.remove('is-film');
            };
          },
        );
      }, root);
      ScrollTrigger.refresh();
    });
    return () => {
      cancel();
      ctx?.revert();
    };
  }, []);

  return (
    <section
      ref={root}
      id="thresholds"
      className="thr relative bg-bg text-ink"
      aria-label="Threshold alerts — 25, 50, 75, 90 percent"
    >
      {/* persistent frame */}
      <div className="t-head pointer-events-none absolute inset-x-0 top-[56px] z-10 border-b border-line bg-bg px-5 py-2 sm:left-8 sm:right-auto sm:top-24 sm:border-0 sm:bg-transparent sm:p-0">
        <p className="label m-0 text-ink/70">Threshold alerts — 25 · 50 · 75 · 90</p>
        <p className="label m-0 mt-2 hidden text-ink/70 sm:block">Reset countdowns — to the minute</p>
      </div>
      <div className="t-readout pointer-events-none absolute right-5 top-20 z-10 hidden sm:right-8 sm:top-24 sm:block">
        <p className="label m-0 text-ink/70">
          Threshold — <span className="t-readout-num tnum font-bold text-ink">025</span>%
        </p>
      </div>
      <div className="t-foot pointer-events-none absolute bottom-6 left-5 right-5 z-10 hidden justify-between sm:left-8 sm:right-8 sm:flex">
        <p className="label m-0 text-ink/70">Per provider. Per window.</p>
        <p className="label m-0 text-ink/70">Warned — never surprised mid-task</p>
      </div>

      <div className="t-track">
        {PANELS.map((p) => (
          <div key={p.n} className="t-panel">
            <div className="font-mono text-[26vw] font-bold leading-[0.85] tracking-[-0.05em] tnum md:text-[52vh]">
              {p.n}
              <span className="align-top text-[0.22em] font-normal tracking-normal">%</span>
            </div>
            <div className="mt-6 md:mt-10">
              <p className="label m-0 font-bold text-ink">{p.head}</p>
              {p.rows.map((r) => (
                <p key={r} className="label m-0 mt-2 text-ink/60">
                  {r}
                </p>
              ))}
              {/* cropped menu-bar fragment */}
              <div className="depth-2 mt-6 inline-flex items-center gap-2 rounded-lg border border-tline bg-term px-3 py-1.5 text-tpaper">
                <GaugeRing
                  className="h-3.5 w-3.5"
                  progress={parseInt(p.n, 10)}
                  ticks={0}
                  showTicks={false}
                  strokeWidth={16}
                  trackOpacity={0.25}
                />
                <span className="font-mono text-[10px] tracking-[0.14em] tnum">{p.n}% USED</span>
              </div>
            </div>
          </div>
        ))}

        {/* 90 — the final panel, its "0" is the portal into the dark scene */}
        <div className="t-panel t-panel-final">
          <div className="flex items-center justify-center font-mono text-[26vw] font-bold leading-[0.85] tracking-[-0.05em] tnum md:text-[52vh]">
            9
            <span className="relative mx-[0.02em] inline-flex h-[0.6em] w-[0.6em] items-center justify-center rounded-full border-[0.045em] border-ink">
              <span className="t-portal absolute inset-0 block rounded-full bg-term" />
            </span>
            <span className="align-top text-[0.22em] font-normal tracking-normal">%</span>
          </div>
          <div className="mt-6 text-center md:mt-10">
            <p className="label m-0 font-bold text-ink">THE WALL IS CLOSE</p>
            <p className="label m-0 mt-2 text-ink/60">COPILOT · PREMIUM — 90% USED</p>
            <p className="label m-0 mt-2 text-ink/60">RESETS IN 6D</p>
          </div>
        </div>
      </div>
    </section>
  );
}
