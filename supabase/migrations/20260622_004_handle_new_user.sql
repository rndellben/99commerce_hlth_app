-- Auto-create a public.users row when a new auth.users row appears.
--
-- Without this, every cloud push (devices / user_profiles / daily_metrics /
-- baselines) fails with a foreign-key violation because all of those tables
-- reference public.users(id) and nothing else inserts the parent row.
--
-- Runs with SECURITY DEFINER so the trigger bypasses RLS — the function's
-- only job is to copy the new auth uid + email into public.users.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
