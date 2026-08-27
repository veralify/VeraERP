-- Phase 1 Batch 3 AI domain.
-- Ambiguity resolved: AI request/run/tool mutation tables are server-written; users can read their own conversations, request summaries, insights, recommendations, estimates, and submit feedback.

create type public.ai_message_role as enum ('user', 'assistant', 'system', 'tool');
create type public.ai_request_status as enum ('pending', 'processing', 'completed', 'failed');

create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  role public.ai_message_role not null,
  content jsonb not null,
  model text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task text not null,
  request_id text not null unique,
  status public.ai_request_status not null default 'pending',
  model_requested text,
  model_used text,
  fallback_used boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.ai_model_runs (
  id uuid primary key default gen_random_uuid(),
  ai_request_id uuid not null references public.ai_requests(id) on delete cascade,
  model text not null,
  provider text not null,
  model_policy_version text not null,
  prompt_version text not null,
  tool_schema_version text not null,
  safety_policy_version text not null,
  input_tokens bigint not null default 0 check (input_tokens >= 0),
  output_tokens bigint not null default 0 check (output_tokens >= 0),
  reasoning_tokens bigint check (reasoning_tokens is null or reasoning_tokens >= 0),
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  estimated_cost numeric check (estimated_cost is null or estimated_cost >= 0),
  success boolean not null,
  structured_output_valid boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_tool_calls (
  id uuid primary key default gen_random_uuid(),
  ai_request_id uuid not null references public.ai_requests(id) on delete cascade,
  tool_name text not null,
  arguments jsonb not null default '{}'::jsonb,
  result jsonb,
  success boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_food_estimates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  food_log_id uuid references public.food_logs(id) on delete set null,
  image_path text,
  model text not null,
  result jsonb not null,
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),
  verified boolean not null default false,
  corrected_by_user boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  source_data jsonb not null default '{}'::jsonb,
  model text not null,
  valid_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  recommendation_type text not null,
  target_id uuid,
  title text not null,
  reason text not null,
  model text not null,
  score numeric not null check (score >= 0 and score <= 1),
  dismissed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  ai_request_id uuid not null references public.ai_requests(id) on delete cascade,
  rating integer check (rating is null or rating between 1 and 5),
  feedback text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, ai_request_id)
);

create index if not exists idx_ai_conversations_user_created on public.ai_conversations(user_id, created_at desc);
create index if not exists idx_ai_messages_conversation_created on public.ai_messages(conversation_id, created_at);
create index if not exists idx_ai_requests_user_created_at on public.ai_requests(user_id, created_at desc);
create index if not exists idx_ai_model_runs_ai_request_id on public.ai_model_runs(ai_request_id);
create index if not exists idx_ai_tool_calls_ai_request_id on public.ai_tool_calls(ai_request_id);
create index if not exists idx_ai_food_estimates_user_created on public.ai_food_estimates(user_id, created_at desc);
create index if not exists idx_ai_food_estimates_food_log_id on public.ai_food_estimates(food_log_id);
create index if not exists idx_ai_insights_user_valid on public.ai_insights(user_id, valid_until);
create index if not exists idx_ai_recommendations_user_dismissed on public.ai_recommendations(user_id, dismissed_at, created_at desc);
create index if not exists idx_ai_feedback_ai_request_id on public.ai_feedback(ai_request_id);

create trigger set_ai_conversations_updated_at before update on public.ai_conversations for each row execute function public.set_updated_at();
create trigger set_ai_messages_updated_at before update on public.ai_messages for each row execute function public.set_updated_at();
create trigger set_ai_requests_updated_at before update on public.ai_requests for each row execute function public.set_updated_at();
create trigger set_ai_model_runs_updated_at before update on public.ai_model_runs for each row execute function public.set_updated_at();
create trigger set_ai_tool_calls_updated_at before update on public.ai_tool_calls for each row execute function public.set_updated_at();
create trigger set_ai_food_estimates_updated_at before update on public.ai_food_estimates for each row execute function public.set_updated_at();
create trigger set_ai_insights_updated_at before update on public.ai_insights for each row execute function public.set_updated_at();
create trigger set_ai_recommendations_updated_at before update on public.ai_recommendations for each row execute function public.set_updated_at();
create trigger set_ai_feedback_updated_at before update on public.ai_feedback for each row execute function public.set_updated_at();

alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_requests enable row level security;
alter table public.ai_model_runs enable row level security;
alter table public.ai_tool_calls enable row level security;
alter table public.ai_food_estimates enable row level security;
alter table public.ai_insights enable row level security;
alter table public.ai_recommendations enable row level security;
alter table public.ai_feedback enable row level security;
alter table public.ai_conversations force row level security;
alter table public.ai_messages force row level security;
alter table public.ai_requests force row level security;
alter table public.ai_model_runs force row level security;
alter table public.ai_tool_calls force row level security;
alter table public.ai_food_estimates force row level security;
alter table public.ai_insights force row level security;
alter table public.ai_recommendations force row level security;
alter table public.ai_feedback force row level security;

create policy ai_conversations_all_own on public.ai_conversations for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy ai_messages_all_parent_owned on public.ai_messages for all to authenticated using (exists (select 1 from public.ai_conversations ac where ac.id = ai_messages.conversation_id and ac.user_id = auth.uid())) with check (exists (select 1 from public.ai_conversations ac where ac.id = ai_messages.conversation_id and ac.user_id = auth.uid()));
create policy ai_requests_select_own on public.ai_requests for select to authenticated using (auth.uid() = user_id);
create policy ai_model_runs_select_parent_owned on public.ai_model_runs for select to authenticated using (exists (select 1 from public.ai_requests ar where ar.id = ai_model_runs.ai_request_id and ar.user_id = auth.uid()));
create policy ai_food_estimates_select_own on public.ai_food_estimates for select to authenticated using (auth.uid() = user_id);
create policy ai_food_estimates_update_verify_own on public.ai_food_estimates for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy ai_insights_select_own on public.ai_insights for select to authenticated using (auth.uid() = user_id);
create policy ai_recommendations_select_own on public.ai_recommendations for select to authenticated using (auth.uid() = user_id);
create policy ai_recommendations_update_dismiss_own on public.ai_recommendations for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy ai_feedback_select_own on public.ai_feedback for select to authenticated using (auth.uid() = user_id);
create policy ai_feedback_insert_own_request on public.ai_feedback for insert to authenticated with check (auth.uid() = user_id and exists (select 1 from public.ai_requests ar where ar.id = ai_feedback.ai_request_id and ar.user_id = auth.uid()));
create policy ai_feedback_update_own on public.ai_feedback for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, update, delete on public.ai_conversations, public.ai_messages to authenticated;
grant select on public.ai_requests, public.ai_model_runs, public.ai_food_estimates, public.ai_insights, public.ai_recommendations, public.ai_feedback to authenticated;
grant insert, update on public.ai_feedback to authenticated;
grant update on public.ai_food_estimates, public.ai_recommendations to authenticated;
revoke select, insert, update, delete on public.ai_tool_calls from anon, authenticated;
