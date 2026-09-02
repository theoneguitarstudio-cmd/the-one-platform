-- P1 regression: run through the existing LOCAL Supabase pgTAP suite only.
-- No business fixtures or writes are needed to prove the unsafe ACL boundary.
-- A service_role raw Lesson completion must be denied, rather than bypassing
-- Booking lifecycle, credit reservation/consumption, authorization, and audit.
-- These assertions intentionally fail until a NEW corrective migration revokes
-- the writes; do not alter the already-applied Epic 3/5/6 migrations.
begin;
select plan(6);

select is(
  has_table_privilege('service_role', 'public.lessons', 'INSERT')
    or has_any_column_privilege('service_role', 'public.lessons', 'INSERT'),
  false,
  'service_role cannot raw INSERT lessons, including through column grants'
);
select is(
  has_table_privilege('service_role', 'public.lessons', 'UPDATE')
    or has_any_column_privilege('service_role', 'public.lessons', 'UPDATE'),
  false,
  'service_role cannot raw UPDATE lessons status/schedule outside domain transitions'
);
select is(
  has_table_privilege('service_role', 'public.lessons', 'DELETE'),
  false,
  'service_role cannot raw DELETE lessons outside domain transitions'
);
select is(
  has_table_privilege('service_role', 'public.lesson_records', 'INSERT')
    or has_any_column_privilege('service_role', 'public.lesson_records', 'INSERT'),
  false,
  'service_role cannot raw INSERT lesson_records outside authorized completion'
);
select is(
  has_table_privilege('service_role', 'public.lesson_records', 'UPDATE')
    or has_any_column_privilege('service_role', 'public.lesson_records', 'UPDATE'),
  false,
  'service_role cannot raw UPDATE lesson_records outside domain authority'
);
select is(
  has_table_privilege('service_role', 'public.lesson_records', 'DELETE'),
  false,
  'service_role cannot raw DELETE lesson_records outside domain authority'
);

select * from finish();
rollback;
