'use client';

import { useEffect, useRef } from 'react';
import { gsap, ScrollTrigger, afterFonts } from './gsap';

/**
 * 06 — CLIMAX. The only large color moment: owl amber, black type. The 90%
 * alert made architectural. Begin inside a giant letterform, zoom out until
 * STOP GUESSING. / START WATCHING. reads, lock to grid, compress into USAGEOWL.
 */
export default function Climax() {
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

          gsap.set(q('.c-mark'), { autoAlpha: 0 });

          const tl = gsap.timeline({
            defaults: { ease: 'none' },
            scrollTrigger: {
              trigger: el,
              start: 'top top',
              end: '+=180%',
              pin: true,
              scrub: 0.9,
              anticipatePin: 1,
            },
          });

          // inside a giant letterform — slow zoom out
          tl.fromTo(
            q('.c-letter'),
            { scale: 2.6 },
            { scale: 0.07, duration: 0.42, ease: 'power1.in' },
            0,
          )
            .to(q('.c-letter'), { autoAlpha: 0, duration: 0.08 }, 0.32)
            // the full statement becomes readable
            .fromTo(
              q('.c-l1'),
              { clipPath: 'inset(0 0 100% 0)' },
              { clipPath: 'inset(0 0 0% 0)', duration: 0.1 },
              0.38,
            )
            .fromTo(
              q('.c-l2'),
              { clipPath: 'inset(0 0 100% 0)' },
              { clipPath: 'inset(0 0 0% 0)', duration: 0.1 },
              0.46,
            )
            .from(q('.c-kick, .c-note'), { opacity: 0, duration: 0.06 }, 0.52)
            // lock the words to a strict grid
            .fromTo(q('.c-lines'), { scale: 1.05 }, { scale: 1, duration: 0.12 }, 0.52)
            // compress everything into USAGEOWL
            .to(q('.c-l1'), { yPercent: 58, autoAlpha: 0, duration: 0.09 }, 0.72)
            .to(q('.c-l2'), { yPercent: -58, autoAlpha: 0, duration: 0.09 }, 0.72)
            .to(q('.c-kick, .c-note'), { autoAlpha: 0, duration: 0.05 }, 0.72)
            .fromTo(q('.c-mark'), { autoAlpha: 0, scale: 0.72 }, { autoAlpha: 1, scale: 1, duration: 0.12 }, 0.79)
            .to(q('.c-mark'), { scale: 0.92, duration: 0.1 }, 0.91);

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
      id="climax"
      className="clx relative bg-owl text-ink"
      aria-label="Stop guessing. Start watching."
    >
      {/* the giant letterform we begin inside of */}
      <div className="c-layer c-letter items-center" aria-hidden="true">
        <span className="font-display text-[110vmin] uppercase leading-[0.86] tracking-[0.01em]">
          S
        </span>
      </div>

      {/* the statement */}
      <div className="c-layer c-statement">
        <p className="c-kick label m-0 mb-6 font-semibold">Alert 90% — 5-hour window — Claude</p>
        <div className="c-lines">
          <h2 className="c-l1 m-0 font-display text-[clamp(2.6rem,8.5vw,9.5rem)] uppercase leading-[0.9] tracking-[0.01em]">
            Stop guessing.
          </h2>
          <h2 className="c-l2 m-0 font-display text-[clamp(2.6rem,8.5vw,9.5rem)] uppercase leading-[0.9] tracking-[0.01em]">
            Start watching.
          </h2>
        </div>
        <p className="c-note label m-0 mt-8 text-ink/70">Threshold 90 of 25 · 50 · 75 · 90</p>
      </div>

      {/* the compressed mark */}
      <div className="c-layer c-mark items-center text-center">
        <span className="font-display text-[clamp(2.4rem,11vw,12rem)] uppercase leading-[0.86] tracking-[0.01em]">
          UsageOwl
        </span>
      </div>
    </section>
  );
}
