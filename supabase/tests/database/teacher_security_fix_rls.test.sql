begin;

select plan(16);

insert into auth.users (id, email)
values
  ('20000000-0000-0000-0000-00000000000a', 'security-teacher-a@example.invalid'),
  ('20000000-0000-0000-0000-00000000000b', 'security-teacher-b@example.invalid');

insert into public.user_roles (user_id, role)
values
  ('20000000-0000-0000-0000-00000000000a', 'teacher'),
  ('20000000-0000-0000-0000-00000000000b', 'teacher');

insert into public.teacher_profiles (
  user_id, public_slug, bio, teaching_status, is_public, trial_price_twd
)
values
  (
    '20000000-0000-0000-0000-00000000000a',
    'security-teacher-a',
    'Teacher A original bio',
    'active',
    true,
    1000
  ),
  (
    '20000000-0000-0000-0000-00000000000b',
    'security-teacher-b',
    'Teacher B original bio',
    'active',
    true,
    1200
  );

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  (select count(*) from public.teacher_public_profiles),
  2::bigint,
  'active public teachers are visible anonymously'
);

reset role;
update public.profiles
set account_status = 'suspended'
where user_id = '20000000-0000-0000-0000-00000000000a';

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  (select count(*) from public.teacher_public_profiles),
  1::bigint,
  'suspended teacher is immediately hidden from anonymous discovery'
);

reset role;
update public.profiles
set account_status = 'active'
where user_id = '20000000-0000-0000-0000-00000000000a';

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  (select count(*) from public.teacher_public_profiles),
  2::bigint,
  'reactivated eligible teacher becomes visible again'
);

reset role;
update public.profiles
set account_status = 'disabled'
where user_id = '20000000-0000-0000-0000-00000000000a';

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  (select count(*) from public.teacher_public_profiles),
  1::bigint,
  'disabled teacher is not publicly discoverable'
);

reset role;
update public.profiles
set account_status = 'active'
where user_id = '20000000-0000-0000-0000-00000000000a';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-00000000000a',
  true
);

select lives_ok(
  $$select public.update_own_teacher_profile(
      'Teacher A updated bio',
      null,
      12::smallint,
      900,
      1800,
      null,
      array['online']::public.teaching_mode[],
      'Taipei',
      array[(select id from public.specialties where code = 'fingerstyle')]::uuid[]
    )$$,
  'Teacher can atomically replace own editable profile and specialties'
);

select is(
  (select bio from public.teacher_profiles where public_slug = 'security-teacher-a'),
  'Teacher A updated bio',
  'atomic mutation updates own presentation fields'
);

select is(
  (
    select count(*)
    from public.teacher_specialties as assignment
    join public.specialties as specialty on specialty.id = assignment.specialty_id
    where assignment.teacher_profile_id = (
      select id from public.teacher_profiles where public_slug = 'security-teacher-a'
    )
      and specialty.code = 'fingerstyle'
  ),
  1::bigint,
  'atomic mutation replaces specialties'
);

select throws_ok(
  $$select public.update_own_teacher_profile(
      'Should rollback',
      null,
      12::smallint,
      900,
      1800,
      null,
      array['online']::public.teaching_mode[],
      'Taipei',
      array['ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid]
    )$$,
  '23514',
  'invalid specialty',
  'invalid specialty rejects the complete mutation'
);

select is(
  (
    select specialty.code
    from public.teacher_specialties as assignment
    join public.specialties as specialty on specialty.id = assignment.specialty_id
    where assignment.teacher_profile_id = (
      select id from public.teacher_profiles where public_slug = 'security-teacher-a'
    )
  ),
  'fingerstyle',
  'failed specialty replacement preserves original relations'
);

select throws_ok(
  $$select public.update_own_teacher_profile(
      'Should rollback negative price',
      null,
      12::smallint,
      -1,
      1800,
      null,
      array['online']::public.teaching_mode[],
      'Taipei',
      array[(select id from public.specialties where code = 'fingerstyle')]::uuid[]
    )$$,
  '23514',
  'invalid teacher profile input',
  'negative price rejects the complete mutation'
);

select is(
  (select bio from public.teacher_profiles where public_slug = 'security-teacher-a'),
  'Teacher A updated bio',
  'negative-price failure leaves original profile unchanged'
);

reset role;
select is(
  (select bio from public.teacher_profiles where public_slug = 'security-teacher-b'),
  'Teacher B original bio',
  'Teacher A RPC cannot target Teacher B'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-00000000000a',
  true
);
select throws_ok(
  $$update public.teacher_profiles
    set is_public = false
    where public_slug = 'security-teacher-a'$$,
  '42501',
  null,
  'Teacher cannot bypass RPC to change publication state'
);

select throws_ok(
  $$update public.teacher_profiles
    set teaching_status = 'paused'
    where public_slug = 'security-teacher-a'$$,
  '42501',
  null,
  'Teacher cannot bypass RPC to change teaching status'
);

select throws_ok(
  $$update public.teacher_profiles
    set public_slug = 'teacher-a-attempted-slug-change'
    where public_slug = 'security-teacher-a'$$,
  '42501',
  null,
  'Teacher cannot bypass RPC to change public slug'
);

reset role;
set local role anon;
select throws_ok(
  $$select public.update_own_teacher_profile(
      'Anonymous attempt',
      null,
      1::smallint,
      null,
      null,
      null,
      array[]::public.teaching_mode[],
      null,
      array[]::uuid[]
    )$$,
  '42501',
  null,
  'anonymous cannot execute the Teacher self-update RPC'
);

select * from finish();
rollback;
