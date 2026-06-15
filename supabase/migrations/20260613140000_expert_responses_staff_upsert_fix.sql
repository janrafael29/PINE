-- Any staff may update advice on any detection (upsert after another DA/admin replied).
-- Replies remain attributed to the current author via with check.

drop policy if exists "expert_responses_update_jwt_staff" on public.expert_responses;

create policy "expert_responses_update_jwt_staff" on public.expert_responses
  for update
  using (public.jwt_is_staff())
  with check (
    public.jwt_is_staff()
    and author_id = auth.uid()
  );

drop policy if exists "expert_responses_select_jwt_staff" on public.expert_responses;

create policy "expert_responses_select_jwt_staff" on public.expert_responses
  for select
  using (public.jwt_is_staff());
