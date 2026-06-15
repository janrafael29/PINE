-- PineSight Admin: one active web session token per staff account.
-- A new login (claim) replaces the token; other browsers fail validate and sign out.

alter table public.profiles
  add column if not exists pinesight_web_session_token uuid;

alter table public.profiles
  add column if not exists pinesight_web_session_at timestamptz;

create or replace function public.claim_pinesight_web_session(p_token uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  user_email text;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  if not public.jwt_is_staff() then
    raise exception 'not authorized for PineSight web';
  end if;

  select u.email into user_email from auth.users u where u.id = uid;

  insert into public.profiles (id, email, pinesight_web_session_token, pinesight_web_session_at, updated_at)
  values (uid, user_email, p_token, now(), now())
  on conflict (id) do update
  set
    pinesight_web_session_token = excluded.pinesight_web_session_token,
    pinesight_web_session_at = excluded.pinesight_web_session_at,
    updated_at = now();
end;
$$;

create or replace function public.validate_pinesight_web_session(p_token uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.pinesight_web_session_token = p_token
      and public.jwt_is_staff()
  );
$$;

create or replace function public.release_pinesight_web_session(p_token uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  update public.profiles
  set
    pinesight_web_session_token = null,
    pinesight_web_session_at = null,
    updated_at = now()
  where id = auth.uid()
    and pinesight_web_session_token = p_token;
end;
$$;

revoke all on function public.claim_pinesight_web_session(uuid) from public;
revoke all on function public.validate_pinesight_web_session(uuid) from public;
revoke all on function public.release_pinesight_web_session(uuid) from public;

grant execute on function public.claim_pinesight_web_session(uuid) to authenticated;
grant execute on function public.validate_pinesight_web_session(uuid) to authenticated;
grant execute on function public.release_pinesight_web_session(uuid) to authenticated;
