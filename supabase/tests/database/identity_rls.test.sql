begin;

select plan(7);

insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-00000000000a', 'student-a@example.invalid'),
  ('00000000-0000-0000-0000-00000000000b', 'student-b@example.invalid'),
  ('00000000-0000-0000-0000-00000000000c', 'suspended@example.invalid');

update public.profiles
set account_status = 'suspended'
where user_id = '00000000-0000-0000-0000-00000000000c';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-00000000000a',
  true
);

select results_eq(
  $$select user_id from public.profiles order by user_id$$,
  $$values ('00000000-0000-0000-0000-00000000000a'::uuid)$$,
  'Student A can read only their own private profile'
);

select is(
  (
    select count(*)
    from public.profiles
    where user_id = '00000000-0000-0000-0000-00000000000b'
  ),
  0::bigint,
  'Student A cannot read Student B private profile'
);

select lives_ok(
  $$update public.profiles
    set display_name = 'Student A Updated'
    where user_id = '00000000-0000-0000-0000-00000000000a'$$,
  'Student A can update an allowed own-profile field'
);

select throws_ok(
  $$update public.profiles
    set account_status = 'suspended'
    where user_id = '00000000-0000-0000-0000-00000000000a'$$,
  '42501',
  null,
  'Student A cannot modify account status'
);

select throws_ok(
  $$update public.user_roles
    set role = 'admin'
    where user_id = '00000000-0000-0000-0000-00000000000a'$$,
  '42501',
  null,
  'Student A cannot modify roles'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-00000000000c',
  true
);

select is(
  (select count(*) from public.profiles),
  0::bigint,
  'Suspended users cannot read protected profile data'
);

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  $$select * from public.profiles$$,
  '42501',
  null,
  'Anonymous users have no private-profile table grant'
);

select * from finish();
rollback;
