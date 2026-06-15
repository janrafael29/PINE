-- Applicant details for DA/OMAG access review.

alter table public.da_access_requests
  add column if not exists full_name text,
  add column if not exists organization text,
  add column if not exists company_location text,
  add column if not exists position text;
