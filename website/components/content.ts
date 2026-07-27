/** Canonical origin. Single source for metadataBase, sitemap and robots. */
export const SITE_URL = 'https://usageowl.com';

/** owner/repo — single source for the API lookups and every link below. */
export const GITHUB_REPO = 'usageowl/usageowl';

export const GITHUB_URL = `https://github.com/${GITHUB_REPO}`;

/** Minimum macOS, shown in the install dropdown. Mirrors LSMinimumSystemVersion
 *  in app/build_app.sh — if that changes, change this. */
export const MIN_MACOS = 'macOS 14+';

export const RELEASES_URL = `${GITHUB_URL}/releases`;
export const LATEST_RELEASE_URL = `${RELEASES_URL}/latest`;
export const ISSUES_URL = `${GITHUB_URL}/issues`;

export const SPEC_ROWS: Array<[string, string]> = [
  ['APP', 'USAGEOWL'],
  ['PRICE', 'FREE'],
  ['LICENSE', 'MIT'],
  ['SIZE', '4.8 MB'],
  ['SYSTEM', 'MACOS 14+'],
  ['PROVIDERS', '5'],
  ['TELEMETRY', 'NONE'],
  ['DISTRIBUTION', 'NOTARIZED DMG'],
];

export const PROVIDER_ROWS: Array<{ name: string; shows: string }> = [
  { name: 'Claude', shows: '5-hour + weekly windows, Fable limit, plan' },
  { name: 'Kimi Code', shows: 'weekly quota, 5-hour rate window' },
  { name: 'Codex', shows: 'primary/secondary windows, plan' },
  { name: 'GitHub Copilot', shows: 'premium interactions, reset date' },
  { name: 'Moonshot', shows: 'pay-as-you-go balance' },
];

export const PRIVACY_ROWS: string[] = [
  'No analytics, no telemetry',
  'No servers, only official provider APIs',
  'MIT licensed, every line public',
];

export const FAQ: Array<{ q: string; a: string }> = [
  {
    q: 'Where does it get my data?',
    a: 'From two places: the credential files your CLI tools (Claude Code, Kimi Code, Codex) already store on your Mac, and each provider’s official quota endpoint over HTTPS. Nothing is scraped, nothing is proxied.',
  },
  {
    q: 'Is my data safe?',
    a: 'Your credentials stay in the files and Keychain items where your tools put them. UsageOwl reads them locally and uses them only to ask the provider for your remaining quota. There is no UsageOwl backend — nothing is sent anywhere else.',
  },
  {
    q: 'Which providers are supported?',
    a: 'Claude (Claude Code and claude.ai), Kimi (Kimi Code), OpenAI Codex (ChatGPT Plus/Pro), GitHub Copilot premium interactions, and the Moonshot platform balance. Providers are plugins, so more can be added.',
  },
  {
    q: 'Does it work on Intel Macs?',
    a: 'Yes. It ships as a universal binary that runs natively on Apple Silicon and Intel, on macOS 14 Sonoma or later.',
  },
  {
    q: 'Why notarized instead of the App Store?',
    a: 'The App Store sandbox blocks apps from reading other tools’ credential files — which is exactly how auto-detect works. The DMG is signed with a Developer ID and notarized by Apple instead, so Gatekeeper still opens it cleanly.',
  },
  {
    q: 'How do I add Copilot?',
    a: 'Paste a GitHub personal access token once. UsageOwl stores it in the macOS Keychain and uses it only to read your premium-interactions quota.',
  },
];
