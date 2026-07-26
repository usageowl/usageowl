import type { MetadataRoute } from 'next';

import { SITE_URL } from '../components/content';

/**
 * Statically exported to out/sitemap.xml by `output: 'export'`.
 *
 * The site is a single marketing page; /coffee/thanks is intentionally absent
 * (it is disallowed in robots.ts and carries `robots: { index: false }`).
 * lastModified is stamped at build time, which is the right semantics for a
 * static export — the deploy *is* the modification.
 */
// Required under `output: 'export'` — without it Next treats the `new Date()`
// below as a dynamic dependency and refuses to prerender the route.
export const dynamic = 'force-static';

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: SITE_URL,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 1,
    },
  ];
}
