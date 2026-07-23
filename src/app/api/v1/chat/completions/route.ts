import type { ApiLogger } from '@lib/logger';
import { apiLogger } from '@lib/logger';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import type { User } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';

type ChatToolCall = {
  id?: string;
  type?: 'function';
  function?: {
    name?: string;
    arguments?: string;
  };
  index?: number;
};

type ChatMessage = {
  role?: string;
  content?: string | null;
  tool_calls?: ChatToolCall[];
  tool_call_id?: string;
};

type ChatCompletionRequest = {
  model?: string;
  messages?: ChatMessage[];
};

const headers = {
  'Content-Type': 'text/event-stream',
  'Cache-Control': 'no-cache, no-transform',
  Connection: 'keep-alive',
};

type ProfileRow = {
  id: string;
  email: string | null;
  subscription_tier: string | null;
  monthly_ai_credits: number | null;
};

const nowUnix = () => Math.floor(Date.now() / 1000);
const randomId = (prefix: string) => `${prefix}_${Math.random().toString(36).slice(2, 10)}`;

const openAIErrorResponse = (
  status: number,
  message: string,
  type: 'invalid_request_error' | 'authentication_error' | 'server_error',
  code: string,
) =>
  NextResponse.json(
    {
      error: {
        message,
        type,
        code,
      },
    },
    { status },
  );

const extractBearerToken = (authorizationHeader: string | null): string | null => {
  if (!authorizationHeader) return null;

  const [scheme, token] = authorizationHeader.split(' ');
  if (!scheme || scheme.toLowerCase() !== 'bearer') return null;

  const trimmedToken = token?.trim();
  return trimmedToken ? trimmedToken : null;
};

const toNumberOr = (value: unknown, fallback: number): number =>
  typeof value === 'number' && Number.isFinite(value) ? value : fallback;

const extractLatestUserText = (messages: ChatMessage[]): string => {
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    const message = messages[i];
    if (message?.role === 'user' && typeof message.content === 'string') {
      return message.content;
    }
  }
  return '';
};

const hasToolResultMessage = (messages: ChatMessage[]) =>
  messages.some((message) => message.role === 'tool');

const detectIntent = (text: string): 'flight' | 'esim' | 'general' => {
  const lower = text.toLowerCase();

  const flightKeywords = [
    'flight',
    'flights',
    'book',
    'booking',
    'ticket',
    'airline',
    'departure',
    'arrival',
    'رحلة',
    'رحلات',
    'طيران',
    'حجز',
  ];
  if (flightKeywords.some((keyword) => lower.includes(keyword))) {
    return 'flight';
  }

  const esimKeywords = [
    'esim',
    'data',
    'roaming',
    'sim',
    'gigabyte',
    'gb',
    'شريحة',
    'بيانات',
    'انترنت',
    'تجوال',
  ];
  if (esimKeywords.some((keyword) => lower.includes(keyword))) {
    return 'esim';
  }

  return 'general';
};

const extractDate = (text: string) => {
  const match = text.match(/\b\d{4}-\d{2}-\d{2}\b/);
  return match?.[0] ?? '2026-08-15';
};

const extractDestination = (text: string) => {
  const match = text.match(/\bto\s+([A-Za-z]{3}|[A-Za-z\s]{3,30})/i);
  if (match?.[1]) {
    return match[1].trim().split(/\s+/).slice(0, 2).join(' ').toUpperCase();
  }

  const arabicMatch = text.match(/إلى\s+([^\s]{2,20})/);
  if (arabicMatch?.[1]) {
    return arabicMatch[1].trim().toUpperCase();
  }

  return 'LON';
};

const extractCountryCode = (text: string) => {
  const tokens = text
    .split(/\s+/)
    .map((token) => token.replace(/[^\p{L}]/gu, ''))
    .filter(Boolean);

  const code = tokens.find((token) => /^[A-Za-z]{2}$/.test(token));
  return code?.toUpperCase() ?? 'US';
};

const toSSE = (payload: unknown) => `data: ${JSON.stringify(payload)}\n\n`;

const getOrCreateProfile = async (user: User, log: ApiLogger): Promise<ProfileRow | null> => {
  const { data: existingProfile, error: existingError } = await supabaseAdmin
    .from('profiles')
    .select('id,email,subscription_tier,monthly_ai_credits')
    .eq('id', user.id)
    .maybeSingle();

  if (existingError) {
    log.error('profile lookup failed', existingError.message);
    return null;
  }

  if (existingProfile) {
    return {
      id: existingProfile.id,
      email: existingProfile.email ?? null,
      subscription_tier: existingProfile.subscription_tier ?? 'free',
      monthly_ai_credits: toNumberOr(existingProfile.monthly_ai_credits, 50),
    };
  }

  const { data: createdProfile, error: createError } = await supabaseAdmin
    .from('profiles')
    .upsert(
      {
        id: user.id,
        email: user.email ?? null,
        subscription_tier: 'free',
        monthly_ai_credits: 50,
      },
      { onConflict: 'id' },
    )
    .select('id,email,subscription_tier,monthly_ai_credits')
    .single();

  if (createError || !createdProfile) {
    log.error('profile upsert failed', createError?.message ?? 'profile not returned');
    return null;
  }

  return {
    id: createdProfile.id,
    email: createdProfile.email ?? null,
    subscription_tier: createdProfile.subscription_tier ?? 'free',
    monthly_ai_credits: toNumberOr(createdProfile.monthly_ai_credits, 50),
  };
};

const applyPostProcessing = async ({
  userId,
  subscriptionTier,
  currentCredits,
  model,
  promptTokens,
  completionTokens,
  log,
}: {
  userId: string;
  subscriptionTier: string;
  currentCredits: number;
  model: string;
  promptTokens: number;
  completionTokens: number;
  log: ApiLogger;
}) => {
  if (subscriptionTier === 'free') {
    const nextCredits = Math.max(0, currentCredits - 1);
    const { error: creditError } = await supabaseAdmin
      .from('profiles')
      .update({
        monthly_ai_credits: nextCredits,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId);

    if (creditError) {
      log.warn('credit decrement failed', creditError.message);
    }
  }

  const { error: usageError } = await supabaseAdmin.from('ai_usage_logs').insert({
    user_id: userId,
    model_used: model,
    prompt_tokens: promptTokens,
    completion_tokens: completionTokens,
  });

  if (usageError) {
    log.warn('usage logging failed', usageError.message);
  }
};

export async function POST(request: Request) {
  const log = apiLogger('/api/v1/chat/completions', request);

  const token = extractBearerToken(request.headers.get('authorization'));
  if (!token) {
    log.warn('missing bearer token');
    log.done(401);
    return openAIErrorResponse(
      401,
      'Unauthorized. Missing bearer token.',
      'authentication_error',
      'invalid_api_key',
    );
  }

  const { data: authData, error: authError } = await supabaseAdmin.auth.getUser(token);
  if (authError || !authData.user) {
    log.warn('invalid bearer token', authError?.message ?? 'no user');
    log.done(401);
    return openAIErrorResponse(
      401,
      'Unauthorized. Invalid bearer token.',
      'authentication_error',
      'invalid_api_key',
    );
  }

  const profile = await getOrCreateProfile(authData.user, log);
  if (!profile) {
    log.done(500);
    return openAIErrorResponse(
      500,
      'Failed to load user profile.',
      'server_error',
      'internal_server_error',
    );
  }

  const subscriptionTier = profile.subscription_tier ?? 'free';
  const monthlyAICredits = toNumberOr(profile.monthly_ai_credits, 50);
  if (subscriptionTier === 'free' && monthlyAICredits <= 0) {
    log.warn('monthly AI limit reached', { userId: profile.id });
    log.done(429);
    return openAIErrorResponse(
      429,
      'Monthly AI limit reached. Upgrade to Veralify+ to continue.',
      'invalid_request_error',
      'rate_limit_exceeded',
    );
  }

  let body: ChatCompletionRequest;
  try {
    body = (await request.json()) as ChatCompletionRequest;
  } catch {
    log.warn('invalid JSON payload');
    log.done(400);
    return openAIErrorResponse(
      400,
      'Invalid JSON payload.',
      'invalid_request_error',
      'invalid_request',
    );
  }

  const messages = Array.isArray(body.messages) ? body.messages : [];
  const userText = extractLatestUserText(messages);
  const intent = detectIntent(userText);
  const model =
    typeof body.model === 'string' && body.model.length > 0 ? body.model : 'gpt-4o-mini';
  const completionId = randomId('chatcmpl_mock');
  const created = nowUnix();
  const hasToolResult = hasToolResultMessage(messages);

  log.info('mock completion', {
    model,
    intent,
    hasToolResult,
    messageCount: messages.length,
  });

  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const encoder = new TextEncoder();
      let promptTokens = 35;
      let completionTokens = 20;

      const write = (payload: unknown) => {
        controller.enqueue(encoder.encode(toSSE(payload)));
      };

      if (!hasToolResult && intent === 'flight') {
        promptTokens = 45;
        completionTokens = 12;

        const args = {
          destination: extractDestination(userText),
          date: extractDate(userText),
        };
        const toolCallId = randomId('call_flight');

        write({
          id: completionId,
          object: 'chat.completion.chunk',
          created,
          model,
          choices: [
            {
              index: 0,
              delta: {
                tool_calls: [
                  {
                    index: 0,
                    id: toolCallId,
                    type: 'function',
                    function: {
                      name: 'searchFlights',
                      arguments: JSON.stringify(args),
                    },
                  },
                ],
              },
              finish_reason: null,
            },
          ],
        });

        write({
          id: completionId,
          object: 'chat.completion.chunk',
          created,
          model,
          choices: [{ index: 0, delta: {}, finish_reason: 'tool_calls' }],
          usage: { prompt_tokens: 45, completion_tokens: 12 },
        });
      } else if (!hasToolResult && intent === 'esim') {
        promptTokens = 40;
        completionTokens = 11;

        const args = {
          countryCode: extractCountryCode(userText),
        };
        const toolCallId = randomId('call_esim');

        write({
          id: completionId,
          object: 'chat.completion.chunk',
          created,
          model,
          choices: [
            {
              index: 0,
              delta: {
                tool_calls: [
                  {
                    index: 0,
                    id: toolCallId,
                    type: 'function',
                    function: {
                      name: 'fetch_eSIM_Catalog',
                      arguments: JSON.stringify(args),
                    },
                  },
                ],
              },
              finish_reason: null,
            },
          ],
        });

        write({
          id: completionId,
          object: 'chat.completion.chunk',
          created,
          model,
          choices: [{ index: 0, delta: {}, finish_reason: 'tool_calls' }],
          usage: { prompt_tokens: 40, completion_tokens: 11 },
        });
      } else {
        const text = hasToolResult
          ? 'Great — I have prepared options and attached interactive cards for you below.'
          : 'Welcome to Veralify Concierge. Ask me for flights or eSIM plans to begin.';

        for (const token of text.split(/\s+/)) {
          write({
            id: completionId,
            object: 'chat.completion.chunk',
            created,
            model,
            choices: [{ index: 0, delta: { content: `${token} ` }, finish_reason: null }],
          });
        }

        write({
          id: completionId,
          object: 'chat.completion.chunk',
          created,
          model,
          choices: [{ index: 0, delta: {}, finish_reason: 'stop' }],
          usage: { prompt_tokens: 35, completion_tokens: 20 },
        });
      }

      await applyPostProcessing({
        userId: profile.id,
        subscriptionTier,
        currentCredits: monthlyAICredits,
        model,
        promptTokens,
        completionTokens,
        log,
      });

      controller.enqueue(encoder.encode('data: [DONE]\n\n'));
      controller.close();
      log.done(200, {
        intent,
        hasToolResult,
        userId: profile.id,
        subscriptionTier,
      });
    },
  });

  return new Response(stream, { status: 200, headers });
}
