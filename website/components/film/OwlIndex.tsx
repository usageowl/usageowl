'use client';

import { useEffect, useRef } from 'react';
import { gsap, ScrollTrigger, afterFonts } from './gsap';
import GaugeRing from './GaugeRing';
import { SPEC_ROWS } from '../content';

/**
 * 05 — OWL INDEX. A huge O on the left, its arc slowly sweeping; spec rows
 * travel vertically on the right and turn amber as each aligns with the O's
 * axis. All rows compress into one line at the end.
 */
export default function OwlIndex() {
  const root = useRef<HTMLElement>(null);

  useEffect(() => {
    let ctx: gsap.Context | undefined;
    const cancel = afterFonts(() => {
      const el = root.current;
      if (!el) return;
      ctx = gsap.context(() => {
        const mm = gsap.matchMedia();
        mm.add('(prefers-reduced-motion: no-preference)', () => {
          el.classList.add('is-film');
          const q = gsap.utils.selector(el);
          const rows = q('.x-row') as HTMLElement[];
          const col = q('.x-rows')[0] as HTMLElement;
          const arc = q('.x-o [data-ring-arc]')[0];
          const ticks = q('.x-o [data-ring-ticks]')[0];
          const n = rows.length;

          const rowH = () => rows[0].offsetHeight;
          const totalH = () => rowH() * n;

          gsap.set(q('.x-condensed'), { autoAlpha: 0 });

          const tl = gsap.timeline({
            defaults: { ease: 'none' },
            scrollTrigger: {
              trigger: el,
              start: 'top top',
              end: '+=220%',
              pin: true,
              scrub: 0.9,
              anticipatePin: 1,
              invalidateOnRefresh: true,
            },
          });

          // the O enters, its axis draws, the arc sweeps
          tl.from(q('.x-o-ring'), { autoAlpha: 0, scale: 0.85, duration: 0.08 }, 0)
            .from(q('.x-axis'), { scaleX: 0, duration: 0.1 }, 0.02)
            .fromTo(arc, { strokeDashoffset: 100 }, { strokeDashoffset: 30, duration: 0.8 }, 0)
            .fromTo(ticks, { rotation: -60 }, { rotation: 30, duration: 0.8, transformOrigin: '50% 50%' }, 0)
            // rows travel across the axis
            .fromTo(
              col,
              { y: () => -rowH() / 2 },
              { y: () => -(totalH() - rowH() / 2), duration: 0.74 },
              0.04,
            );

          // amber as each row aligns with the O's horizontal axis
          rows.forEach((row, i) => {
            const p = 0.04 + (i / (n - 1)) * 0.74;
            const val = row.querySelector('.x-val');
            tl.to([row, val], { color: '#16A34A', duration: 0.015 }, p).to(
              [row, val],
              { color: '', duration: 0.015, clearProps: 'color' },
              p + 0.045,
            );
          });

          // compress all rows into one line
          tl.to(rows, { y: (i) => totalH() - rowH() * (i + 1), duration: 0.08, stagger: 0.006 }, 0.84)
            .to(rows, { autoAlpha: 0, duration: 0.05 }, 0.92)
            .to(q('.x-axis'), { autoAlpha: 0, duration: 0.05 }, 0.92)
            .to(q('.x-condensed'), { autoAlpha: 1, duration: 0.06 }, 0.94);

          return () => {
            tl.kill();
            el.classList.remove('is-film');
          };
        });
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
      id="index"
      className="idx relative bg-bg text-ink"
      aria-label="Specification index"
    >
      <div className="x-stage">
        <div className="x-o text-ink">
          <div className="x-o-ring h-full w-full">
            <GaugeRing
              className="h-full w-full"
              progress={70}
              ticks={60}
              strokeWidth={4}
              trackOpacity={0.14}
              tickOpacity={0.25}
            />
          </div>
        </div>
        <div className="x-axis choreo bg-ink/20" aria-hidden="true" />
        <div className="x-rows-wrap">
          <div className="x-rows">
            {SPEC_ROWS.map(([k, v]) => (
              <div key={k} className="x-row font-mono text-fade">
                <span className="label">{k}</span>
                <span className="x-val tnum text-[clamp(1.1rem,3.4vmin,2rem)] font-bold tracking-tight text-ink">
                  {v}
                </span>
              </div>
            ))}
          </div>
        </div>
        <p className="x-condensed label m-0 text-fade">
          <span className="text-ink">UsageOwl</span> — Free — MIT — 4.8 MB — macOS 14+ — 5
          providers — Telemetry none — Notarized DMG
        </p>
      </div>
    </section>
  );
}
