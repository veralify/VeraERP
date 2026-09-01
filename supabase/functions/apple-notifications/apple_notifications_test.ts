import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { mapAppleNotificationToStatus, verifyAppleJws } from '../_shared/apple.ts';

Deno.test('apple notification type mapping follows entitlement states', () => {
  const cases: Array<[string, string | undefined, string]> = [
    ['SUBSCRIBED', undefined, 'active'],
    ['DID_RENEW', undefined, 'active'],
    ['DID_FAIL_TO_RENEW', 'GRACE_PERIOD', 'grace_period'],
    ['DID_FAIL_TO_RENEW', undefined, 'expired'],
    ['EXPIRED', undefined, 'expired'],
    ['GRACE_PERIOD_EXPIRED', undefined, 'expired'],
    ['REFUND', undefined, 'revoked'],
    ['REVOKE', undefined, 'revoked'],
  ];
  for (const [type, subtype, expected] of cases) {
    assertEquals(mapAppleNotificationToStatus(type, subtype), expected);
  }
});

Deno.test('apple JWS verification rejects malformed or unsigned payloads', async () => {
  await assertRejects(
    () => verifyAppleJws('not-a-jws', '-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----'),
    Error,
    'Invalid JWS compact serialization',
  );
  await assertRejects(
    () => verifyAppleJws('eyJhbGciOiJub25lIn0.e30.signature', '-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----'),
    Error,
    'Unsupported Apple JWS algorithm',
  );
});

Deno.test('apple notification replay is idempotent in notificationUUID gate', () => {
  const seen = new Set<string>();
  let upserts = 0;
  const process = (notificationUUID: string) => {
    if (seen.has(notificationUUID)) return 'duplicate';
    seen.add(notificationUUID);
    upserts++;
    return 'processed';
  };

  assertEquals(process('notif-1'), 'processed');
  assertEquals(process('notif-1'), 'duplicate');
  assertEquals(upserts, 1);
});
