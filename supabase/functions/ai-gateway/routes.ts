// @ts-nocheck
export type AiGatewayRoute =
  | 'analyze-food'
  | 'food-estimate'
  | 'food-verify'
  | 'chat'
  | 'insight'
  | 'progress-analysis'
  | 'recommendations'
  | 'feedback';

export function rawRouteName(url: URL | string) {
  const u = typeof url === 'string' ? new URL(url) : url;
  return u.pathname.split('/').filter(Boolean).pop() ?? '';
}

export function normalizeAiRoute(url: URL | string): AiGatewayRoute | null {
  const route = rawRouteName(url);
  if (route === 'food-estimate') return 'analyze-food';
  if (route === 'progress-analysis') return 'progress-analysis';
  if (['analyze-food', 'food-verify', 'chat', 'insight', 'recommendations', 'feedback'].includes(route)) return route as AiGatewayRoute;
  return null;
}
