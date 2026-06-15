-- PineSight web: reject new login when another browser already holds the session token.
-- The signed-in user is never replaced; the second login must wait for sign-out elsewhere.

create or replace function public.claim_pinesight_web_session(p_token uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  user_email text;
  existing uuid;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  if not public.jwt_is_staff() then
    raise exception 'not authorized for PineSight web';
  end if;

  select p.pinesight_web_session_token into existing
  from public.profiles p
  where p.id = uid;

  if existing is not null and existing is distinct from p_token then
    raise exception 'pinesight_web_session_in_use'
      using hint = 'This account is already signed in on another browser. Sign out there first.';
  end if;

  select u.email into user_email from auth.users u where u.id = uid;

  insert into public.profiles (id, email, pinesight_web_session_token, pinesight_web_session_at, updated_at)
  values (uid, user_email, p_token, now(), now())
  on conflict (id) do update
  set
    pinesight_web_session_token = excluded.pinesight_web_session_token,
    pinesight_web_session_at = excluded.pinesight_web_session_at,
    updated_at = now()
  where public.profiles.pinesight_web_session_token is null
     or public.profiles.pinesight_web_session_token = excluded.pinesight_web_session_token;

  if not found then
    raise exception 'pinesight_web_session_in_use'
      using hint = 'This account is already signed in on another browser. Sign out there first.';
  end if;
end;
$$;
