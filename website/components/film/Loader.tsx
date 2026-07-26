'use client';

import { useEffect, useRef } from 'react';
import { gsap, ScrollTrigger, afterFonts } from './gsap';

/**
 * 00 — LOADER. "USAGEOWL" + calibration line + CALIBRATING 000%.
 * Max ~1.4s. The calibration line travels down into the hero composition
 * (it lands exactly on the hero's baseline rule), then the overlay wipes away.
 */
export default function Loader() {
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = root.current;
    if (!el) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      el.remove();
      return;
    }
    if (window.scrollY > 80) {
      el.remove();
      return;
    }

    document.documentElement.style.overflow = 'hidden';
    let ctx: gsap.Context | undefined;

    const cancel = afterFonts(() => {
      if (!root.current) return;
      ctx = gsap.context(() => {
        const q = gsap.utils.selector(el);
        const counter = { v: 0 };
        const num = q('.l-num')[0] as HTMLElement;

        const tl = gsap.timeline({
          defaults: { ease: 'power2.inOut' },
          onComplete: () => {
            document.documentElement.style.overflow = '';
            el.remove();
            ScrollTrigger.refresh();
          },
        });

        tl.from(q('.l-word'), { opacity: 0, y: 14, duration: 0.25, ease: 'power2.out' }, 0)
          .from(q('.l-meta'), { opacity: 0, duration: 0.2 }, 0.1)
          .fromTo(
            q('.l-fill'),
            { scaleX: 0 },
            { scaleX: 1, duration: 0.85, ease: 'power1.inOut' },
            0.1,
          )
          .to(
            counter,
            {
              v: 100,
              duration: 0.85,
              ease: 'power1.inOut',
              onUpdate: () => {
                if (num) num.textContent = String(Math.round(counter.v)).padStart(3, '0');
              },
            },
            0.1,
          )
          // the calibration line drops into the hero: lands on the hero's rule
          .to(q('.l-line'), { y: () => window.innerHeight * 0.62, duration: 0.3 }, 1.0)
          .to(q('.l-word, .l-meta'), { opacity: 0, duration: 0.2 }, 1.0)
          .to(el, { clipPath: 'inset(0 0 100% 0)', duration: 0.4, ease: 'power3.inOut' }, 1.12);
      }, root);
    });

    return () => {
      cancel();
      document.documentElement.style.overflow = '';
      ctx?.revert();
    };
  }, []);

  return (
    <div
      ref={root}
      className="loader fixed inset-0 z-[90] flex flex-col items-center justify-center bg-bg"
      style={{ clipPath: 'inset(0 0 0% 0)' }}
      aria-hidden="true"
    >
      <div className="l-word font-display text-5xl uppercase leading-none tracking-[0.01em] text-ink">
        UsageOwl
      </div>
      <div className="l-line absolute left-1/2 top-1/2 h-px w-[86vw] max-w-5xl -translate-x-1/2 bg-line2">
        <div className="l-fill h-full w-full origin-left scale-x-0 bg-green" />
      </div>
      <div className="l-meta label mt-8 text-fade">
        Calibrating <span className="l-num tnum font-semibold text-ink">000</span>%
      </div>
    </div>
  );
}
