import { defineMiddleware } from 'astro:middleware';

export const onRequest = defineMiddleware((context, next) => {
  const host = context.request.headers.get('host')?.toLowerCase() || '';

  if (host.startsWith('dashboard.veralify.com') && context.url.pathname === '/') {
    return context.redirect('/dashboard');
  }

  return next();
});
