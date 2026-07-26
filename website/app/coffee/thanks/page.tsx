import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Thanks for the coffee — UsageOwl',
  description: 'Thanks for supporting UsageOwl with a coffee.',
  robots: { index: false, follow: false },
};

export default function CoffeeThanksPage() {
  return (
    <main className="flex min-h-screen items-center justify-center px-5 py-24">
      <div className="w-full max-w-md text-center">
        <div
          className="depth-1 mx-auto flex h-16 w-16 items-center justify-center rounded-2xl border border-line bg-surface"
          aria-hidden="true"
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className="h-7 w-7 text-green"
          >
            <path d="M17 8h1a3 3 0 1 1 0 6h-1" />
            <path d="M3 8h14v6a5 5 0 0 1-5 5H8a5 5 0 0 1-5-5V8z" />
            <line x1="6" y1="2" x2="6" y2="4" />
            <line x1="10" y1="2" x2="10" y2="4" />
            <line x1="14" y1="2" x2="14" y2="4" />
          </svg>
        </div>
        <h1 className="mt-6 font-display text-4xl leading-none text-ink">
          Thanks for the coffee!
        </h1>
        <p className="mt-3 text-sm leading-relaxed text-fade">
          Your tip keeps UsageOwl free and open-source. It genuinely funds the
          next provider integration — thank you.
        </p>
        <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
          <Link href="/" className="btn btn-green">
            Back to usageowl.com
          </Link>
          <a
            href="https://github.com/usageowl/usageowl"
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-ghost"
          >
            Star on GitHub
          </a>
        </div>
      </div>
    </main>
  );
}
