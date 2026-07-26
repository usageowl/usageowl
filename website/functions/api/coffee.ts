/**
 * Cloudflare Pages Function — POST /api/coffee
 *
 * "Buy me a coffee" tip checkout. Anonymous one-time payment — no account,
 * no entitlement, nothing stored (the payment record lives in Stripe; this
 * repo has no backend by design). Runs on Cloudflare's edge via the fetch
 * API, so the Stripe client uses its fetch-based HTTP client.
 *
 * The amount is charged via price_data so presets AND custom amounts work
 * against a single Stripe product. Set STRIPE_COFFEE_PRODUCT_ID to the
 * product created by tools/create-coffee-product.mjs; without it we fall
 * back to inline product_data (a fresh product per session — fine for a
 * smoke test, clutter long-term).
 *
 * Env (Cloudflare Pages → Settings → Environment variables, or .dev.vars
 * locally):  STRIPE_SECRET_KEY, optional STRIPE_COFFEE_PRODUCT_ID
 */
import Stripe from 'stripe';
import { validateCoffeeAmountCents } from '../../lib/coffee';

interface Env {
  STRIPE_SECRET_KEY?: string;
  STRIPE_COFFEE_PRODUCT_ID?: string;
}

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

export async function onRequestPost(context: {
  request: Request;
  env: Env;
}): Promise<Response> {
  const { request, env } = context;

  if (!env.STRIPE_SECRET_KEY) {
    return json({ error: 'Payments are not configured yet.' }, 503);
  }

  let amountCents: unknown;
  try {
    ({ amountCents } = await request.json());
  } catch {
    return json({ error: 'Invalid request body.' }, 400);
  }

  const validation = validateCoffeeAmountCents(Number(amountCents));
  if (!validation.ok) {
    return json({ error: validation.reason }, 400);
  }

  // Workers have no Node runtime — the Stripe SDK must talk HTTPS via fetch.
  const stripe = new Stripe(env.STRIPE_SECRET_KEY, {
    httpClient: Stripe.createFetchHttpClient(),
  });

  const origin = new URL(request.url).origin;
  const productId = env.STRIPE_COFFEE_PRODUCT_ID;

  try {
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [
        {
          price_data: {
            currency: 'usd',
            unit_amount: Number(amountCents),
            ...(productId
              ? { product: productId }
              : {
                  product_data: {
                    name: 'Buy me a coffee — UsageOwl',
                    description: 'A one-time tip supporting UsageOwl.',
                  },
                }),
          },
          quantity: 1,
        },
      ],
      success_url: `${origin}/coffee/thanks`,
      cancel_url: `${origin}/`,
    });
    return json({ url: session.url });
  } catch (err) {
    console.error('coffee checkout failed', err);
    return json({ error: 'Could not start checkout. Please try again.' }, 502);
  }
}
