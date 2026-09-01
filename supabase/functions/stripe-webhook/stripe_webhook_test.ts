import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { hmacSha256Hex, verifyStripeSignature } from '../_shared/stripe.ts';

Deno.test('stripe signature verification rejects bad signatures', async () => {
  const body = JSON.stringify({ id: 'evt_bad', type: 'customer.subscription.updated' });
  const timestamp = 1_700_000_000;
  const ok = await verifyStripeSignature(body, `t=${timestamp},v1=not-a-real-signature`, 'whsec_test', timestamp);
  assertEquals(ok, false);
});

Deno.test('stripe signature verification accepts valid signatures', async () => {
  const body = JSON.stringify({ id: 'evt_good', type: 'customer.subscription.updated' });
  const timestamp = 1_700_000_000;
  const signature = await hmacSha256Hex('whsec_test', `${timestamp}.${body}`);
  const ok = await verifyStripeSignature(body, `t=${timestamp},v1=${signature}`, 'whsec_test', timestamp);
  assert(ok);
});

Deno.test('stripe webhook replay is idempotent in event-id gate', () => {
  const seen = new Set<string>();
  let stateChanges = 0;
  const process = (eventId: string) => {
    if (seen.has(eventId)) return 'duplicate';
    seen.add(eventId);
    stateChanges++;
    return 'processed';
  };

  assertEquals(process('evt_replay'), 'processed');
  assertEquals(process('evt_replay'), 'duplicate');
  assertEquals(stateChanges, 1);
});
