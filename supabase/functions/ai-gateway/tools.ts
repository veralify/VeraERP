// @ts-nocheck
import { GatewayError, type ToolContext, type ToolDefinition } from './types.ts';
export const TOOL_SCHEMA_VERSION = '2026-08';
type Handler = (args: Record<string, unknown>, ctx: ToolContext) => Promise<unknown>;
type ToolSpec = { name: string; description: string; parameters: Record<string, unknown>; handler: Handler };
const objectSchema = (properties: Record<string, unknown> = {}, required: string[] = []) => ({ type: 'object', additionalProperties: false, properties, required });
const unavailable = (table: string): Handler => async () => ({ error: { code: 'NOT_YET_AVAILABLE', message: `Requires Agent B schema/table: ${table}` } });
const names = ['get_user_profile','get_user_goals','get_active_goal','get_food_log','get_daily_nutrition','get_nutrition_history','get_weight_history','get_measurements','get_progress_summary','get_activity_summary','get_user_groups','get_recommended_groups','get_live_rooms','get_upcoming_sessions','get_coach_relationship','search_foods','create_food_log','update_food_log','delete_food_log','create_goal','update_goal','create_progress_entry','recommend_group','recommend_live_room'];
const tools: ToolSpec[] = names.map((name) => ({ name, description: `${name} (caller-scoped allowlisted Veralify tool)`, parameters: objectSchema(name.startsWith('get_') ? {} : { id: { type: 'string' } }), handler: unavailable(name) }));
export const toolRegistry = new Map(tools.map((t) => [t.name, t]));
export function getOpenRouterTools(namesToUse?: string[]): ToolDefinition[] { const selected = namesToUse ? namesToUse.map((n) => { const t = toolRegistry.get(n); if (!t) throw new GatewayError('TOOL_NOT_ALLOWED', `Tool ${n} is not allowlisted`, 400); return t; }) : tools; return selected.map((t) => ({ type: 'function', function: { name: t.name, description: t.description, parameters: t.parameters } })); }
export async function executeTool(name: string, args: Record<string, unknown>, ctx: ToolContext): Promise<unknown> { const tool = toolRegistry.get(name); if (!tool) throw new GatewayError('TOOL_NOT_ALLOWED', `Tool ${name} is not allowlisted`, 400); return await tool.handler(args, ctx); }
