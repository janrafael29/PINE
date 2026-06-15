-- Track whether the user registered as a farmer or government staff.

alter table public.profiles
  add column if not exists account_intent text;

alter table public.profiles
  drop constraint if exists profiles_account_intent_check;

alter table public.profiles
  add constraint profiles_account_intent_check
  check (account_intent is null or account_intent in ('farmer', 'staff'));
