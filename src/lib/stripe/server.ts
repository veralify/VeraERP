import Stripe from 'stripe';

let client: Stripe | null = null;

/**
 * Lazily create the Stripe client on first use so importing this module
 * (e.g. during `next build` page-data collection) never throws when the
 * secret key is only present at runtime. The env check runs when a request
 * actually needs Stripe.
 */
export function getStripe(): Stripe {
  if (client) return client;

  const secretKey = process.env.STRIPE_SECRET_KEY;
  if (!secretKey) {
    throw new Error('Missing STRIPE_SECRET_KEY environment variable.');
  }

  client = new Stripe(secretKey, {
    typescript: true,
  });
  return client;
}
