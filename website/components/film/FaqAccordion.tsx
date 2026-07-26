'use client';

import { useState } from 'react';
import { FAQ } from '../content';

/**
 * 08 — FAQ. Rounded rows, keyboard-accessible accordion.
 */
export default function FaqAccordion() {
  const [open, setOpen] = useState<number | null>(0);

  return (
    <div className="rounded-2xl border border-line bg-surface px-6 depth-1">
      {FAQ.map((item, i) => {
        const isOpen = open === i;
        return (
          <div key={item.q} className={i > 0 ? 'border-t border-line' : ''}>
            <button
              type="button"
              onClick={() => setOpen(isOpen ? null : i)}
              aria-expanded={isOpen}
              aria-controls={`faq-a-${i}`}
              id={`faq-q-${i}`}
              className="group grid w-full grid-cols-[auto_1fr_auto] items-baseline gap-4 py-5 text-left sm:gap-6"
            >
              <span className="font-mono text-[10px] text-dim tnum">
                {String(i + 1).padStart(2, '0')}
              </span>
              <span className="font-display text-xl leading-tight tracking-[0.01em] text-ink transition-colors duration-150 group-hover:text-green sm:text-2xl">
                {item.q}
              </span>
              <span
                className={`relative h-3.5 w-3.5 shrink-0 self-center text-dim transition-colors duration-150 group-hover:text-green motion-safe:transition-transform motion-safe:duration-200 ${
                  isOpen ? 'rotate-45 text-green' : ''
                }`}
                aria-hidden="true"
              >
                <span className="absolute inset-x-0 top-1/2 h-px -translate-y-1/2 bg-current" />
                <span className="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-current" />
              </span>
            </button>
            <div
              id={`faq-a-${i}`}
              role="region"
              aria-labelledby={`faq-q-${i}`}
              className={`grid motion-safe:transition-all motion-safe:duration-300 motion-safe:ease-out ${
                isOpen ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'
              }`}
            >
              <div className="overflow-hidden">
                <p className="max-w-2xl pb-6 pl-8 pr-8 text-[15px] leading-relaxed text-fade sm:pl-10">
                  {item.a}
                </p>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
