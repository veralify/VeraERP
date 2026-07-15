export function getSiteUrl(): string {
  if (process.env.VERCEL_ENV === 'production') return 'https://veralify.com';
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  return 'http://localhost:3000';
}
