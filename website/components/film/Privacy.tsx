import Eyebrow from './Eyebrow';
import { PRIVACY_ROWS } from '../content';

/**
 * Privacy — three ruled statements with green edge marks.
 */
export default function Privacy() {
  return (
    <section id="privacy" aria-labelledby="ax-privacy" className="scroll-mt-24">
      <div className="mx-auto max-w-6xl px-5 py-24 sm:px-8">
        <Eyebrow n="03" label="privacy" note="credentials never leave the mac" />
        <div className="depth-1 rounded-2xl border border-line bg-surface px-6 py-3">
          {PRIVACY_ROWS.map((row, i) => (
            <div
              key={row}
              className={`flex items-baseline gap-5 border-l-2 border-green/40 py-4 pl-5 pr-2 ${
                i > 0 ? 'border-t border-line' : ''
              }`}
            >
              <span className="tnum font-mono text-[10px] text-dim">
                {String(i + 1).padStart(2, '0')}
              </span>
              <span className="font-display text-xl leading-tight tracking-[0.01em] text-ink sm:text-2xl">
                {row}
              </span>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
