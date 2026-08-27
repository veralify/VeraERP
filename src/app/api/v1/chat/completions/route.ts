import { apiLogger } from '@lib/logger';
import { NextResponse } from 'next/server';

type ChatMessage = { role?: string; content?: string | null };
type ChatCompletionRequest = { model?: string; messages?: ChatMessage[]; stream?: boolean };

const nowUnix = () => Math.floor(Date.now() / 1000);
const randomId = () => `chatcmpl_${Math.random().toString(36).slice(2, 10)}`;

const latestUserText = (messages: ChatMessage[]) => {
  for (let index = messages.length - 1; index >= 0; index -= 1) {
    const message = messages[index];
    if (message?.role === 'user' && typeof message.content === 'string') return message.content;
  }
  return '';
};

const fitnessReply = (text: string) => {
  const lower = text.toLowerCase();
  if (lower.includes('meal') || lower.includes('food') || lower.includes('nutrition')) {
    return 'Veralify can help you log meals, review AI-suggested nutrition, and turn confirmed entries into daily insights.';
  }
  if (lower.includes('group') || lower.includes('community')) {
    return 'Veralify communities are designed for goal-aligned accountability, progress sharing, and support.';
  }
  if (lower.includes('live') || lower.includes('coach')) {
    return 'Veralify Pro includes live rooms and coach discovery so members can add real-time and human accountability.';
  }
  return 'Welcome to Veralify. Track meals and progress, let AI summarize patterns, then connect with communities, live rooms, and coaches for accountability.';
};

export async function POST(request: Request) {
  const log = apiLogger('/api/v1/chat/completions', request);
  const body = (await request.json().catch(() => null)) as ChatCompletionRequest | null;

  if (!body || !Array.isArray(body.messages)) {
    log.done(400);
    return NextResponse.json({ error: { message: 'messages must be an array' } }, { status: 400 });
  }

  const id = randomId();
  const model = body.model ?? 'veralify-fitness-foundation';
  const content = fitnessReply(latestUserText(body.messages));

  if (body.stream) {
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      start(controller) {
        controller.enqueue(
          encoder.encode(
            `data: ${JSON.stringify({ id, object: 'chat.completion.chunk', created: nowUnix(), model, choices: [{ index: 0, delta: { role: 'assistant', content }, finish_reason: null }] })}\n\n`,
          ),
        );
        controller.enqueue(
          encoder.encode(
            `data: ${JSON.stringify({ id, object: 'chat.completion.chunk', created: nowUnix(), model, choices: [{ index: 0, delta: {}, finish_reason: 'stop' }] })}\n\n`,
          ),
        );
        controller.enqueue(encoder.encode('data: [DONE]\n\n'));
        controller.close();
      },
    });
    log.done(200);
    return new Response(stream, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache, no-transform',
        Connection: 'keep-alive',
      },
    });
  }

  log.done(200);
  return NextResponse.json({
    id,
    object: 'chat.completion',
    created: nowUnix(),
    model,
    choices: [{ index: 0, message: { role: 'assistant', content }, finish_reason: 'stop' }],
  });
}
