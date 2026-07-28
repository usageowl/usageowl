/**
 * Brand tokens, lifted verbatim from website/tailwind.config.ts and
 * app/globals.css. Someone who just saw usageowl.com should recognise this
 * video as the same product without being told — that only holds if the
 * values match exactly rather than approximately.
 */
export const color = {
  bg: '#F6F8FE',
  surface: '#FFFFFF',
  ink: '#111827',
  fade: '#4B5563',
  dim: '#5F6774',
  line: '#E3E8F4',
  green: '#16A34A',
  owl: '#F0B429',
  red: '#DC2626',

  // terminal palette
  term: '#0C111B',
  tline: '#222D42',
  tpaper: '#E9EEFB',
  tfade: '#9FB0CF',
  tdim: '#5F7191',
  tgreen: '#34D399',
} as const;

export const font = {
  display: '"Bangers", system-ui, sans-serif',
  body: '"Poppins", system-ui, sans-serif',
  mono: '"IBM Plex Mono", ui-monospace, monospace',
} as const;

/** 30fps throughout — seconds * FPS is the only timing arithmetic in the video. */
export const FPS = 30;
export const sec = (s: number) => Math.round(s * FPS);

/**
 * Scene boundaries in seconds. Keeping every cut in one table means the
 * timeline can be re-paced here without hunting through five components, and
 * makes it obvious at a glance that the durations sum to 25s.
 */
export const beats = {
  terminal: { from: 0, duration: 6.5 },
  menubar: { from: 6.5, duration: 3 },
  popup: { from: 9.5, duration: 7.5 },
  statement: { from: 17, duration: 4 },
  end: { from: 21, duration: 4 },
} as const;

export const TOTAL_SECONDS = 25;

/** Matches --ease-out on the site: cubic-bezier(0.2, 0.7, 0.2, 1). */
export const EASE_OUT = [0.2, 0.7, 0.2, 1] as const;
