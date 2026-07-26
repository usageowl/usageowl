import { GITHUB_URL, ISSUES_URL, RELEASES_URL } from '../content';
import BuyCoffee from './BuyCoffee';

/**
 * Footer — wordmark, project links, grid floor, affiliation note.
 */
export default function Footer() {
  return (
    <footer className="relative overflow-hidden border-t border-line">
      <div
        className="pointer-events-none absolute inset-x-0 bottom-0 h-[70%] opacity-50"
        aria-hidden="true"
      >
        <div className="grid-floor absolute inset-0" />
      </div>
      <div className="relative mx-auto max-w-6xl px-5 py-14 sm:px-8">
        <div className="flex flex-col gap-8 sm:flex-row sm:items-start sm:justify-between">
          <span className="font-display text-3xl leading-none tracking-[0.01em] text-ink">
            usageowl
          </span>
          <div className="flex flex-col items-start gap-5 sm:items-end">
            <nav aria-label="Project" className="flex gap-8 font-mono text-xs text-fade">
              <a
                href={GITHUB_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="transition-colors duration-150 hover:text-green"
              >
                github
              </a>
              <a
                href={RELEASES_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="transition-colors duration-150 hover:text-green"
              >
                releases
              </a>
              <a
                href={ISSUES_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="transition-colors duration-150 hover:text-green"
              >
                issues
              </a>
            </nav>
            <BuyCoffee />
          </div>
        </div>
        <div className="mt-10 flex flex-col gap-2 border-t border-line pt-6 font-mono text-[11px] text-dim sm:flex-row sm:justify-between">
          <span>© UsageOwl · usageowl.com</span>
          <span>Not affiliated with Anthropic, Moonshot AI, OpenAI, or GitHub.</span>
        </div>

        {/* all glory to Him who sustains this work */}
        <div className="mt-12 border-t border-line pt-8 text-center">
          <p className="mx-auto max-w-2xl font-mono text-[12.5px] leading-relaxed text-fade">
            <span aria-hidden className="text-green">
              ✝
            </span>{' '}
            &ldquo;For God so loved the world, that he gave his only begotten Son, that
            whosoever believeth in Him should not perish, but have everlasting life.&rdquo;
            <span className="mt-1.5 block text-[11px] uppercase tracking-wide text-dim">
              John 3:16
            </span>
          </p>
        </div>

        <div className="mt-10 flex justify-center border-t border-line pt-6 font-mono text-[11px] text-dim">
          <span className="flex items-center gap-2">
            Built by
            <img
              src="/images/anestis.jpg"
              alt="Anestis Finstad"
              width={20}
              height={20}
              className="inline-block h-5 w-5 rounded-full object-cover ring-1 ring-line"
            />
            <a
              href="https://x.com/JSDevlife"
              target="_blank"
              rel="noopener noreferrer"
              className="font-medium text-fade underline underline-offset-2 hover:text-ink"
            >
              Anestis Finstad
            </a>
            with usageowl
          </span>
        </div>
      </div>
    </footer>
  );
}
