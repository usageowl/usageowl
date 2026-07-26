'use client';

import { useEffect, useId, useState } from 'react';
import {
  COFFEE_PRESET_AMOUNTS_CENTS,
  COFFEE_DEFAULT_AMOUNT_CENTS,
  COFFEE_MIN_CENTS,
  COFFEE_MAX_CENTS,
  validateCoffeeAmountCents,
} from '@/lib/coffee';

function formatAmount(cents: number): string {
  return `$${(cents / 100).toFixed(cents % 100 === 0 ? 0 : 2)}`;
}

function CoffeeGlyph({ className }: { className?: string }) {
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
      <path d="M17 8h1a3 3 0 1 1 0 6h-1" />
      <path d="M3 8h14v6a5 5 0 0 1-5 5H8a5 5 0 0 1-5-5V8z" />
      <line x1="6" y1="2" x2="6" y2="4" />
      <line x1="10" y1="2" x2="10" y2="4" />
      <line x1="14" y1="2" x2="14" y2="4" />
    </svg>
  );
}

/**
 * "Buy me a coffee" tip jar. Opens a dialog with preset amounts ($5 default)
 * plus a custom amount, then hands off to Stripe Checkout via /api/coffee.
 * Anonymous — no account, nothing tracked.
 *
 * `variant` styles the trigger only; the dialog is identical either way.
 * - 'footer' — full-size button with the complete label.
 * - 'nav'    — compact, matched to the install button's metrics, with the
 *              label dropped below `sm` so the glyph alone carries it on
 *              phones where the nav band has no room for two labelled CTAs.
 *
 * Each instance owns its own dialog state, so the title id is scoped with
 * useId rather than hardcoded — two instances mount on the page at once.
 */
export default function BuyCoffee({ variant = 'footer' }: { variant?: 'footer' | 'nav' }) {
  const titleId = useId();
  const [open, setOpen] = useState(false);
  const [selected, setSelected] = useState<number | 'custom'>(COFFEE_DEFAULT_AMOUNT_CENTS);
  const [customDollars, setCustomDollars] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const amountCents =
    selected === 'custom' ? Math.round(Number(customDollars) * 100) : selected;

  // Esc closes the dialog.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open]);

  async function startCheckout() {
    setError(null);
    const validation = validateCoffeeAmountCents(amountCents);
    if (!validation.ok) {
      setError(
        selected === 'custom'
          ? `Enter an amount between $${COFFEE_MIN_CENTS / 100} and $${COFFEE_MAX_CENTS / 100}.`
          : validation.reason,
      );
      return;
    }
    setLoading(true);
    try {
      const res = await fetch('/api/coffee', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ amountCents }),
      });
      const data = (await res.json()) as { url?: string; error?: string };
      if (!res.ok || !data.url) {
        setError(data.error ?? 'Could not start checkout. Please try again.');
        setLoading(false);
        return;
      }
      window.location.assign(data.url);
    } catch {
      setError('Network error. Please try again.');
      setLoading(false);
    }
  }

  return (
    <>
      {variant === 'nav' ? (
        <button
          type="button"
          className="btn btn-owl !px-3.5 !py-1.5 !text-xs"
          onClick={() => setOpen(true)}
        >
          <CoffeeGlyph className="h-3.5 w-3.5" />
          <span className="hidden sm:inline">coffee</span>
          <span className="sr-only sm:hidden">Buy me a coffee</span>
        </button>
      ) : (
        <button type="button" className="btn btn-owl" onClick={() => setOpen(true)}>
          <CoffeeGlyph className="h-4 w-4" />
          Buy me a coffee
        </button>
      )}

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-ink/30 p-4"
          onClick={() => setOpen(false)}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            className="depth-2 w-full max-w-sm rounded-2xl border border-line bg-surface p-6"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 id={titleId} className="font-display text-2xl leading-none text-ink">
                  Buy me a coffee
                </h2>
                <p className="mt-2 text-sm leading-relaxed text-fade">
                  UsageOwl is free and MIT-licensed. A coffee keeps it that way —
                  one-time, no account needed.
                </p>
              </div>
              <button
                type="button"
                aria-label="Close"
                onClick={() => setOpen(false)}
                className="rounded-md px-2 py-1 font-mono text-sm text-dim transition-colors hover:bg-surface2 hover:text-ink"
              >
                ✕
              </button>
            </div>

            <div
              className="mt-5 grid grid-cols-4 gap-2"
              role="radiogroup"
              aria-label="Tip amount"
            >
              {COFFEE_PRESET_AMOUNTS_CENTS.map((cents) => (
                <button
                  key={cents}
                  type="button"
                  role="radio"
                  aria-checked={selected === cents}
                  onClick={() => setSelected(cents)}
                  className={`h-10 rounded-lg border font-mono text-sm font-semibold transition-colors ${
                    selected === cents
                      ? 'border-green bg-green text-white'
                      : 'border-line2 bg-surface text-ink hover:border-dim'
                  }`}
                >
                  {formatAmount(cents)}
                </button>
              ))}
            </div>

            <div className="relative mt-3">
              <span
                aria-hidden="true"
                className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 font-mono text-sm text-dim"
              >
                $
              </span>
              <input
                type="number"
                inputMode="decimal"
                min={COFFEE_MIN_CENTS / 100}
                max={COFFEE_MAX_CENTS / 100}
                step="1"
                placeholder="Custom amount"
                aria-label="Custom amount in dollars"
                value={customDollars}
                onFocus={() => setSelected('custom')}
                onChange={(e) => {
                  setCustomDollars(e.target.value);
                  setSelected('custom');
                }}
                className={`h-10 w-full rounded-lg border bg-surface pl-7 pr-3 font-mono text-sm text-ink outline-none transition-colors placeholder:text-dim focus:border-green ${
                  selected === 'custom' ? 'border-green' : 'border-line2'
                }`}
              />
            </div>

            {error && (
              <p role="alert" className="mt-3 font-mono text-xs text-red-600">
                {error}
              </p>
            )}

            <button
              type="button"
              className="btn btn-green mt-5 w-full justify-center"
              onClick={startCheckout}
              disabled={loading}
            >
              {loading
                ? 'Redirecting…'
                : Number.isFinite(amountCents) && amountCents > 0
                  ? `Tip ${formatAmount(amountCents)} with Stripe`
                  : 'Tip with Stripe'}
            </button>
            <p className="mt-3 text-center font-mono text-[11px] text-dim">
              Secure checkout by Stripe · one-time payment
            </p>
          </div>
        </div>
      )}
    </>
  );
}
