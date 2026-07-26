import { useId } from 'react';

/**
 * Rounds a tick coordinate to 3dp before it reaches the DOM.
 *
 * Math.sin/Math.cos are not required by the ECMAScript spec to be
 * bit-identical across engines, and Node's V8 and the browser's disagree in
 * the last ULP (…82.69837232100535 server vs …82.69837232100537 client).
 * React compares the two as strings during hydration and reports a mismatch
 * it explicitly will not patch up. 3dp is far below one device pixel on a
 * 100-unit viewBox, so the geometry is unchanged.
 */
const coord = (n: number) => Math.round(n * 1000) / 1000;

/**
 * The O: ring gauge geometry reused across every scene.
 * All strokes use currentColor except the active arc (owl amber by default).
 * Arc uses pathLength=100 so `progress` maps directly to a percent.
 */
export default function GaugeRing({
  className = '',
  progress = 62,
  ticks = 60,
  tickEvery = 1,
  strokeWidth = 7,
  showTicks = true,
  arc = true,
  arcColor = '#16A34A',
  trackOpacity = 0.16,
  tickOpacity = 0.28,
}: {
  className?: string;
  progress?: number;
  ticks?: number;
  tickEvery?: number;
  strokeWidth?: number;
  showTicks?: boolean;
  arc?: boolean;
  arcColor?: string;
  trackOpacity?: number;
  tickOpacity?: number;
}) {
  const id = useId();
  const r = 50 - strokeWidth / 2;
  const tickR1 = r - strokeWidth / 2 - 6;
  const tickR2 = r - strokeWidth / 2 - 2;
  const lines = [];
  if (showTicks) {
    for (let i = 0; i < ticks; i += tickEvery) {
      const a = (i / ticks) * Math.PI * 2 - Math.PI / 2;
      const major = i % 5 === 0;
      lines.push(
        <line
          key={i}
          x1={coord(50 + Math.cos(a) * (major ? tickR1 - 2 : tickR1))}
          y1={coord(50 + Math.sin(a) * (major ? tickR1 - 2 : tickR1))}
          x2={coord(50 + Math.cos(a) * tickR2)}
          y2={coord(50 + Math.sin(a) * tickR2)}
          stroke="currentColor"
          strokeWidth={major ? 1 : 0.5}
          opacity={tickOpacity}
        />,
      );
    }
  }
  return (
    <svg viewBox="0 0 100 100" className={className} aria-hidden="true" data-ring={id}>
      <circle
        cx="50"
        cy="50"
        r={r}
        fill="none"
        stroke="currentColor"
        strokeWidth={strokeWidth}
        opacity={trackOpacity}
        data-ring-track
      />
      {arc && (
        <circle
          cx="50"
          cy="50"
          r={r}
          fill="none"
          stroke={arcColor}
          strokeWidth={strokeWidth}
          pathLength={100}
          strokeDasharray={100}
          strokeDashoffset={100 - progress}
          transform="rotate(-90 50 50)"
          data-ring-arc
        />
      )}
      {showTicks && <g data-ring-ticks>{lines}</g>}
    </svg>
  );
}
