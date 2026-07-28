import { useCurrentFrame, interpolate, spring, useVideoConfig, AbsoluteFill } from 'remotion';
import { color, font, sec } from '../theme';

/**
 * 0:21–0:25 — the ask.
 *
 * One URL, and the three facts that remove every reason to hesitate: it's
 * free, it's open, it sends nothing anywhere. The frame holds still for the
 * last second so a viewer can actually read and remember the domain — the
 * most common end-card mistake is animating right up to the cut.
 */

const FACTS = ['Free forever', 'MIT licensed', 'No telemetry'];

const OwlMark: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 64 64">
    <rect width="64" height="64" rx="14" fill={color.owl} />
    <path d="M15 9 L26 19 L15 21 Z" fill={color.term} />
    <path d="M49 9 L38 19 L49 21 Z" fill={color.term} />
    <circle cx="32" cy="36" r="21" stroke={color.term} strokeWidth="3.5" fill="none" />
    <circle cx="24" cy="33" r="7" fill={color.term} />
    <circle cx="40" cy="33" r="7" fill={color.term} />
    <circle cx="24" cy="33" r="2.8" fill={color.owl} />
    <circle cx="40" cy="33" r="2.8" fill={color.owl} />
    <path d="M32 41 L28.5 46.5 L35.5 46.5 Z" fill={color.term} />
  </svg>
);

export const EndCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const mark = spring({ frame, fps, config: { damping: 200, mass: 0.7 } });
  const word = spring({ frame: frame - 6, fps, config: { damping: 200, mass: 0.7 } });
  const url = spring({ frame: frame - 16, fps, config: { damping: 200, mass: 0.7 } });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: color.term,
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      {/* the same faint grid the README header uses */}
      <AbsoluteFill
        style={{
          backgroundImage: `linear-gradient(rgba(59,130,246,0.06) 1px, transparent 1px),
                            linear-gradient(90deg, rgba(59,130,246,0.06) 1px, transparent 1px)`,
          backgroundSize: '64px 64px',
        }}
      />
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at 50% 42%, rgba(240,180,41,0.16) 0%, transparent 58%)`,
        }}
      />

      <div style={{ position: 'relative', textAlign: 'center' }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 26,
            opacity: mark,
            transform: `scale(${0.9 + mark * 0.1})`,
          }}
        >
          <OwlMark size={96} />
          <div
            style={{
              fontFamily: font.display,
              fontSize: 128,
              lineHeight: 0.86,
              letterSpacing: '0.02em',
              textTransform: 'uppercase',
              color: color.owl,
              opacity: word,
              transform: `translateX(${(1 - word) * -22}px)`,
            }}
          >
            UsageOwl
          </div>
        </div>

        <div
          style={{
            marginTop: 40,
            fontFamily: font.body,
            fontWeight: 600,
            fontSize: 40,
            color: color.tpaper,
            opacity: interpolate(frame, [sec(0.5), sec(1.0)], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
          }}
        >
          Every AI subscription. One menu bar.
        </div>

        <div
          style={{
            marginTop: 52,
            fontFamily: font.mono,
            fontWeight: 600,
            fontSize: 54,
            letterSpacing: '0.02em',
            color: color.tgreen,
            opacity: url,
            transform: `translateY(${(1 - url) * 18}px)`,
          }}
        >
          usageowl.com
        </div>

        <div
          style={{
            marginTop: 44,
            display: 'flex',
            justifyContent: 'center',
            gap: 22,
            opacity: interpolate(frame, [sec(1.5), sec(2.0)], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
          }}
        >
          {FACTS.map((f) => (
            <div
              key={f}
              style={{
                padding: '13px 26px',
                borderRadius: 9,
                border: `1px solid ${color.tline}`,
                backgroundColor: 'rgba(233,238,251,0.04)',
                fontFamily: font.mono,
                fontSize: 21,
                letterSpacing: '0.13em',
                textTransform: 'uppercase',
                color: color.tfade,
              }}
            >
              {f}
            </div>
          ))}
        </div>

        <div
          style={{
            marginTop: 40,
            fontFamily: font.mono,
            fontSize: 19,
            letterSpacing: '0.14em',
            textTransform: 'uppercase',
            color: color.tdim,
            opacity: interpolate(frame, [sec(2.0), sec(2.5)], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
          }}
        >
          macOS 14+ · Universal · Signed &amp; notarized
        </div>
      </div>
    </AbsoluteFill>
  );
};
