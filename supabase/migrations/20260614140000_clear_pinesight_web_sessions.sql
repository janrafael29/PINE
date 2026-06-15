-- PineSight web: allow multiple concurrent sign-ins (remove exclusive session lock).
update public.profiles
set
  pinesight_web_session_token = null,
  pinesight_web_session_at = null
where pinesight_web_session_token is not null;
