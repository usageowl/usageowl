/**
 * Cloudflare Pages Function — root middleware, runs on every request.
 *
 * DataFast "Bot traffic" tracking. The browser script in app/layout.tsx only
 * sees visitors that run JavaScript; AI crawlers (ChatGPT-User, ClaudeBot,
 * PerplexityBot, GPTBot, Googlebot…) generally do not, so they have to be
 * counted server-side. This site is a static export, so Pages middleware is
 * the only server-side hook available — hence a root _middleware.ts rather
 * than the Next.js proxy.ts shown in DataFast's docs.
 *
 * We track on the way *out* (trackAICrawlerResponse) rather than on the way
 * in, so the real status code is reported and a crawler hitting a dead URL
 * shows up as the 404 it was. The call is fire-and-forget: it hands its work
 * to waitUntil() and never blocks the response.
 *
 * Env (optional, Cloudflare Pages → Settings → Environment variables):
 *   DATAFAST_BOT_TOKEN — website-specific Bot traffic token (dfbot_…), which
 *   stops anyone else from posting crawl events against our website ID.
 */
import { trackAICrawlerResponse } from '@datafast/ai-crawl';

// Same website as the analytics script in app/layout.tsx.
const DATAFAST_WEBSITE_ID = 'dfid_BMX73NM35pYcva7hZiZIw';
const SITE_DOMAIN = 'usageowl.com';

interface Env {
  DATAFAST_BOT_TOKEN?: string;
}

export async function onRequest(context: {
  request: Request;
  env: Env;
  next: () => Promise<Response>;
  waitUntil: (promise: Promise<unknown>) => void;
}): Promise<Response> {
  const { request, env } = context;
  const response = await context.next();

  // Preview deployments answer on *.pages.dev; crawls of those are not
  // usageowl.com traffic and would skew the numbers.
  const { hostname } = new URL(request.url);
  if (hostname === SITE_DOMAIN || hostname === `www.${SITE_DOMAIN}`) {
    try {
      // Not awaited by design — the library filters non-crawler traffic
      // synchronously and defers the network call to waitUntil().
      trackAICrawlerResponse(request, response, context, {
        websiteId: DATAFAST_WEBSITE_ID,
        domain: SITE_DOMAIN,
        authToken: env.DATAFAST_BOT_TOKEN,
        // The library defaults to a 1500ms timeout, but measured round trips to
        // /api/ai-crawls run 2.7-14s (slow server side, not the network), so the
        // default aborts and drops the event. Nothing waits on this call, so a
        // longer ceiling costs the visitor nothing.
        timeoutMs: 10_000,
      });
    } catch {
      // Analytics must never take the site down.
    }
  }

  return response;
}
