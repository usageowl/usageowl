import { useCurrentFrame, interpolate, spring, useVideoConfig, AbsoluteFill } from 'remotion';
import { color, font, sec } from '../theme';

/**
 * 0:06.5–0:09.5 — the relief.
 *
 * Cut from the dark terminal straight to a bright desktop: the same 91% that
 * just killed the session was sitting in the menu bar the whole time.
 *
 * The bar is rebuilt in CSS rather than scaled up from public/menubar.png —
 * that asset is 454x54, and stretching it across a 1920 frame would be visibly
 * soft in the one shot that has to read as a crisp native macOS UI.
 */

const OwlMark: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 64 64">
    <path d="M15 9 L26 19 L15 21 Z" fill={color.ink} />
    <path d="M49 9 L38 19 L49 21 Z" fill={color.ink} />
    <circle cx="32" cy="36" r="21" stroke={color.ink} strokeWidth="3.5" fill="none" />
    <circle cx="24" cy="33" r="7" fill={color.ink} />
    <circle cx="40" cy="33" r="7" fill={color.ink} />
    <circle cx="24" cy="33" r="2.8" fill={color.bg} />
    <circle cx="40" cy="33" r="2.8" fill={color.bg} />
    <path d="M32 41 L28.5 46.5 L35.5 46.5 Z" fill={color.ink} />
  </svg>
);

const WifiIcon: React.FC = () => (
  <svg width="26" height="20" viewBox="0 0 26 20" fill="none">
    <path d="M2 6.5a17 17 0 0 1 22 0" stroke={color.ink} strokeWidth="2.2" strokeLinecap="round" />
    <path d="M6.5 11a11 11 0 0 1 13 0" stroke={color.ink} strokeWidth="2.2" strokeLinecap="round" />
    <circle cx="13" cy="16" r="2.2" fill={color.ink} />
  </svg>
);

const BatteryIcon: React.FC = () => (
  <svg width="34" height="18" viewBox="0 0 34 18" fill="none">
    <rect x="1" y="1" width="28" height="16" rx="5" stroke={color.ink} strokeWidth="1.8" opacity="0.55" />
    <rect x="3.5" y="3.5" width="23" height="11" rx="3" fill={color.ink} />
    <path d="M31.5 6.5v5a2.6 2.6 0 0 0 0-5Z" fill={color.ink} opacity="0.55" />
  </svg>
);

export const MenuBarScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Scale the whole bar up so a 24px-tall macOS UI is legible at 1080p
  // without pretending to be full-screen.
  const rise = spring({ frame, fps, config: { damping: 200, mass: 0.6 } });

  // The amber readout pulses once, right as the eye lands on it.
  const pulse = interpolate(frame, [sec(0.9), sec(1.25), sec(1.6)], [1, 1.12, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        background: `linear-gradient(160deg, ${color.bg} 0%, #E7EDFA 100%)`,
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          transform: `scale(${0.96 + rise * 0.04})`,
          opacity: rise,
          width: 1400,
          borderRadius: 18,
          overflow: 'hidden',
          border: `1px solid ${color.line}`,
          boxShadow: '0 50px 120px -40px rgba(30,58,138,0.35)',
        }}
      >
        {/* the macOS menu bar itself */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'flex-end',
            gap: 34,
            height: 74,
            padding: '0 34px',
            backgroundColor: 'rgba(255,255,255,0.82)',
            backdropFilter: 'blur(20px)',
            borderBottom: `1px solid ${color.line}`,
            fontFamily: font.body,
            fontSize: 24,
            color: color.ink,
          }}
        >
          {/* UsageOwl's own item, scaled up under the pulse */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              transform: `scale(${pulse})`,
              transformOrigin: 'center',
            }}
          >
            <OwlMark size={30} />
            <span
              style={{
                fontFamily: font.mono,
                fontWeight: 600,
                fontSize: 26,
                color: color.owl,
                fontVariantNumeric: 'tabular-nums',
              }}
            >
              91%
            </span>
          </div>

          {/* Drawn, not typed. SF Symbols live in a private-use Unicode range
              that Chromium cannot resolve, so the glyph characters rendered as
              tofu blocks in the first pass. */}
          <WifiIcon />
          <BatteryIcon />
          <span style={{ fontSize: 23, color: color.ink, fontVariantNumeric: 'tabular-nums' }}>
            Tue 19:24
          </span>
        </div>

        {/*
          A sliver of desktop so the bar reads as attached to a machine rather
          than floating. The amber wash sits directly under the owl item to
          pull the eye to the 91% — in the first pass this was a flat blue
          rectangle and the readout got lost against it.
        */}
        <div
          style={{
            position: 'relative',
            height: 190,
            background: `linear-gradient(180deg, #DCE5F7 0%, #BFCFEC 100%)`,
          }}
        >
          <div
            style={{
              position: 'absolute',
              inset: 0,
              background: `radial-gradient(circle at 74% -10%, rgba(240,180,41,${0.5 * rise}) 0%, transparent 46%)`,
            }}
          />
        </div>
      </div>

      <div
        style={{
          marginTop: 56,
          fontFamily: font.mono,
          fontSize: 23,
          letterSpacing: '0.16em',
          textTransform: 'uppercase',
          color: color.fade,
          opacity: interpolate(frame, [sec(1.5), sec(2.0)], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }),
        }}
      >
        It was there the whole time.
      </div>
    </AbsoluteFill>
  );
};
