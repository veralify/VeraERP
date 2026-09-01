import { assertEquals, assertThrows } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { agoraUidForUserId, buildAgoraRtcToken, isModeratorParticipant, resolveAgoraRole } from '../_shared/agora.ts';

Deno.test('agora token builder is deterministic for fixed inputs', async () => {
  const token = await buildAgoraRtcToken({
    appId: '00112233445566778899aabbccddeeff',
    appCertificate: 'ffeeddccbbaa99887766554433221100',
    channelName: 'vr_live_01JXYZ',
    uid: 12345,
    role: 'speaker',
    expireAt: 1_700_003_600,
    issuedAt: 1_700_000_000,
    salt: 42,
  });
  assertEquals(token, '00600112233445566778899aabbccddeeffFADnDKniLpFrgSuntkLR1rgv4If4GyAkuAAcOvXLHAAqAAAAAPFTZQMAAQAQ/1NlAgAQ/1NlAwAQ/1Nl');
});

Deno.test('requested speaker without approved state is rejected', () => {
  assertThrows(
    () => resolveAgoraRole('speaker', { role: 'listener', speak_state: 'request_to_speak' }),
    Error,
    'Speaker role requires server-approved speaker state',
  );
});

Deno.test('approved speaker receives speaker token role', () => {
  assertEquals(resolveAgoraRole('speaker', { role: 'speaker', speak_state: 'approved_speaker' }), 'speaker');
  assertEquals(resolveAgoraRole('listener', { role: 'speaker', speak_state: 'approved_speaker' }), 'listener');
});

Deno.test('moderator helper requires host/moderator with speaking privilege state', () => {
  assertEquals(isModeratorParticipant({ role: 'moderator', speak_state: 'speaking' }), true);
  assertEquals(isModeratorParticipant({ role: 'moderator', speak_state: 'listener' }), false);
  assertEquals(isModeratorParticipant({ role: 'speaker', speak_state: 'speaking' }), false);
});

Deno.test('agora uid is stable and numeric', () => {
  assertEquals(agoraUidForUserId('user-1'), agoraUidForUserId('user-1'));
});
