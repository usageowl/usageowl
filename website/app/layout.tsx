import type { Metadata, Viewport } from 'next';
import { Bangers, Poppins, IBM_Plex_Mono } from 'next/font/google';
import './globals.css';
import { SITE_URL } from '../components/content';

const display = Bangers({
  weight: '400',
  subsets: ['latin'],
  variable: '--font-display',
  display: 'swap',
});

const body = Poppins({
  weight: ['400', '500', '600', '700'],
  subsets: ['latin'],
  variable: '--font-body',
  display: 'swap',
});

const mono = IBM_Plex_Mono({
  weight: ['400', '500', '600'],
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
});

const title = 'UsageOwl — Every AI subscription. One menu bar.';
const description =
  'Free, open-source macOS menu bar app that tracks quota across Claude Code, Kimi Code, OpenAI Codex, GitHub Copilot and Moonshot — with threshold alerts and reset countdowns. No telemetry. MIT licensed.';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title,
  description,
  applicationName: 'UsageOwl',
  alternates: { canonical: '/' },
  keywords: [
    'Claude Code usage',
    'Kimi Code quota',
    'Codex quota tracker',
    'Copilot premium interactions',
    'Moonshot balance',
    'macOS menu bar app',
    'AI subscription tracker',
    'open source',
  ],
  openGraph: {
    type: 'website',
    url: SITE_URL,
    siteName: 'UsageOwl',
    title,
    description,
  },
  twitter: {
    card: 'summary_large_image',
    title,
    description,
  },
};

export const viewport: Viewport = {
  themeColor: '#08080A',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${body.variable} ${mono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
