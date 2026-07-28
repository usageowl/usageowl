import { useCurrentFrame, interpolate, AbsoluteFill } from 'remotion';
import { color, font, sec } from '../theme';

/**
 * 0:00–0:06.5 — the hook.
 *
 * A Claude Code session doing real work, then the rate limit. The error lands
 * at ~3.2s and then NOTHING moves for over a second. That hold is the whole
 * point of the scene: it's the feeling of being stopped mid-thought, and any
 * motion during it would undercut the thing the product exists to prevent.
 */

const LINES: { text: string; color: string; at: number }[] = [
  { text: '$ claude "refactor the auth module"', color: color.tpaper, at: 0.35 },
  { text: '  Reading src/auth/session.ts…', color: color.tdim, at: 1.15 },
  { text: '  Reading src/auth/tokens.ts…', color: color.tdim, at: 1.6 },
  { text: '  Editing src/auth/session.ts', color: color.tgreen, at: 2.1 },
  { text: '  Editing src/auth/middleware.ts', color: color.tgreen, at: 2.55 },
];

const ERROR_AT = 3.2;

export const TerminalScene: React.FC = () => {
  const frame = useCurrentFrame();

  // The window settles in over the first ~18 frames, then holds perfectly
  // still — a drifting window would fight the freeze later in the scene.
  const enter = interpolate(frame, [0, 18], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const errorShown = frame >= sec(ERROR_AT);

  // Cursor blinks while working, then stops dead when the error lands. A
  // blinking cursor after the failure would read as "still alive".
  const cursorOn = !errorShown && Math.floor(frame / 16) % 2 === 0;

  return (
    <AbsoluteFill style={{ backgroundColor: color.ink, justifyContent: 'center', alignItems: 'center' }}>
      <div
        style={{
          width: 1180,
          borderRadius: 16,
          overflow: 'hidden',
          backgroundColor: color.term,
          border: `1px solid ${color.tline}`,
          boxShadow: '0 60px 140px -40px rgba(0,0,0,0.75)',
          opacity: enter,
          transform: `translateY(${(1 - enter) * 26}px)`,
        }}
      >
        {/* title bar */}
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

        <div style={{ padding: '30px 34px 38px', fontFamily: font.mono, fontSize: 25, lineHeight: 1.85 }}>
          {LINES.map((line) => {
            const visible = frame >= sec(line.at);
            return (
              <div
                key={line.text}
                style={{
                  color: line.color,
                  opacity: visible ? 1 : 0,
                  // Dim the work once it's been cut off — the session is over.
                  filter: errorShown ? 'opacity(0.42)' : 'none',
                  transition: 'none',
                }}
              >
                {line.text}
              </div>
            );
          })}

          {errorShown ? (
            <div style={{ marginTop: 26 }}>
              <div
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 14,
                  padding: '14px 22px',
                  borderRadius: 10,
                  backgroundColor: 'rgba(220,38,38,0.14)',
                  border: `1px solid rgba(220,38,38,0.5)`,
                  // Snap in at full size. A spring here would feel playful,
                  // and nothing about hitting a rate limit is playful.
                  opacity: interpolate(frame, [sec(ERROR_AT), sec(ERROR_AT) + 3], [0, 1], {
                    extrapolateLeft: 'clamp',
                    extrapolateRight: 'clamp',
                  }),
                }}
              >
                <span style={{ color: color.red, fontSize: 27 }}>✕</span>
                <span style={{ color: '#FCA5A5', fontSize: 25 }}>
                  5-hour limit reached · resets in 41 minutes
                </span>
              </div>
            </div>
          ) : (
            <div style={{ color: color.tpaper, height: 46, fontSize: 25 }}>
              {cursorOn ? '▋' : ' '}
            </div>
          )}
        </div>
      </div>

      {/* The line only appears during the dead air, so the silence has a caption. */}
      <div
        style={{
          marginTop: 44,
          fontFamily: font.mono,
          fontSize: 21,
          letterSpacing: '0.16em',
          textTransform: 'uppercase',
          color: color.tdim,
          opacity: interpolate(frame, [sec(4.5), sec(5.1)], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }),
        }}
      >
        You had no warning.
      </div>
    </AbsoluteFill>
  );
};
