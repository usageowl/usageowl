import { ImageResponse } from 'next/og';

export const dynamic = 'force-static';
export const alt = 'UsageOwl — Every AI subscription. One menu bar.';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

export default function OpengraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: 80,
          background: '#F6F8FE',
          fontFamily: 'sans-serif',
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <div
            style={{
              fontSize: 24,
              letterSpacing: 6,
              color: '#16A34A',
              textTransform: 'uppercase',
              marginBottom: 28,
            }}
          >
            Free &amp; open source — MIT
          </div>
          <div
            style={{
              fontSize: 118,
              fontWeight: 800,
              color: '#111827',
              letterSpacing: -4,
              lineHeight: 0.95,
              textTransform: 'uppercase',
            }}
          >
            UsageOwl
          </div>
          <div style={{ fontSize: 34, marginTop: 32, color: '#4B5563' }}>
            Every AI subscription. One menu bar.
          </div>
          <div
            style={{
              display: 'flex',
              marginTop: 56,
              fontSize: 22,
              letterSpacing: 3,
              color: '#16A34A',
              textTransform: 'uppercase',
            }}
          >
            Claude · Kimi · Codex · Copilot · Moonshot
          </div>
        </div>
        {/* the O — ring gauge */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            width: 320,
            height: 320,
            borderRadius: 9999,
            border: '26px solid #16A34A',
            marginRight: 24,
          }}
        >
          <div style={{ width: 56, height: 56, borderRadius: 9999, background: '#16A34A' }} />
        </div>
      </div>
    ),
    size,
  );
}
