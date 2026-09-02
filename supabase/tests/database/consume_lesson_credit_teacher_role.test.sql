-- P1-2: local-only functional regression. Use the same owner-created fixtures
-- and authenticated RPC calls as entitlement_lesson_credits.test.sql.
-- No triggers/policies are disabled. Every fixture and RPC mutation rolls back.
begin;
select no_plan();

create temporary table credit_role_ids(name text primary key,id uuid not null);
grant select,insert on pg_temp.credit_role_ids to authenticated;

insert into auth.users(id,email) values
('52000000-0000-0000-0000-000000000001','credit-role-student@example.invalid'),
('52000000-0000-0000-0000-000000000002','credit-role-teacher@example.invalid');
insert into public.user_roles(user_id,role)
values('52000000-0000-0000-0000-000000000002','teacher');
insert into public.teacher_profiles(
  user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd
) values(
  '52000000-0000-0000-0000-000000000002','credit-role-teacher','Role regression',
  'active',true,array['online']::public.teaching_mode[],500
);
insert into public.student_teacher_relationships(
  id,student_user_id,teacher_user_id,relationship_status,preferred_mode
) values(
  '52000000-0000-0000-0000-000000000003','52000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000002','active','online'
);
insert into public.entitlements(
  id,beneficiary_user_id,entitlement_type,status,starts_at,expires_at,
  product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes
) values(
  '52000000-0000-0000-0000-000000000020','52000000-0000-0000-0000-000000000001',
  'lesson_package','active',now()-interval '1 day',now()+interval '1 month',
  'Teacher role control package','both',50
);
insert into public.lesson_credit_ledger(
  entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code
) values(
  '52000000-0000-0000-0000-000000000020','52000000-0000-0000-0000-000000000001',
  'allocation',2,'teacher-role-control-allocation','test_fixture'
);
insert into public.lessons(
  id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,location_text
) values
('52000000-0000-0000-0000-000000000010','52000000-0000-0000-0000-000000000001',
 '52000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000003',
 'flexible','onsite',now()-interval '3 hours',now()-interval '130 minutes',50,
 'Asia/Taipei','completed','Local test studio'),
('52000000-0000-0000-0000-000000000011','52000000-0000-0000-0000-000000000001',
 '52000000-0000-0000-0000-000000000002','52000000-0000-0000-0000-000000000003',
 'flexible','onsite',now()-interval '2 hours',now()-interval '70 minutes',50,
 'Asia/Taipei','completed','Local test studio');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','52000000-0000-0000-0000-000000000001',true);
select lives_ok($$insert into pg_temp.credit_role_ids
  select 'positive',public.reserve_lesson_credit(
    '52000000-0000-0000-0000-000000000020','teacher-role-positive-reservation',
    '52000000-0000-0000-0000-000000000010',null)$$,
  'Student reserves the positive-control Lesson credit');
select lives_ok($$insert into pg_temp.credit_role_ids
  select 'negative',public.reserve_lesson_credit(
    '52000000-0000-0000-0000-000000000020','teacher-role-negative-reservation',
    '52000000-0000-0000-0000-000000000011',null)$$,
  'Student reserves the negative-control Lesson credit');

select set_config('request.jwt.claim.sub','52000000-0000-0000-0000-000000000002',true);
select ok(private.current_user_has_role(array['teacher'::public.app_role]),
  'Positive control: actor currently has Teacher role');
select lives_ok($$select public.consume_lesson_credit(
  (select id from pg_temp.credit_role_ids where name='positive'),
  '52000000-0000-0000-0000-000000000010')$$,
  'Positive control: active assigned Teacher consumes a completed Lesson');
reset role;
select is((select status from public.lesson_credit_reservations
  where id=(select id from pg_temp.credit_role_ids where name='positive')),
  'consumed'::public.lesson_credit_reservation_status,
  'Positive control: reservation is consumed');
select is((select count(*) from public.lesson_credit_ledger
  where reservation_id=(select id from pg_temp.credit_role_ids where name='positive')
    and entry_type='consumption' and reserved_delta=-1 and consumed_delta=1),
  1::bigint,'Positive control: exactly one correct consumption delta');

-- Remove only the domain role; retain the active profile and assignments.
delete from public.user_roles
where user_id='52000000-0000-0000-0000-000000000002' and role='teacher';
set local role authenticated;
select set_config('request.jwt.claim.sub','52000000-0000-0000-0000-000000000002',true);
select is(current_user::text,'authenticated','Negative fixture: executes as authenticated, not owner');
select is(auth.uid(),'52000000-0000-0000-0000-000000000002'::uuid,
  'Negative fixture: JWT still identifies the assigned Teacher');
select ok(private.current_user_is_active(),'Negative fixture: actor account remains active');
select is(private.current_user_has_role(array['teacher'::public.app_role]),false,
  'Negative fixture: Teacher role is actually removed');
select is(private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role]),false,
  'Negative fixture: actor has no Admin bypass');
reset role;
select is((select teaching_status::text from public.teacher_profiles
  where user_id='52000000-0000-0000-0000-000000000002'),'active',
  'Negative fixture: Teacher profile stays active');
select ok(exists(select 1 from public.lessons
  where id='52000000-0000-0000-0000-000000000011' and status='completed'
    and teacher_user_id='52000000-0000-0000-0000-000000000002'
    and student_user_id='52000000-0000-0000-0000-000000000001'),
  'Negative fixture: completed Lesson retains assignment and beneficiary');
select is((select status from public.lesson_credit_reservations
  where id=(select id from pg_temp.credit_role_ids where name='negative')),
  'reserved'::public.lesson_credit_reservation_status,
  'Negative fixture: credit is still reserved before unauthorized call');

create temporary table credit_role_before as select
  (select to_jsonb(r) from public.lesson_credit_reservations r
    where id=(select id from pg_temp.credit_role_ids where name='negative')) as reservation,
  (select to_jsonb(b) from private.lesson_credit_balance('52000000-0000-0000-0000-000000000020') b) as balance,
  (select to_jsonb(e) from public.entitlements e
    where id='52000000-0000-0000-0000-000000000020') as entitlement,
  (select to_jsonb(l) from public.lessons l
    where id='52000000-0000-0000-0000-000000000011') as lesson,
  (select coalesce(jsonb_agg(to_jsonb(b) order by b.id),'[]'::jsonb) from public.bookings b) as bookings,
  (select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb) from public.audit_logs a) as audit;

set local role authenticated;
select throws_ok($$select public.consume_lesson_credit(
  (select id from pg_temp.credit_role_ids where name='negative'),
  '52000000-0000-0000-0000-000000000011')$$,
  '42501','Not authorized','P1-2: removed Teacher role must be rejected');
reset role;

-- throws_ok retains writes when the call unexpectedly succeeds, allowing these
-- independent assertions to expose the real corruption before outer rollback.
select is((select to_jsonb(r) from public.lesson_credit_reservations r
  where id=(select id from pg_temp.credit_role_ids where name='negative')),
  (select reservation from credit_role_before),'P1-2: rejected consume leaves reservation unchanged');
select is((select count(*) from public.lesson_credit_ledger
  where reservation_id=(select id from pg_temp.credit_role_ids where name='negative')
    and entry_type='consumption'),0::bigint,'P1-2: rejected consume adds no consumption ledger entry');
select is((select coalesce(sum(consumed_delta),0)::bigint from public.lesson_credit_ledger
  where reservation_id=(select id from pg_temp.credit_role_ids where name='negative')),
  0::bigint,'P1-2: rejected consume adds no consumed credit delta');
select is((select to_jsonb(b) from private.lesson_credit_balance('52000000-0000-0000-0000-000000000020') b),
  (select balance from credit_role_before),'P1-2: rejected consume leaves every balance component unchanged');
select is((select to_jsonb(e) from public.entitlements e
  where id='52000000-0000-0000-0000-000000000020'),
  (select entitlement from credit_role_before),'P1-2: rejected consume leaves entitlement unchanged');
select is((select to_jsonb(l) from public.lessons l
  where id='52000000-0000-0000-0000-000000000011'),
  (select lesson from credit_role_before),'P1-2: rejected consume leaves Lesson unchanged');
-- Epic 5 accepts standalone Lessons; this fixture has no linked Booking.
select is((select coalesce(jsonb_agg(to_jsonb(b) order by b.id),'[]'::jsonb) from public.bookings b),
  (select bookings from credit_role_before),'P1-2: rejected consume neither creates nor changes Bookings');
-- The current credit core emits ledger history, not a central consume audit.
-- Do not introduce a rejected-attempt audit requirement in this regression.
select is((select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb) from public.audit_logs a),
  (select audit from credit_role_before),'P1-2: rejected consume leaves central audit unchanged');

select * from finish();
rollback;
