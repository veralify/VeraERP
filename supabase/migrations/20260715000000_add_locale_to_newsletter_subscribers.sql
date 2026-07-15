-- Store each subscriber's preferred language so transactional emails
-- (welcome + referral notifications) can be sent in the language they
-- selected on the website.
alter table public.newsletter_subscribers
  add column if not exists locale text not null default 'en';
