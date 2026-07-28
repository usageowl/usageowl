import type { Metadata, Viewport } from 'next';
import Script from 'next/script';
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
      <body>
        {children}
        {/*
          DataFast — site analytics. In the root layout so it loads on every
          route. This measures the marketing site only; the app itself still
          ships no analytics and no telemetry, which is what the Privacy
          section and the README are claiming.
        */}
        <Script
          src="https://datafa.st/js/script.js"
          data-website-id="dfid_BMX73NM35pYcva7hZiZIw"
          data-domain="usageowl.com"
          strategy="afterInteractive"
        />
      </body>
    </html>
  );
}
