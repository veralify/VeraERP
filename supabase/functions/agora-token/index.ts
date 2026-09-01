// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';
import { corsHeaders, json, requireEnv } from '../_shared/http.ts';
import { agoraUidForUserId, buildAgoraRtcToken, isModeratorParticipant, resolveAgoraRole } from '../_shared/agora.ts';

const serviceClient = () => createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false, autoRefreshToken: false } });
const userClient = (auth: string) => createClient(requireEnv('SUPABASE_URL'), Deno.env.get('SUPABASE_ANON_KEY') || requireEnv('SUPABASE_SERVICE_ROLE_KEY'), { global: { headers: { Authorization: auth } }, auth: { persistSession: false, autoRefreshToken: false } });

async function caller(req: Request) {
  const auth = req.headers.get('authorization') ?? '';
  if (!auth.startsWith('Bearer ')) throw new Response(JSON.stringify({ error: 'Authentication required.' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  const { data, error } = await userClient(auth).auth.getUser();
  if (error || !data.user) throw new Response(JSON.stringify({ error: 'Invalid session.' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  return data.user;
}

async function getRoom(supabase: any, roomId: string) {
  const { data, error } = await supabase.from('live_rooms').select('id, group_id, host_id, coach_session_id, room_type, status, agora_channel').eq('id', roomId).maybeSingle();
  if (error) throw error;
  if (!data) throw new Error('Room not found');
  return data;
}

async function isBanned(supabase: any, roomId: string, userId: string) {
  const { data } = await supabase.from('room_banned_users').select('room_id').eq('room_id', roomId).eq('user_id', userId).maybeSingle();
  return Boolean(data);
}

async function canJoinRoom(supabase: any, room: any, userId: string) {
  if (room.host_id === userId || room.room_type === 'public') return true;
  if (room.room_type === 'group' && room.group_id) {
    const { data } = await supabase.from('group_members').select('user_id').eq('group_id', room.group_id).eq('user_id', userId).eq('status', 'active').maybeSingle();
    return Boolean(data);
  }
  if (room.room_type === 'coach_client' && room.coach_session_id) {
    const { data } = await supabase.from('coach_sessions').select('id').eq('id', room.coach_session_id).or(`coach_id.eq.${userId},client_id.eq.${userId}`).maybeSingle();
    return Boolean(data);
  }
  return false;
}

async function getParticipant(supabase: any, roomId: string, userId: string) {
  const { data, error } = await supabase.from('live_room_participants').select('room_id, user_id, role, speak_state, left_at').eq('room_id', roomId).eq('user_id', userId).maybeSingle();
  if (error) throw error;
  return data;
}

async function ensureParticipant(supabase: any, room: any, userId: string) {
  let participant = await getParticipant(supabase, room.id, userId);
  if (participant && !participant.left_at) return participant;
  const isHost = room.host_id === userId;
  const row = { room_id: room.id, user_id: userId, role: isHost ? 'host' : 'listener', speak_state: isHost ? 'speaking' : 'listener', joined_at: new Date().toISOString(), left_at: null };
  const { error } = await supabase.from('live_room_participants').upsert(row, { onConflict: 'room_id,user_id' });
  if (error) throw error;
  await supabase.from('live_room_events').insert({ room_id: room.id, user_id: userId, event_type: 'joined', metadata: { role: row.role } });
  return await getParticipant(supabase, room.id, userId);
}

async function requireModerator(supabase: any, roomId: string, userId: string) {
  const participant = await getParticipant(supabase, roomId, userId);
  if (!isModeratorParticipant(participant)) throw new Error('Moderator privileges required');
  return participant;
}

async function tokenAction(supabase: any, userId: string, body: any) {
  const room = await getRoom(supabase, String(body.room_id));
  if (await isBanned(supabase, room.id, userId)) return json({ error: 'User is banned from this room.' }, 403);
  if (!(await canJoinRoom(supabase, room, userId))) return json({ error: 'Not authorized for this room.' }, 403);
  const participant = await ensureParticipant(supabase, room, userId);
  let role;
  try {
    role = resolveAgoraRole(body.requested_role, participant);
  } catch (error) {
    return json({ error: error.message }, 403);
  }
  const expireAt = Math.floor(Date.now() / 1000) + Number(body.ttl_seconds ?? 3600);
  const uid = agoraUidForUserId(userId);
  const token = await buildAgoraRtcToken({ appId: requireEnv('AGORA_APP_ID'), appCertificate: requireEnv('AGORA_APP_CERTIFICATE'), channelName: room.agora_channel, uid, role, expireAt });
  await supabase.from('live_room_events').insert({ room_id: room.id, user_id: userId, event_type: 'token_issued', metadata: { role, uid, expireAt } });
  return json({ channel: room.agora_channel, uid, token, expiration: expireAt, role });
}

async function requestToSpeak(supabase: any, userId: string, body: any) {
  const room = await getRoom(supabase, String(body.room_id));
  if (await isBanned(supabase, room.id, userId)) return json({ error: 'User is banned from this room.' }, 403);
  if (!(await canJoinRoom(supabase, room, userId))) return json({ error: 'Not authorized for this room.' }, 403);
  await ensureParticipant(supabase, room, userId);
  const { error } = await supabase.from('live_room_participants').update({ speak_state: 'request_to_speak', role: 'listener', hand_raised_at: new Date().toISOString() }).eq('room_id', room.id).eq('user_id', userId);
  if (error) throw error;
  await supabase.from('live_room_events').insert({ room_id: room.id, user_id: userId, event_type: 'request_to_speak', metadata: {} });
  return json({ ok: true });
}

async function approveSpeaker(supabase: any, moderatorId: string, body: any) {
  const roomId = String(body.room_id);
  const target = String(body.target_user_id);
  await requireModerator(supabase, roomId, moderatorId);
  const participant = await getParticipant(supabase, roomId, target);
  if (!participant || participant.speak_state !== 'request_to_speak') return json({ error: 'Target has not requested to speak.' }, 409);
  await supabase.from('live_room_participants').update({ role: 'speaker', speak_state: 'approved_speaker', hand_raised_at: null }).eq('room_id', roomId).eq('user_id', target);
  await supabase.from('room_moderation_events').insert({ room_id: roomId, moderator_id: moderatorId, target_user_id: target, action: 'approve_speaker', metadata: {} });
  await supabase.from('live_room_events').insert({ room_id: roomId, user_id: target, event_type: 'speaker_approved', metadata: { moderator_id: moderatorId } });
  return json({ ok: true });
}

async function demoteToListener(supabase: any, moderatorId: string, body: any) {
  const roomId = String(body.room_id);
  const target = String(body.target_user_id);
  await requireModerator(supabase, roomId, moderatorId);
  await supabase.from('live_room_participants').update({ role: 'listener', speak_state: 'listener', hand_raised_at: null }).eq('room_id', roomId).eq('user_id', target);
  await supabase.from('room_moderation_events').insert({ room_id: roomId, moderator_id: moderatorId, target_user_id: target, action: 'revoke_speaker', metadata: {} });
  await supabase.from('live_room_events').insert({ room_id: roomId, user_id: target, event_type: 'demoted_to_listener', metadata: { moderator_id: moderatorId } });
  return json({ ok: true });
}

async function banUser(supabase: any, moderatorId: string, body: any) {
  const roomId = String(body.room_id);
  const target = String(body.target_user_id);
  await requireModerator(supabase, roomId, moderatorId);
  if (target === moderatorId) return json({ error: 'Cannot ban yourself.' }, 400);
  await supabase.from('room_banned_users').upsert({ room_id: roomId, user_id: target, banned_by: moderatorId, reason: body.reason ?? null }, { onConflict: 'room_id,user_id' });
  await supabase.from('live_room_participants').update({ left_at: new Date().toISOString(), role: 'listener', speak_state: 'listener' }).eq('room_id', roomId).eq('user_id', target);
  await supabase.from('room_moderation_events').insert({ room_id: roomId, moderator_id: moderatorId, target_user_id: target, action: 'ban', metadata: { reason: body.reason ?? null } });
  await supabase.from('live_room_events').insert({ room_id: roomId, user_id: target, event_type: 'banned', metadata: { moderator_id: moderatorId, reason: body.reason ?? null } });
  return json({ ok: true });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);
  try {
    const user = await caller(req);
    const body = await req.json();
    const supabase = serviceClient();
    switch (body.action ?? 'token') {
      case 'token': return await tokenAction(supabase, user.id, body);
      case 'request-to-speak': return await requestToSpeak(supabase, user.id, body);
      case 'approve-speaker': return await approveSpeaker(supabase, user.id, body);
      case 'demote-to-listener': return await demoteToListener(supabase, user.id, body);
      case 'ban-user': return await banUser(supabase, user.id, body);
      default: return json({ error: 'Unknown action.' }, 400);
    }
  } catch (error) {
    if (error instanceof Response) return error;
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message.includes('AGORA_APP')) return json({ error: 'NOT_CONFIGURED', message }, 503);
    return json({ error: message }, 500);
  }
});
