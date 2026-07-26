import Eyebrow from './Eyebrow';

const FEATURES = [
  { n: '01', word: 'Watch', sub: 'Every quota window. One ring in the menu bar.' },
  { n: '02', word: 'Warn', sub: '25 · 50 · 75 · 90 — alerted before the wall, not after.' },
  { n: '03', word: 'Reset', sub: 'Know the minute every window refreshes.' },
];

/**
 * Capabilities as static cards (the film's WATCH / WARN / RESET, at rest).
 */
export default function Features() {
  return (
    <section id="watch" aria-labelledby="ax-features" className="scroll-mt-24">
      <div className="mx-auto max-w-6xl px-5 py-24 sm:px-8">
        <Eyebrow n="02" label="capabilities" note="per provider · per window" />
        <div className="grid gap-4 md:grid-cols-3">
          {FEATURES.map((f) => (
            <div
              key={f.word}
              className="card-hover depth-2 rounded-2xl border border-line bg-surface px-6 py-6"
            >
              <div className="flex items-baseline justify-between">
                <span className="font-display text-5xl leading-none tracking-[0.01em] text-ink">
                  {f.word}
                </span>
                <span className="tnum font-mono text-[10px] text-dim">{f.n}</span>
              </div>
              <p className="label m-0 mt-5 text-fade">{f.sub}</p>
            </div>
          ))}
        </div>

        {/* the product in the wild */}
        <div className="mt-4 grid gap-4 lg:grid-cols-2">
          <figure className="depth-2 flex flex-col items-center justify-center gap-5 rounded-2xl border border-line bg-surface px-6 py-10">
            <img
              src="/images/menubar.png"
              alt="The macOS menu bar with UsageOwl's live readouts: Claude at 91% in amber, Kimi at 18%, Codex at 4%"
              width={454}
              height={54}
              className="h-auto w-[340px] max-w-full rounded-lg"
            />
            <figcaption className="label text-center text-dim">
              One ring in the menu bar — per provider, per window
            </figcaption>
          </figure>
          <figure className="depth-2 flex flex-col items-center justify-center gap-5 rounded-2xl border border-line bg-surface px-6 py-10">
            <img
              src="/images/notify.png"
              alt="A UsageOwl threshold notification: Claude 5-hour window at 91% — resets in 41 minutes"
              width={720}
              height={226}
              className="depth-1 h-auto w-full max-w-[360px] rounded-2xl"
            />
            <figcaption className="label text-center text-dim">
              Threshold alerts — 25 · 50 · 75 · 90, per window
            </figcaption>
          </figure>
        </div>
      </div>
    </section>
  );
}
