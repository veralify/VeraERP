export * from './types';

import type {
  CoachResponse,
  FoodAnalysisResult,
  GatewayEnvelope,
  InsightResponse,
  RecommendationResponse,
} from './types';

export type GatewayRoute = 'analyze-food' | 'chat' | 'insight' | 'recommendations';

export class AiGatewayClientError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details?: unknown,
  ) {
    super(message);
  }
}

export async function callGateway<T>(
  route: GatewayRoute,
  body: unknown,
  options: { accessToken: string; baseUrl?: string; signal?: AbortSignal },
): Promise<GatewayEnvelope<T>> {
  const baseUrl = options.baseUrl ?? process.env.NEXT_PUBLIC_SUPABASE_FUNCTIONS_URL;
  if (!baseUrl) {
    throw new AiGatewayClientError(
      500,
      'MISSING_FUNCTIONS_URL',
      'NEXT_PUBLIC_SUPABASE_FUNCTIONS_URL is required.',
    );
  }

  const response = await fetch(`${baseUrl.replace(/\/$/, '')}/ai-gateway/${route}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${options.accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
    signal: options.signal,
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok || payload?.error) {
    const err = payload?.error ?? {};
    throw new AiGatewayClientError(
      response.status,
      String(err.code ?? 'AI_GATEWAY_ERROR'),
      String(err.message ?? 'AI gateway request failed.'),
      err.details,
    );
  }
  return payload as GatewayEnvelope<T>;
}

export const analyzeFood = (
  body: { image_ref: string; context?: Record<string, unknown> },
  options: { accessToken: string; baseUrl?: string; signal?: AbortSignal },
) => callGateway<FoodAnalysisResult>('analyze-food', body, options);

export const chatWithCoach = (
  body: {
    message: string;
    mode?: 'simple' | 'advanced';
    messages?: Array<{ role: string; content: string }>;
  },
  options: { accessToken: string; baseUrl?: string; signal?: AbortSignal },
) => callGateway<CoachResponse>('chat', body, options);

export const getAiInsight = (
  body: { type?: 'nutrition' | 'progress'; context: Record<string, unknown> },
  options: { accessToken: string; baseUrl?: string; signal?: AbortSignal },
) => callGateway<InsightResponse>('insight', body, options);

export const getRecommendations = (
  body: { candidates: unknown[] },
  options: { accessToken: string; baseUrl?: string; signal?: AbortSignal },
) => callGateway<RecommendationResponse>('recommendations', body, options);

export async function* readSseStream<T = unknown>(response: Response): AsyncGenerator<T> {
  if (!response.body) return;
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const chunks = buffer.split('\n\n');
    buffer = chunks.pop() ?? '';
    for (const chunk of chunks) {
      const line = chunk.split('\n').find((entry) => entry.startsWith('data: '));
      if (!line) continue;
      const data = line.slice(6).trim();
      if (data === '[DONE]') return;
      yield JSON.parse(data) as T;
    }
  }
}
