import Eyebrow from './Eyebrow';
import { GITHUB_URL, PROVIDER_ROWS } from '../content';

/**
 * Providers — one rounded card per provider, plus the plugin invite.
 */
export default function Providers() {
  return (
    <section id="providers" aria-labelledby="ax-providers" className="scroll-mt-24">
      <div className="mx-auto max-w-6xl px-5 py-24 sm:px-8">
        <Eyebrow n="01" label="providers" note="05 + yours" />
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {PROVIDER_ROWS.map((p, i) => (
            <div
              key={p.name}
              className="card-hover depth-2 rounded-2xl border border-line bg-surface px-6 py-5"
            >
              <div className="flex items-baseline justify-between">
                <span className="font-display text-2xl leading-none tracking-[0.01em] text-ink">
                  {p.name}
                </span>
                <span className="tnum font-mono text-[10px] text-dim">
                  {String(i + 1).padStart(2, '0')}
                </span>
              </div>
              <p className="m-0 mt-3 font-mono text-[11px] uppercase tracking-[0.1em] text-fade">
                {p.shows}
              </p>
            </div>
          ))}
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="card-hover group rounded-2xl border border-green/40 bg-green/[0.06] px-6 py-5"
          >
            <div className="flex items-baseline justify-between">
              <span className="font-display text-2xl leading-none tracking-[0.01em] text-green">
                Your provider here
              </span>
              <span
                className="text-green transition-transform duration-200 group-hover:-translate-y-0.5 group-hover:translate-x-0.5"
                aria-hidden="true"
              >
                ↗
              </span>
            </div>
            <p className="m-0 mt-3 font-mono text-[11px] uppercase tracking-[0.1em] text-fade">
              Providers are plugins — send a PR
            </p>
          </a>
        </div>
      </div>
    </section>
  );
}
