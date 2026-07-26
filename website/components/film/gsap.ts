'use client';

import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

export { gsap, ScrollTrigger };

/**
 * Runs `cb` after webfonts are ready (timelines must be measured against the
 * real display font). Returns a cancel function for effect cleanup.
 */
export function afterFonts(cb: () => void): () => void {
  let alive = true;
  const ready: Promise<unknown> =
    typeof document !== 'undefined' && document.fonts ? document.fonts.ready : Promise.resolve();
  ready.then(() => {
    if (alive) cb();
  });
  return () => {
    alive = false;
  };
}
