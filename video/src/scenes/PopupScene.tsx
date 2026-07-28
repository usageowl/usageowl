import {
  useCurrentFrame,
  interpolate,
  spring,
  useVideoConfig,
  AbsoluteFill,
  Img,
  staticFile,
} from 'remotion';
import { color, font, sec } from '../theme';

/**
 * 0:09.5–0:17 — the proof.
 *
 * The real popup, then the claim it supports: every provider, one place.
 * popup.png is used as-is (680x1902 shown at ~880px tall, so it downscales
 * and stays sharp) rather than rebuilt — this is the shot where a viewer
 * decides whether the product is real, and a mock-up would undercut that.
 */

// Retimed for a 5.5s scene (was 7.5s). The five land in 1.8s rather than 3s —
// fast enough to read as a list, not a queue.
const CALLOUTS: { label: string; detail: string; at: number }[] = [
  { label: 'Claude', detail: '5-hour · weekly · spend', at: 0.75 },
  { label: 'Kimi', detail: 'weekly quota · rate window', at: 1.1 },
  { label: 'Codex', detail: 'primary · secondary', at: 1.45 },
  { label: 'Copilot', detail: 'premium interactions', at: 1.8 },
  { label: 'Moonshot', detail: 'pay-as-you-go balance', at: 2.15 },
];

export const PopupScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const rise = spring({ frame, fps, config: { damping: 200, mass: 0.8 } });

  // A small drift so 7.5s on this shot doesn't go dead. Deliberately gentle:
  // the popup is 940px tall in a 1080 frame, and the first pass used 1180px
  // with a -120px drift, which cropped the header and the footer clean off.
  // Whatever the drift is, height + |drift| must stay under 1080.
  const drift = interpolate(frame, [0, sec(5.5)], [0, -40], {
    extrapolateRight: 'clamp',
  });

  const notifyIn = spring({
    frame: frame - sec(2.9),
    fps,
    config: { damping: 200, mass: 0.7 },
  });

  return (
    <AbsoluteFill
      style={{
        background: `linear-gradient(160deg, ${color.bg} 0%, #E7EDFA 100%)`,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 90,
      }}
    >
      {/* left: the claim, built line by line */}
      <div style={{ width: 620 }}>
        <div
          style={{
            fontFamily: font.mono,
            fontSize: 21,
            letterSpacing: '0.16em',
            textTransform: 'uppercase',
            color: color.green,
            opacity: interpolate(frame, [sec(0.4), sec(0.9)], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
          }}
        >
          Every AI subscription
        </div>

        <div style={{ marginTop: 34, display: 'flex', flexDirection: 'column', gap: 20 }}>
          {CALLOUTS.map((c) => {
            const p = interpolate(frame, [sec(c.at), sec(c.at + 0.42)], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            });
            return (
              <div
                key={c.label}
                style={{
                  display: 'flex',
                  alignItems: 'baseline',
                  gap: 18,
                  opacity: p,
                  transform: `translateX(${(1 - p) * -26}px)`,
                }}
              >
                <div
                  style={{
                    width: 11,
                    height: 11,
                    borderRadius: '50%',
                    backgroundColor: color.green,
                    flexShrink: 0,
                    transform: 'translateY(-3px)',
                  }}
                />
                <div
                  style={{
                    fontFamily: font.display,
                    fontSize: 46,
                    lineHeight: 1,
                    letterSpacing: '0.01em',
                    textTransform: 'uppercase',
                    color: color.ink,
                    minWidth: 210,
                  }}
                >
                  {c.label}
                </div>
                <div style={{ fontFamily: font.mono, fontSize: 20, color: color.dim }}>
                  {c.detail}
                </div>
              </div>
            );
          })}
        </div>

        {/* the real threshold notification, landing late as the payoff */}
        <div
          style={{
            marginTop: 52,
            opacity: notifyIn,
            transform: `translateY(${(1 - notifyIn) * 22}px)`,
          }}
        >
          <Img
            src={staticFile('notify.png')}
            style={{
              width: 560,
              height: 'auto',
              borderRadius: 14,
              filter: 'drop-shadow(0 26px 60px rgba(30,58,138,0.28))',
            }}
          />
        </div>
      </div>

      {/* right: the product */}
      <div
        style={{
          opacity: rise,
          transform: `translateY(${(1 - rise) * 60 + drift}px)`,
        }}
      >
        <Img
          src={staticFile('popup.png')}
          style={{
            height: 940,
            width: 'auto',
            borderRadius: 22,
            filter: 'drop-shadow(0 50px 120px rgba(17,24,39,0.45))',
          }}
        />
      </div>
    </AbsoluteFill>
  );
};
