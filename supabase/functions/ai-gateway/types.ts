// @ts-nocheck
export type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue };
export type AiTaskType = 'food_image' | 'simple_chat' | 'advanced_chat' | 'weekly_analysis' | 'cheap_multimodal' | 'coding' | 'moderation' | 'insight' | 'recommendations' | 'food_verification';
export type AiMessage = { role: 'system' | 'user' | 'assistant' | 'tool'; content: string | Array<Record<string, unknown>>; tool_call_id?: string; name?: string };
export type Usage = { inputTokens: number; outputTokens: number; reasoningTokens?: number | null };
export type ModelRunMeta = { requestId: string; aiRequestId?: string | null; userId: string; task: AiTaskType; model: string; provider: string | null; modelPolicyVersion: string; promptVersion: string; toolSchemaVersion: string; safetyPolicyVersion: string; latencyMs: number; estimatedCostUsd: number; success: boolean; structuredOutputValid: boolean; usage: Usage };
export type GatewayErrorCode = 'UNAUTHORIZED' | 'BAD_REQUEST' | 'MISSING_OPENROUTER_API_KEY' | 'RATE_LIMITED' | 'COST_CEILING_EXCEEDED' | 'SAFETY_REFUSAL' | 'MODEL_UNAVAILABLE' | 'STRUCTURED_OUTPUT_INVALID' | 'TOOL_NOT_ALLOWED' | 'NOT_YET_AVAILABLE' | 'INTERNAL_ERROR';
export class GatewayError extends Error { constructor(public code: GatewayErrorCode, message: string, public status = 500, public details?: Record<string, unknown>) { super(message); } }
export type SupabaseLike = { from: (table: string) => any; auth?: { getUser?: (token: string) => Promise<{ data?: { user?: { id: string; email?: string | null } | null }; error?: { message?: string } | null }> } };
export type ToolContext = { userId: string; supabase: SupabaseLike; requestId: string };
export type ToolDefinition = { type: 'function'; function: { name: string; description: string; parameters: Record<string, unknown> } };
