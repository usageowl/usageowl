#!/usr/bin/env node
/**
 * Creates (or finds) the "Buy me a coffee" product in the configured Stripe
 * account and prints its product id for STRIPE_COFFEE_PRODUCT_ID.
 *
 * Idempotent: looks up an existing product tagged metadata usageowl_coffee=1
 * before creating a new one. Create-only — never modifies or deletes
 * pre-existing Stripe objects.
 *
 * Run:  node --env-file=.env.local tools/create-coffee-product.mjs
 */
import Stripe from 'stripe';

const key = process.env.STRIPE_SECRET_KEY;
if (!key) {
  console.error('STRIPE_SECRET_KEY is not set (check .env.local).');
  process.exit(1);
}

const stripe = new Stripe(key);

const existing = await stripe.products.search({
  query: 'metadata["usageowl_coffee"]:"1"',
  limit: 1,
});

const product =
  existing.data[0] ??
  (await stripe.products.create({
    name: 'Buy me a coffee — UsageOwl',
    description: 'A one-time tip supporting UsageOwl (usageowl.com).',
    metadata: { usageowl_coffee: '1' },
  }));

console.log(`${existing.data[0] ? 'Found' : 'Created'} product: ${product.id}`);
console.log('\nAdd to .env.local and your host env:');
console.log(`STRIPE_COFFEE_PRODUCT_ID=${product.id}`);
