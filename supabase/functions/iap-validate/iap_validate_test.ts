import { assertEquals, assertRejects, assertThrows } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { assertAppAccountTokenMatches, transactionStatus, verifyAppleJws } from '../_shared/apple.ts';

Deno.test('iap validate rejects appAccountToken mismatch', async () => {
  assertThrows(
    () => assertAppAccountTokenMatches('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002'),
    Error,
    'appAccountToken does not match authenticated user',
  );
});

Deno.test('iap validate accepts matching appAccountToken case-insensitively', () => {
  assertEquals(
    assertAppAccountTokenMatches('AAAAAAAA-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001'),
    undefined,
  );
});

Deno.test('iap validate maps transaction expiry and revocation to entitlement status', () => {
  assertEquals(transactionStatus({ expiresDate: Date.now() + 60_000 }), 'active');
  assertEquals(transactionStatus({ expiresDate: Date.now() - 60_000 }), 'expired');
  assertEquals(transactionStatus({ expiresDate: Date.now() + 60_000, revocationDate: Date.now() }), 'revoked');
});

Deno.test('iap validate rejects malformed signed transaction JWS', async () => {
  await assertRejects(
    () => verifyAppleJws('bad.payload.signature', '-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----'),
    Error,
  );
});
