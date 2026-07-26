import type { Config } from 'tailwindcss';

export default {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: '#F6F8FE',
        surface: '#FFFFFF',
        surface2: '#EEF2FB',
        ink: '#111827',
        fade: '#4B5563',
        dim: '#5F6774',
        line: '#E3E8F4',
        line2: '#D6DEEF',
        green: '#16A34A',
        greenbright: '#15803D',
        term: '#0C111B',
        tline: '#222D42',
        tpaper: '#E9EEFB',
        tfade: '#9FB0CF',
        tdim: '#5F7191',
        tgreen: '#34D399',
        owl: '#F0B429',
        owlbright: '#D99B16',
      },
      fontFamily: {
        sans: ['var(--font-body)', 'system-ui', 'sans-serif'],
        display: ['var(--font-display)', 'system-ui', 'sans-serif'],
        mono: ['var(--font-mono)', 'ui-monospace', 'monospace'],
      },
    },
  },
  plugins: [],
} satisfies Config;
