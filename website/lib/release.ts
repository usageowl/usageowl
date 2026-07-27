import { GITHUB_REPO, LATEST_RELEASE_URL } from '../components/content';

export interface ReleaseInfo {
  /** Marketing version, no leading v — "1.0.0". */
  version: string;
  /** Direct link to the .dmg. GitHub serves it with
   *  `content-disposition: attachment`, so a plain <a> downloads it
   *  immediately rather than navigating anywhere. */
  dmgUrl: string;
  /** Human-readable asset size, e.g. "1.3 MB". */
  size: string;
  /** The release page, for anyone who wants the notes or an older build. */
  releaseUrl: string;
  /** False when the network lookup failed and the fallback below is in use. */
  live: boolean;
}

/**
 * Used when the build machine can't reach GitHub (offline, rate-limited, CI
 * without egress). Keeping a real value here means the download button always
 * works — a stale-but-valid link beats a broken build or an empty dropdown.
 * Bump alongside the release tag.
 */
const FALLBACK: ReleaseInfo = {
  version: '1.0.0',
  dmgUrl: `https://github.com/${GITHUB_REPO}/releases/download/v1.0.0/UsageOwl-1.0.0.dmg`,
  size: '1.3 MB',
  releaseUrl: LATEST_RELEASE_URL,
  live: false,
};

interface GitHubAsset {
  name: string;
  size: number;
  browser_download_url: string;
}

/**
 * Read the latest release at **build time**.
 *
 * `output: 'export'` means this runs once during `npm run build` and the result
 * is baked into the HTML — no client-side request, no loading state, and no
 * third version number to keep in sync by hand. Ship a release, rebuild, and
 * the site follows automatically.
 */
export async function getLatestRelease(): Promise<ReleaseInfo> {
  try {
    const res = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/releases/latest`, {
      headers: { Accept: 'application/vnd.github+json' },
    });
    if (!res.ok) return FALLBACK;

    const data = (await res.json()) as {
      tag_name?: string;
      html_url?: string;
      assets?: GitHubAsset[];
    };

    const dmg = data.assets?.find((a) => a.name.endsWith('.dmg'));
    if (!data.tag_name || !dmg) return FALLBACK;

    return {
      version: data.tag_name.replace(/^v/, ''),
      dmgUrl: dmg.browser_download_url,
      size: `${(dmg.size / 1_048_576).toFixed(1)} MB`,
      releaseUrl: data.html_url ?? LATEST_RELEASE_URL,
      live: true,
    };
  } catch {
    return FALLBACK;
  }
}
