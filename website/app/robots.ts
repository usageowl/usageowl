import type { MetadataRoute } from 'next';

import { SITE_URL } from '../components/content';

/**
 * Statically exported to out/robots.txt by `output: 'export'`.
 *
 * Everything is crawlable except /coffee/thanks — that page is only ever
 * reached by returning from a Stripe checkout, so indexing it would surface a
 * "thanks for the coffee" page to people who never bought one. AI crawlers are
 * listed explicitly rather than left to the wildcard: this is an open-source
 * tool that benefits from being cited in AI answers, and naming them documents
 * that the allow is deliberate rather than an oversight.
 */
// Pinned for parity with sitemap.ts under `output: 'export'`.
export const dynamic = 'force-static';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: '/coffee/thanks',
      },
      {
        userAgent: ['GPTBot', 'ClaudeBot', 'PerplexityBot', 'Google-Extended', 'OAI-SearchBot'],
        allow: '/',
        disallow: '/coffee/thanks',
      },
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL,
  };
}
