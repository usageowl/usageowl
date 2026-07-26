/**
 * Spinyield-style numbered section eyebrow.
 */
export default function Eyebrow({ n, label, note }: { n: string; label: string; note?: string }) {
  return (
    <div className="mb-8 flex items-baseline justify-between">
      <p className="m-0 font-mono text-xs font-medium text-green">
        <span className="text-dim">[{n}]</span> {label}
      </p>
      {note ? <span className="label text-dim">{note}</span> : null}
    </div>
  );
}
