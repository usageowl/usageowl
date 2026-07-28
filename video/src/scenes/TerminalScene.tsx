import { useCurrentFrame, interpolate, spring, useVideoConfig, AbsoluteFill } from 'remotion';
import { color, font, sec } from '../theme';

/**
 * 0:00–4.5 — the hook, rewritten.
 *
 * The first cut spent 6.5s here and argued with itself: the error printed
 * "resets in 41 minutes" while the caption claimed "You had no warning." The
 * frame WAS the warning, so the line contradicted the image.
 *
 * The real insight is that the warning arrives *at* the wall rather than
 * before it, which is also what the menu-bar scene then pays off. That is what
 * this scene now says, in 4.5s instead of 6.5:
 *
 *   0.0–1.1  command types out — live work, not a static list
 *   1.1–1.9  output lines rapid-fire
 *   1.9      the wall SLAMS in, everything above dims, cursor dies
 *   2.4–4.5  "Told at the wall. Not before it."
 */

const COMMAND = '$ claude "refactor the auth module"';

const OUTPUT: { text: string; color: string; at: number }[] = [
  { text: '  Editing src/auth/session.ts', color: color.tgreen, at: 1.15 },
  { text: '  Editing src/auth/tokens.ts', color: color.tgreen, at: 1.38 },
  { text: '  Editing src/auth/middleware.ts', color: color.tgreen, at: 1.61 },
];

const WALL_AT = 1.9;

export const TerminalScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const enter = interpolate(frame, [0, 10], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // Typewriter on the command only. A static line reads as a screenshot;
  // watching it type reads as someone actually working, which is what has to
  // be interrupted for the cut to land.
  const typed = Math.floor(
    interpolate(frame, [sec(0.2), sec(1.05)], [0, COMMAND.length], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    }),
  );

  const hit = frame >= sec(WALL_AT);

  // Punch: overshoot then settle. The one place in the video where motion is
  // violent, because it's the moment the work dies.
  const slam = spring({
    frame: frame - sec(WALL_AT),
    fps,
    config: { damping: 11, mass: 0.4, stiffness: 190 },
  });

  const cursorOn = !hit && frame > sec(0.2) && Math.floor(frame / 14) % 2 === 0;

  return (
    <AbsoluteFill
      style={{ backgroundColor: color.ink, justifyContent: 'center', alignItems: 'center' }}
    >
      <div
        style={{
          width: 1150,
          borderRadius: 16,
          overflow: 'hidden',
          backgroundColor: color.term,
          border: `1px solid ${color.tline}`,
          boxShadow: '0 60px 140px -40px rgba(0,0,0,0.75)',
          opacity: enter,
          transform: `translateY(${(1 - enter) * 18}px)`,
          // The whole window recoils a touch when the wall hits.
          filter: hit ? `brightness(${1 - 0.1 * (1 - Math.min(slam, 1))})` : 'none',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 9,
            padding: '15px 20px',
            borderBottom: `1px solid ${color.tline}`,
          }}
        >
          {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => (
            <div key={c} style={{ width: 13, height: 13, borderRadius: '50%', backgroundColor: c }} />
          ))}
          <div
            style={{
              flex: 1,
              textAlign: 'center',
              fontFamily: font.mono,
              fontSize: 15,
              color: color.tdim,
              marginRight: 48,
            }}
          >
            claude — 120×32
          </div>
        </div>

        <div
          style={{
            padding: '30px 34px 34px',
            fontFamily: font.mono,
            fontSize: 26,
            lineHeight: 1.8,
            // Once the wall hits, the work above is spent.
            filter: hit ? 'opacity(0.3)' : 'none',
          }}
        >
          <div style={{ color: color.tpaper }}>
            {COMMAND.slice(0, typed)}
            {!hit && typed < COMMAND.length ? '▋' : ''}
          </div>

          {OUTPUT.map((line) => (
            <div key={line.text} style={{ color: line.color, opacity: frame >= sec(line.at) ? 1 : 0 }}>
              {line.text}
            </div>
          ))}

          {!hit && <div style={{ color: color.tpaper, height: 47 }}>{cursorOn ? '▋' : ' '}</div>}
        </div>

        {/* the wall — full-width bar across the base of the window */}
        {hit && (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 16,
              padding: '22px 34px',
              backgroundColor: 'rgba(220,38,38,0.16)',
              borderTop: `1px solid rgba(220,38,38,0.55)`,
              transform: `scaleY(${Math.min(slam, 1.06)})`,
              transformOrigin: 'bottom',
            }}
          >
            <span style={{ color: color.red, fontSize: 30 }}>✕</span>
            <span style={{ color: '#FCA5A5', fontFamily: font.mono, fontSize: 27 }}>
              5-hour limit reached · resets in 41 minutes
            </span>
          </div>
        )}
      </div>

      {/*
        The payoff line. Deliberately NOT "you had no warning" — the bar above
        is a warning. The problem is when it arrives.
      */}
      <div
        style={{
          marginTop: 52,
          textAlign: 'center',
          opacity: interpolate(frame, [sec(2.4), sec(2.85)], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }),
          transform: `translateY(${interpolate(frame, [sec(2.4), sec(2.85)], [14, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          })}px)`,
        }}
      >
        <div
          style={{
            fontFamily: font.display,
            fontSize: 62,
            letterSpacing: '0.01em',
            textTransform: 'uppercase',
            color: color.tpaper,
            lineHeight: 1,
          }}
        >
          Told at the wall.
        </div>
        <div
          style={{
            marginTop: 10,
            fontFamily: font.display,
            fontSize: 62,
            letterSpacing: '0.01em',
            textTransform: 'uppercase',
            color: color.red,
            lineHeight: 1,
            opacity: interpolate(frame, [sec(2.9), sec(3.3)], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
          }}
        >
          Not before it.
        </div>
      </div>
    </AbsoluteFill>
  );
};
