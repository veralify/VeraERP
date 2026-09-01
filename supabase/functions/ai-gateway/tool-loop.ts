// @ts-nocheck
import { logToolCall } from './logging.ts';
import { executeTool } from './tools.ts';
import { type AiMessage, type SupabaseLike } from './types.ts';

export async function runToolLoop(input: {
  rawMessage: unknown;
  messages: AiMessage[];
  supabase: SupabaseLike;
  userId: string;
  requestId: string;
  aiRequestId?: string | null;
}) {
  const msg = (input.rawMessage as any)?.choices?.[0]?.message;
  const calls = Array.isArray(msg?.tool_calls) ? msg.tool_calls : [];
  const messages = [...input.messages];
  if (!calls.length) return { messages, toolResults: [] };
  messages.push({ role: 'assistant', content: msg?.content ?? '', tool_calls: calls } as any);
  const toolResults = [];
  for (const call of calls) {
    const name = call?.function?.name;
    let args: Record<string, unknown> = {};
    try { args = JSON.parse(call?.function?.arguments || '{}'); } catch { args = {}; }
    let result: unknown;
    let success = true;
    try { result = await executeTool(name, args, { userId: input.userId, supabase: input.supabase, requestId: input.requestId }); }
    catch (e) { success = false; result = { error: { code: e?.code ?? 'TOOL_ERROR', message: e instanceof Error ? e.message : String(e) } }; }
    await logToolCall(input.supabase, { aiRequestId: input.aiRequestId, toolName: name, arguments: args, result, success });
    toolResults.push({ name, args, result, success });
    messages.push({ role: 'tool', tool_call_id: call.id, name, content: JSON.stringify(result) });
  }
  return { messages, toolResults };
}
