create table if not exists public.blog_posts (
  id uuid primary key default gen_random_uuid(),
  author_user_id uuid references public.vera_users(id) on delete set null,
  brand text not null default 'default',
  title text not null,
  slug text not null,
  excerpt text,
  content text not null,
  status text not null default 'draft',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_blog_posts_slug_brand
  on public.blog_posts(brand, slug);

create index if not exists idx_blog_posts_status_published_at
  on public.blog_posts(status, published_at desc);
