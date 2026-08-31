begin;

select plan(11);

select ok(
  pg_catalog.to_regprocedure(
    'private.lock_lesson_schedule_resources(uuid,uuid)'
  ) is not null,
  'shared Lesson schedule resource lock helper exists'
);
select is(
  (
    select pg_catalog.pg_get_userbyid(proowner)
    from pg_catalog.pg_proc
    where oid = 'private.lock_lesson_schedule_resources(uuid,uuid)'::regprocedure
  ),
  'postgres',
  'schedule lock helper has the trusted postgres owner'
);
select is(
  (
    select array_to_string(proconfig, ',')
    from pg_catalog.pg_proc
    where oid = 'private.lock_lesson_schedule_resources(uuid,uuid)'::regprocedure
  ),
  'search_path=""',
  'schedule lock helper pins an empty search_path'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc as procedure
    cross join lateral pg_catalog.aclexplode(
      coalesce(
        procedure.proacl,
        pg_catalog.acldefault('f', procedure.proowner)
      )
    ) as privilege
    where procedure.oid =
      'private.lock_lesson_schedule_resources(uuid,uuid)'::regprocedure
      and privilege.grantee = 0
      and privilege.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute the schedule lock helper'
);
select ok(
  not has_function_privilege(
    'anon', 'private.lock_lesson_schedule_resources(uuid,uuid)', 'EXECUTE'
  ),
  'anonymous cannot execute the schedule lock helper'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'private.lock_lesson_schedule_resources(uuid,uuid)',
    'EXECUTE'
  ),
  'authenticated clients cannot execute the schedule lock helper directly'
);
select ok(
  exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.lessons'::regclass
      and conname = 'lessons_teacher_no_overlap'
      and contype = 'x'
  ),
  'Teacher GiST exclusion constraint remains installed'
);
select ok(
  exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.lessons'::regclass
      and conname = 'lessons_student_no_overlap'
      and contype = 'x'
  ),
  'Student GiST exclusion constraint remains installed'
);

insert into auth.users (id, email) values
  ('70000000-0000-0000-0000-000000000001', 'schedule-contract-student@example.invalid'),
  ('70000000-0000-0000-0000-000000000002', 'schedule-contract-teacher@example.invalid');

insert into public.student_teacher_relationships (
  id, student_user_id, teacher_user_id, relationship_status, preferred_mode
) values (
  '71000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000002',
  'active', 'onsite'
);

insert into public.lessons (
  id, student_user_id, teacher_user_id, relationship_id, lesson_type,
  delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
  status, location_text
) values
  (
    '72000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000002',
    '71000000-0000-0000-0000-000000000001', 'fixed', 'onsite',
    '2099-10-01 10:00+00', '2099-10-01 10:50+00', 50,
    'Asia/Taipei', 'admin_cancelled', 'Fake test room'
  ),
  (
    '72000000-0000-0000-0000-000000000002',
    '70000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000002',
    '71000000-0000-0000-0000-000000000001', 'fixed', 'onsite',
    '2099-10-02 10:00+00', '2099-10-02 10:50+00', 50,
    'Asia/Taipei', 'completed', 'Fake test room'
  );

select lives_ok(
  $$insert into public.lessons (
      id, student_user_id, teacher_user_id, relationship_id, lesson_type,
      delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
      status, location_text
    ) values (
      '72000000-0000-0000-0000-000000000003',
      '70000000-0000-0000-0000-000000000001',
      '70000000-0000-0000-0000-000000000002',
      '71000000-0000-0000-0000-000000000001', 'fixed', 'onsite',
      '2099-10-01 10:00+00', '2099-10-01 10:50+00', 50,
      'Asia/Taipei', 'scheduled', 'Fake test room'
    )$$,
  'cancelled Lesson does not block the same interval'
);
select lives_ok(
  $$insert into public.lessons (
      id, student_user_id, teacher_user_id, relationship_id, lesson_type,
      delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
      status, location_text
    ) values (
      '72000000-0000-0000-0000-000000000004',
      '70000000-0000-0000-0000-000000000001',
      '70000000-0000-0000-0000-000000000002',
      '71000000-0000-0000-0000-000000000001', 'fixed', 'onsite',
      '2099-10-02 10:00+00', '2099-10-02 10:50+00', 50,
      'Asia/Taipei', 'scheduled', 'Fake test room'
    )$$,
  'completed Lesson does not block the same interval'
);
select lives_ok(
  $$insert into public.lessons (
      id, student_user_id, teacher_user_id, relationship_id, lesson_type,
      delivery_mode, starts_at, ends_at, duration_minutes, timezone_anchor,
      status, location_text
    ) values (
      '72000000-0000-0000-0000-000000000005',
      '70000000-0000-0000-0000-000000000001',
      '70000000-0000-0000-0000-000000000002',
      '71000000-0000-0000-0000-000000000001', 'fixed', 'onsite',
      '2099-10-01 10:50+00', '2099-10-01 11:40+00', 50,
      'Asia/Taipei', 'scheduled', 'Fake test room'
    )$$,
  'adjacent half-open Lesson interval remains allowed'
);

select * from finish();
rollback;
