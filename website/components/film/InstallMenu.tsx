'use client';

import { useEffect, useId, useRef, useState } from 'react';
import type { ReleaseInfo } from '@/lib/release';
import { MIN_MACOS } from '../content';

function DownloadGlyph({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      <path d="M12 3v12" />
      <path d="m7 10 5 5 5-5" />
      <path d="M4 20h16" />
    </svg>
  );
}

/**
 * The nav's install control: a button that opens a small panel stating exactly
 * what you're about to get — version, OS floor, architecture, file size —
 * before the download starts.
 *
 * The download itself is a plain anchor to the GitHub release asset. GitHub
 * answers that URL with `content-disposition: attachment`, so the file starts
 * downloading in place; no tab opens and no intermediate page loads. The
 * `download` attribute is set for correctness even though browsers ignore it
 * cross-origin — the header is what actually does the work here.
 */
export default function InstallMenu({ release }: { release: ReleaseInfo }) {
  const [open, setOpen] = useState(false);
  const panelId = useId();
  const wrap = useRef<HTMLDivElement>(null);
  const button = useRef<HTMLButtonElement>(null);

  // Escape closes and returns focus to the trigger; a click anywhere outside
  // dismisses. Both are registered only while open so the page isn't carrying
  // idle listeners through every scroll of a GSAP-heavy page.
  useEffect(() => {
    if (!open) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setOpen(false);
        button.current?.focus();
      }
    };
    const onPointer = (e: PointerEvent) => {
      if (!wrap.current?.contains(e.target as Node)) setOpen(false);
    };

    window.addEventListener('keydown', onKey);
    window.addEventListener('pointerdown', onPointer);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.removeEventListener('pointerdown', onPointer);
    };
  }, [open]);

  return (
    <div ref={wrap} className="relative">
      <button
        ref={button}
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-haspopup="true"
        aria-controls={open ? panelId : undefined}
        className="btn btn-green !px-3.5 !py-1.5 !text-xs"
      >
        install
        <span
          aria-hidden="true"
          className={`inline-block text-[9px] leading-none transition-transform duration-200 ${
            open ? 'rotate-180' : ''
          }`}
        >
          ▼
        </span>
      </button>

      {open && (
        <div
          id={panelId}
          className="install-pop depth-2 absolute right-0 top-[calc(100%+10px)] w-[268px] overflow-hidden rounded-xl border border-line bg-surface text-left"
        >
          <div className="px-4 pb-3 pt-3.5">
            <div className="font-display text-xl leading-none tracking-[0.01em] text-ink">
              UsageOwl {release.version}
            </div>
            <div className="label mt-2 text-dim">
              {MIN_MACOS} · Universal
            </div>
            <div className="label mt-1 text-dim">Apple Silicon &amp; Intel</div>
          </div>

          <div className="border-t border-line px-3 py-3">
            <a
              href={release.dmgUrl}
              download
              onClick={() => setOpen(false)}
              className="btn btn-green flex w-full items-center justify-center !py-2 !text-xs"
            >
              <DownloadGlyph className="h-3.5 w-3.5" />
              Download .dmg
              <span className="tnum opacity-70">{release.size}</span>
            </a>
            <p className="label mt-2.5 text-center text-dim">
              Signed &amp; notarized by Apple
            </p>
          </div>

          <a
            href={release.releaseUrl}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => setOpen(false)}
            className="block border-t border-line px-4 py-2.5 text-center font-mono text-[11px] text-dim transition-colors hover:bg-surface2 hover:text-ink"
          >
            Release notes ↗
          </a>
        </div>
      )}
    </div>
  );
}
