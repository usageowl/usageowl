import { useCurrentFrame, interpolate, spring, useVideoConfig, AbsoluteFill } from 'remotion';
import { color, font, sec } from '../theme';

/**
 * 0:17–0:21 — the turn.
 *
 * The site's own climax line, on the site's own amber. Someone who has seen
 * usageowl.com should feel the callback; someone who hasn't still gets the
 * thesis in four words. Amber full-bleed is the loudest frame in the video,
 * which is why it sits here and nowhere else.
 */
export const StatementScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const line1 = spring({ frame, fps, config: { damping: 200, mass: 0.55 } });
  const line2 = spring({ frame: frame - 9, fps, config: { damping: 200, mass: 0.55 } });

  // The amber floods in from the left rather than cutting, so the jump from
  // the light popup scene reads as a wipe instead of a flash.
  const flood = interpolate(frame, [0, 12], [0, 100], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{ backgroundColor: color.bg }}>
      <AbsoluteFill
        style={{
          backgroundColor: color.owl,
          clipPath: `polygon(0 0, ${flood}% 0, ${flood}% 100%, 0 100%)`,
        }}
      />

      <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center' }}>
        <div style={{ textAlign: 'center' }}>
          <div
            style={{
              fontFamily: font.display,
              fontSize: 158,
              lineHeight: 0.9,
              letterSpacing: '0.01em',
              textTransform: 'uppercase',
              color: color.ink,
              opacity: line1,
              transform: `translateY(${(1 - line1) * 34}px)`,
            }}
          >
            Stop guessing.
          </div>
          <div
            style={{
              fontFamily: font.display,
              fontSize: 158,
              lineHeight: 0.9,
              letterSpacing: '0.01em',
              textTransform: 'uppercase',
              color: color.ink,
              opacity: line2,
              transform: `translateY(${(1 - line2) * 34}px)`,
            }}
          >
            Start watching.
          </div>

          <div
            style={{
              marginTop: 46,
              fontFamily: font.mono,
              fontSize: 24,
              letterSpacing: '0.2em',
              textTransform: 'uppercase',
              color: 'rgba(17,24,39,0.65)',
              opacity: interpolate(frame, [sec(1.6), sec(2.1)], [0, 1], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              }),
            }}
          >
            Alerts at 25 · 50 · 75 · 90%
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
