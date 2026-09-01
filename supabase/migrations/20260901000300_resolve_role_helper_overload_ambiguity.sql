begin;

-- Compatibility overload for legacy SQL and PL/pgSQL bodies that pass an
-- untyped string literal. PostgreSQL prefers text within the string category,
-- so current_user_has_role('teacher') remains unambiguous while explicitly
-- typed app_role and app_role[] calls retain their original APIs.
create or replace function private.current_user_has_role(expected_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role::text = expected_role
  );
$$;

alter function private.current_user_has_role(text) owner to postgres;
revoke all on function private.current_user_has_role(text)
from public, anon, authenticated;
grant execute on function private.current_user_has_role(text)
to authenticated, service_role;

comment on function private.current_user_has_role(text) is
  'Compatibility signature for legacy untyped role literals; typed callers should use app_role or app_role[].';

commit;
