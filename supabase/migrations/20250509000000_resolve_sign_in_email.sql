-- Resolve email/password login identifier: full email, or profiles.display_name → auth email.
-- SECURITY DEFINER: required to read auth.users from an RPC callable by anon before sign-in.

create or replace function public.resolve_sign_in_email(p_identifier text)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_trimmed text := trim(p_identifier);
  v_email text;
begin
  if v_trimmed is null or v_trimmed = '' then
    return null;
  end if;

  if position('@' in v_trimmed) > 0 then
    return lower(v_trimmed);
  end if;

  select u.email::text into v_email
  from public.profiles p
  join auth.users u on u.id = p.id
  where lower(trim(p.display_name)) = lower(v_trimmed)
  limit 1;

  return v_email;
end;
$$;

revoke all on function public.resolve_sign_in_email(text) from public;
grant execute on function public.resolve_sign_in_email(text) to anon, authenticated;
