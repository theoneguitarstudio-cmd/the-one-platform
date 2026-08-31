begin;

select plan(12);

insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-00000000000a', 'teacher-a@example.invalid'),
  ('10000000-0000-0000-0000-00000000000b', 'teacher-b@example.invalid'),
  ('10000000-0000-0000-0000-00000000000c', 'student@example.invalid');

insert into public.user_roles (user_id, role)
values
  ('10000000-0000-0000-0000-00000000000a', 'teacher'),
  ('10000000-0000-0000-0000-00000000000b', 'teacher');

insert into public.teacher_profiles (
  user_id, public_slug, bio, teaching_status, is_public, trial_price_twd
)
values
  (
    '10000000-0000-0000-0000-00000000000a',
    'teacher-a',
    'Public teacher',
    'active',
    true,
    1000
  ),
  (
    '10000000-0000-0000-0000-00000000000b',
    'teacher-b',
    'Unpublished teacher',
    'active',
    false,
    1200
  );

select is(
  (select count(*) from public.teacher_public_profiles where is_discoverable),
  1::bigint,
  'only an active public teacher is placed in the discoverable projection'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select count(*) from public.teacher_public_profiles),
  1::bigint,
  'anonymous can read the active public teacher projection'
);

select is(
  (
    select count(*)
    from public.teacher_public_profiles
    where public_slug = 'teacher-b'
  ),
  0::bigint,
  'anonymous cannot read an unpublished teacher'
);

select throws_ok(
  $$select * from public.teacher_profiles$$,
  '42501',
  null,
  'anonymous cannot read private teacher profiles'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-00000000000a',
  true
);

select lives_ok(
  $$update public.teacher_profiles
    set bio = 'Updated public teacher bio'
    where public_slug = 'teacher-a'$$,
  'Teacher A can update an allowed own field'
);

select is(
  (
    select count(*)
    from public.teacher_profiles
    where public_slug = 'teacher-b'
  ),
  0::bigint,
  'Teacher A cannot read Teacher B private profile'
);

select is(
  (
    with attempted as (
      update public.teacher_profiles
      set bio = 'attempted cross-account change'
      where public_slug = 'teacher-b'
      returning 1
    )
    select count(*) from attempted
  ),
  0::bigint,
  'Teacher A cannot update Teacher B'
);

select throws_ok(
  $$update public.teacher_profiles
    set is_public = true
    where public_slug = 'teacher-a'$$,
  '42501',
  null,
  'Teacher A cannot self-publish'
);

select throws_ok(
  $$insert into public.teacher_stage_capabilities (
      teacher_profile_id, stage_number, capability_status
    )
    values (
      (select id from public.teacher_profiles where public_slug = 'teacher-a'),
      1,
      'certified'
    )$$,
  '42501',
  null,
  'Teacher A cannot self-certify a learning-map stage'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-00000000000c',
  true
);

select is(
  (select count(*) from public.teacher_profiles),
  0::bigint,
  'a signed-in student cannot read private teacher profiles'
);

reset role;

select throws_ok(
  $$insert into public.teacher_profiles (
      user_id, public_slug, teaching_status
    )
    values (
      '10000000-0000-0000-0000-00000000000c',
      'teacher-a',
      'draft'
    )$$,
  '23505',
  null,
  'duplicate public slugs are rejected'
);

select throws_ok(
  $$insert into public.teacher_profiles (
      user_id, public_slug, teaching_status, trial_price_twd
    )
    values (
      '10000000-0000-0000-0000-00000000000c',
      'negative-price',
      'draft',
      -1
    )$$,
  '23514',
  null,
  'negative prices are rejected'
);

select * from finish();
rollback;
