'use client';

import { useEffect, useRef } from 'react';
import { gsap, ScrollTrigger, afterFonts } from './gsap';
import OwlLogo from '../OwlLogo';
// import BuyCoffee from './BuyCoffee';  // hidden until Stripe is configured
import InstallMenu from './InstallMenu';
import type { ReleaseInfo } from '@/lib/release';

const LINKS = [
  { href: '#watch', label: 'features', id: 'watch' },
  { href: '#thresholds', label: 'thresholds', id: 'thresholds' },
  { href: '#index', label: 'specs', id: 'index' },
  { href: '#faq', label: 'faq', id: 'faq' },
];

const THEMES: Record<string, string> = {
  climax: 'amber',
};

/**
 * Fixed minimal navigation. Color state follows the active scene
 * (paper text on dark, ink on paper/amber); a fill tracks scroll progress.
 * State is computed deterministically from the scenes' pinned ranges.
 */
export default function SiteNav({ release }: { release: ReleaseInfo }) {
  const root = useRef<HTMLElement>(null);

  useEffect(() => {
    let ctx: gsap.Context | undefined;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const cancel = afterFonts(() => {
      const el = root.current;
      if (!el) return;
      // wait one tick so every scene has registered its pinned ScrollTrigger
      timer = setTimeout(() => {
        ctx = gsap.context(() => {
          const q = gsap.utils.selector(el);
          const fill = q('.nav-fill')[0] as HTMLElement;
          const links = LINKS.map((l) => ({
            id: l.id,
            node: q(`[data-nav="${l.id}"]`)[0] as HTMLElement | undefined,
          }));

          const pinned = () =>
            ScrollTrigger.getAll()
              .filter((st) => st.pin && st.trigger instanceof HTMLElement)
              .map((st) => ({
                id: (st.trigger as HTMLElement).id,
                start: st.start,
                end: st.end,
              }));

          let ranges = pinned();
          const onRefresh = () => {
            ranges = pinned();
            update();
          };

          const update = () => {
            const y = window.scrollY;
            const vh = window.innerHeight;
            const line = y + vh * 0.04; // theme follows the scene directly under the nav band

            let theme = 'light';
            for (const r of ranges) {
              if (line >= r.start && line <= r.end + vh && THEMES[r.id]) {
                theme = THEMES[r.id];
              }
            }
            if (el.dataset.theme !== theme) el.dataset.theme = theme;

            // active link: pinned scenes by range, static sections by element position
            const mid = y + vh * 0.5;
            for (const l of links) {
              if (!l.node) continue;
              let on = false;
              const pinned = ranges.find((r) => r.id === l.id);
              if (pinned) {
                on = mid >= pinned.start && mid <= pinned.end + vh;
              } else {
                const sec = document.getElementById(l.id);
                if (sec) {
                  const top = sec.getBoundingClientRect().top + y;
                  on = mid >= top && mid <= top + sec.offsetHeight;
                }
              }
              const val = on ? 'true' : 'false';
              if (l.node.dataset.active !== val) l.node.dataset.active = val;
            }
            const max = ScrollTrigger.maxScroll(window);
            if (fill) fill.style.transform = `scaleX(${max > 0 ? y / max : 0})`;
          };

          window.addEventListener('scroll', update, { passive: true });
          ScrollTrigger.addEventListener('refresh', onRefresh);
          update();

          return () => {
            window.removeEventListener('scroll', update);
            ScrollTrigger.removeEventListener('refresh', onRefresh);
          };
        }, root);
      }, 0);
    });
    return () => {
      cancel();
      if (timer !== undefined) clearTimeout(timer);
      ctx?.revert();
    };
  }, []);

  return (
    <header ref={root} className="site-nav fixed inset-x-0 top-0 z-[80]" data-theme="light">
      <div className="flex h-14 items-center justify-between px-5 sm:px-8">
        <a href="#top" className="flex items-center gap-2.5" aria-label="UsageOwl — back to top">
          <OwlLogo className="h-6 w-6" />
          <span className="font-display text-2xl leading-none tracking-[0.01em]">usageowl</span>
        </a>
        <nav aria-label="Sections" className="flex items-center gap-6 sm:gap-7">
          {LINKS.map((l) => (
            <a
              key={l.id}
              href={l.href}
              data-nav={l.id}
              data-active="false"
              className="nav-link hidden font-mono text-xs md:block"
            >
              {l.label}
            </a>
          ))}
          {/*
            Tip jar hidden until Stripe is configured — without a key the
            checkout call answers "Payments are not configured yet.", which is
            a worse first impression than no button at all. To restore:
            uncomment the import above and the line below.
          */}
          <div className="flex items-center gap-2.5">
            {/* <BuyCoffee variant="nav" /> */}
            <InstallMenu release={release} />
          </div>
        </nav>
      </div>
      <div className="nav-fill h-[2px] w-full origin-left scale-x-0" />
    </header>
  );
}
