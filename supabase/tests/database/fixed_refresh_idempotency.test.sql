-- P1-3A: local refresh controls; fixtures follow scheduling_booking_core.
-- Domain transitions use authenticated public RPCs. Owner-created scheduled
-- Lessons isolate external collision checks. All fixtures roll back.
begin;
select no_plan();

create temporary table priority_context(
  first_day date, gap_day date, beyond_day date, series_id uuid,
  student_a uuid, student_b uuid, teacher uuid, relationship_a uuid,
  relationship_b uuid, flex_entitlement uuid
);
insert into priority_context
select d,d+35,d+70,null,
  '63000000-0000-0000-0000-000000000001'::uuid,
  '63000000-0000-0000-0000-000000000002'::uuid,
  '63000000-0000-0000-0000-000000000003'::uuid,
  '63000000-0000-0000-0000-000000000010'::uuid,
  '63000000-0000-0000-0000-000000000011'::uuid,
  '63000000-0000-0000-0000-000000000020'::uuid
from (select min(day::date) d from generate_series(current_date+7,current_date+13,interval '1 day') day
  where extract(dow from day)=3) dates;
grant select,insert,update on priority_context to authenticated;

insert into auth.users(id,email) select student_a,'priority-a@example.invalid' from priority_context
union all select student_b,'priority-b@example.invalid' from priority_context
union all select teacher,'priority-teacher@example.invalid' from priority_context;
insert into public.user_roles(user_id,role) select teacher,'teacher' from priority_context;
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,
  teaching_modes,trial_price_twd,default_meeting_provider,default_meeting_url)
select teacher,'priority-teacher','Priority fixture','active',true,
  array['online']::public.teaching_mode[],500,'manual_google_meet','https://meet.google.com/abc-defg-hij'
from priority_context;
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)
select relationship_a,student_a,teacher,'active'::public.student_teacher_relationship_status,'online'::public.teaching_mode from priority_context
union all select relationship_b,student_b,teacher,'active','online' from priority_context;
-- Initially A has no entitlement: priority is independent of credit.
insert into public.entitlements(id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,
  starts_at,expires_at,product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes)
select flex_entitlement,student_b,teacher,'lesson_package','active',now()-interval '1 day',
  now()+interval '6 months','Flexible control','flexible',50 from priority_context;
insert into public.lesson_credit_ledger(entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code)
select flex_entitlement,student_b,'allocation',8,'priority-flex-allocation','test_fixture' from priority_context;

set local role authenticated;
select set_config('request.jwt.claim.sub',(select teacher::text from priority_context),true);
select lives_ok($$select public.set_teacher_scheduling_settings(teacher,'Asia/Taipei',0,28,10,'Priority fixture') from priority_context$$,
  'Fixture: Teacher configures 28-day booking horizon');
select lives_ok($$select public.create_teacher_availability_rule(teacher,3::smallint,'20:00'::time,'21:00'::time,
  'Asia/Taipei',current_date,current_date+120,'Wednesday availability') from priority_context$$,
  'Fixture: Teacher creates Wednesday availability');
select lives_ok($$update pg_temp.priority_context set series_id=public.create_recurring_lesson_series(
  student_a,teacher,relationship_a,null,3::smallint,'20:00'::time,'Asia/Taipei',50::smallint,
  first_day,null,'Fixed ownership without credit')$$,'Fixture: first Fixed expansion succeeds without credit');
reset role;
select ok((select series_id is not null from priority_context),'Fixture: active base series exists');
select ok((select count(*)>1 from public.recurring_lesson_occurrences),'Fixture: initial expansion contains multiple occurrences');
select is((select count(*) from public.lessons),0::bigint,'Priority creation does not create Lessons');
select is((select count(*) from public.bookings),0::bigint,'Priority creation does not create Bookings');
select is((select count(*) from public.entitlements where beneficiary_user_id=(select student_a from priority_context)),
  0::bigint,'Fixed priority owner has no credit package');


-- P1-3A focused controls. The setup above mirrors the existing priority fixture.
-- The original combined A/B/C regression is deliberately left unchanged.
set local role authenticated;
select set_config('request.jwt.claim.sub',(select teacher::text from priority_context),true);
select is((select public.refresh_recurring_series_occurrences(series_id,current_date+28) from priority_context),
  0,'3A: second refresh inserts zero duplicates');
select is((select public.refresh_recurring_series_occurrences(series_id,current_date+28) from priority_context),
  0,'3A: third refresh inserts zero duplicates');
reset role;
select ok((select bool_and(status='planned') from public.recurring_lesson_occurrences),
  '3A: repeated refresh retains planned state');

-- Expand explicitly only for state controls; no automatic horizon behavior is added.
set local role authenticated;
select lives_ok($$select public.set_teacher_scheduling_settings(teacher,'Asia/Taipei',0,60,10,'State control horizon')
  from priority_context$$,'3A fixture: configure state-control horizon');
select lives_ok($$select public.refresh_recurring_series_occurrences(series_id,current_date+60)
  from priority_context$$,'3A: refresh can add new dates after skipping existing logical occurrences');
reset role;
insert into public.entitlements(id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,
  starts_at,expires_at,product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes)
select '63000000-0000-0000-0000-000000000021',student_a,teacher,'lesson_package','active',
  now()-interval '1 day',now()+interval '6 months','Fixed materialization control','fixed',50 from priority_context;
insert into public.lesson_credit_ledger(entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code)
select '63000000-0000-0000-0000-000000000021',student_a,'allocation',4,'refresh-fixed-control-allocation','test_fixture'
from priority_context;
create temporary table refresh_times as select first_day,
  private.resolve_scheduling_local_datetime(first_day+28,'21:00','Asia/Taipei') as moved_start,
  private.resolve_scheduling_local_datetime(first_day+14,'20:00','Asia/Taipei') as released_start,
  private.resolve_scheduling_local_datetime(first_day+35,'20:00','Asia/Taipei') as collision_start,
  private.resolve_scheduling_local_datetime(first_day+70,'20:00','Asia/Taipei') as future_collision_start
from priority_context;
grant select on refresh_times to authenticated;
set local role authenticated;
select lives_ok($$select public.materialize_recurring_lesson_occurrence(series_id,first_day,
  '63000000-0000-0000-0000-000000000021','refresh-materialized-control') from priority_context$$,
  '3A fixture: materialize one occurrence through the formal RPC');
select is((select public.materialize_recurring_lesson_occurrence(series_id,first_day+7,null,
  'refresh-credit-required-control') from priority_context),null::uuid,
  '3A fixture: mark another occurrence credit_required');
select lives_ok($$select public.set_recurring_lesson_series_exception(series_id,first_day+14,'release',null,null,true,
  'Release one control date') from priority_context$$,'3A fixture: release one date');
select lives_ok($$select public.set_recurring_lesson_series_exception(series_id,first_day+21,'skip_holiday',null,null,true,
  'Skip one control date') from priority_context$$,'3A fixture: skip one date');
select lives_ok($$select public.set_recurring_lesson_series_exception(series_id,c.first_day+28,'reschedule',
  moved_start,moved_start+interval '50 minutes',false,'Reschedule one control date')
  from priority_context c cross join refresh_times$$,'3A fixture: reschedule one occurrence away from base time');
select set_config('request.jwt.claim.sub',(select student_b::text from priority_context),true);
select lives_ok($$select public.create_lesson_booking(student_b,teacher,relationship_b,flex_entitlement,
  released_start,'Asia/Taipei','refresh-released-flex-control','Book released date')
  from priority_context cross join refresh_times$$,
  '3A fixture: another student legitimately books the released date');
reset role;

-- Snapshot full rows, including bindings, timestamps and exceptions.
create temporary table refresh_before as select
  (select jsonb_agg(to_jsonb(o) order by o.id) from public.recurring_lesson_occurrences o) as occurrences,
  (select jsonb_agg(to_jsonb(s) order by s.id) from public.recurring_lesson_series s) as series,
  (select jsonb_agg(to_jsonb(e) order by e.id) from public.recurring_lesson_series_exceptions e) as exceptions,
  (select jsonb_agg(to_jsonb(l) order by l.id) from public.lessons l) as lessons,
  (select jsonb_agg(to_jsonb(b) order by b.id) from public.bookings b) as bookings,
  (select jsonb_agg(to_jsonb(r) order by r.id) from public.lesson_credit_reservations r) as reservations,
  (select jsonb_agg(to_jsonb(l) order by l.id) from public.lesson_credit_ledger l) as ledger,
  (select jsonb_agg(to_jsonb(e) order by e.id) from public.entitlements e) as entitlements;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select teacher::text from priority_context),true);
select is((select public.refresh_recurring_series_occurrences(series_id,current_date+60) from priority_context),
  0,'3A: mixed-state refresh ignores only its own occurrence and materialized Lesson');
select is((select public.refresh_recurring_series_occurrences(series_id,current_date+60) from priority_context),
  0,'3A: mixed-state third refresh stays idempotent');
reset role;
select is((select status::text from public.recurring_lesson_occurrences where occurrence_date=(select first_day from priority_context)),
  'materialized','3A: materialized state retained');
select is((select status::text from public.recurring_lesson_occurrences where occurrence_date=(select first_day+7 from priority_context)),
  'credit_required','3A: credit_required state retained');
select is((select status::text from public.recurring_lesson_occurrences where occurrence_date=(select first_day+14 from priority_context)),
  'released','3A: released occurrence is not recreated despite an external booking at base time');
select is((select status::text from public.recurring_lesson_occurrences where occurrence_date=(select first_day+21 from priority_context)),
  'skipped','3A: skipped state retained');
select is((select starts_at from public.recurring_lesson_occurrences where occurrence_date=(select first_day+28 from priority_context)),
  (select moved_start from refresh_times),'3A: rescheduled occurrence keeps its canonical persisted time');
select is((select jsonb_agg(to_jsonb(o) order by o.id) from public.recurring_lesson_occurrences o),
  (select occurrences from refresh_before),'3A: no occurrence row, owner or binding changes');
select is((select jsonb_agg(to_jsonb(s) order by s.id) from public.recurring_lesson_series s),
  (select series from refresh_before),'3A: base rule unchanged');
select is((select jsonb_agg(to_jsonb(e) order by e.id) from public.recurring_lesson_series_exceptions e),
  (select exceptions from refresh_before),'3A: exceptions unchanged');
select is((select jsonb_agg(to_jsonb(l) order by l.id) from public.lessons l),
  (select lessons from refresh_before),'3A: no Lesson created or modified');
select is((select jsonb_agg(to_jsonb(b) order by b.id) from public.bookings b),
  (select bookings from refresh_before),'3A: Bookings unchanged');
select is((select jsonb_agg(to_jsonb(r) order by r.id) from public.lesson_credit_reservations r),
  (select reservations from refresh_before),'3A: reservations unchanged');
select is((select jsonb_agg(to_jsonb(l) order by l.id) from public.lesson_credit_ledger l),
  (select ledger from refresh_before),'3A: credit ledger unchanged');
select is((select jsonb_agg(to_jsonb(e) order by e.id) from public.entitlements e),
  (select entitlements from refresh_before),'3A: entitlement state unchanged');

set local role authenticated;
select throws_ok($$select public.create_recurring_lesson_series(student_b,teacher,relationship_b,null,
  3::smallint,'20:00'::time,'Asia/Taipei',50::smallint,first_day+35,first_day+35,'External series collision')
  from priority_context$$,'P0001','RECURRING_SERIES_CONFLICT',
  '3A: true overlapping ownership by another series is still rejected');
reset role;

-- Owner-created scheduled Lesson fixtures independently exercise Teacher and
-- Student collision checks against an EXISTING planned occurrence.
insert into auth.users(id,email) values('63000000-0000-0000-0000-000000000004','refresh-other-teacher@example.invalid');
insert into public.user_roles(user_id,role) values('63000000-0000-0000-0000-000000000004','teacher');
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd)
values('63000000-0000-0000-0000-000000000004','refresh-other-teacher','Other Teacher','active',false,array['online']::public.teaching_mode[],500);
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)
select '63000000-0000-0000-0000-000000000012',student_a,'63000000-0000-0000-0000-000000000004','active','online'
from priority_context;
insert into public.lessons(id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,location_text)
select '63000000-0000-0000-0000-000000000100',student_b,teacher,relationship_b,'flexible','onsite',
  collision_start,collision_start+interval '50 minutes',50,'Asia/Taipei','scheduled','Local collision fixture'
from priority_context cross join refresh_times;
set local role authenticated;
select throws_ok($$select public.refresh_recurring_series_occurrences(series_id,current_date+60) from priority_context$$,
  'P0001','RECURRING_SERIES_CONFLICT','3A: Teacher overlap with another students scheduled Lesson still rejects refresh');
reset role;
delete from public.lessons where id='63000000-0000-0000-0000-000000000100';
insert into public.lessons(id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,location_text)
select '63000000-0000-0000-0000-000000000101',student_a,'63000000-0000-0000-0000-000000000004',
  '63000000-0000-0000-0000-000000000012','flexible','onsite',
  collision_start,collision_start+interval '50 minutes',50,'Asia/Taipei','scheduled','Local collision fixture'
from priority_context cross join refresh_times;
set local role authenticated;
select throws_ok($$select public.refresh_recurring_series_occurrences(series_id,current_date+60) from priority_context$$,
  'P0001','RECURRING_SERIES_CONFLICT','3A: Student overlap with another Teachers scheduled Lesson still rejects refresh');
reset role;
delete from public.lessons where id='63000000-0000-0000-0000-000000000101';

-- Also exercise the NEW-occurrence path: a later collision must roll back all
-- dates added earlier in the same refresh, preserving atomic horizon expansion.
set local role authenticated;
select lives_ok($$select public.set_teacher_scheduling_settings(teacher,'Asia/Taipei',0,90,10,'Collision expansion control')
  from priority_context$$,'3A fixture: extend test horizon for new-occurrence collision');
reset role;
insert into public.lessons(id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,location_text)
select '63000000-0000-0000-0000-000000000102',student_b,teacher,relationship_b,'flexible','onsite',
  future_collision_start,future_collision_start+interval '50 minutes',50,'Asia/Taipei','scheduled','Future collision fixture'
from priority_context cross join refresh_times;
set local role authenticated;
select throws_ok($$select public.refresh_recurring_series_occurrences(series_id,first_day+70) from priority_context$$,
  'P0001','RECURRING_SERIES_CONFLICT','3A: new date still rejects external scheduled Lesson');
reset role;
select is((select jsonb_agg(to_jsonb(o) order by o.id) from public.recurring_lesson_occurrences o),
  (select occurrences from refresh_before),'3A: failed expansion rolls back every new date, leaving no partial horizon');

-- Bounded concurrency contract: preserve natural uniqueness and the existing
-- wrapper advisory-lock -> series row-lock -> occurrence row-lock ordering.
select ok(exists(select 1 from pg_constraint where conrelid='public.recurring_lesson_occurrences'::regclass
  and contype='u' and pg_get_constraintdef(oid)='UNIQUE (series_id, occurrence_date)'),
  '3A concurrency control: database enforces one logical occurrence per series/date');
select ok(position('private.lock_lesson_schedule_resources' in body)>0
  and position('private.lock_lesson_schedule_resources' in body)<position('private.ensure_recurring_occurrences' in body),
  '3A concurrency control: wrapper obtains schedule advisory locks before expansion')
from (select pg_get_functiondef('public.refresh_recurring_series_occurrences(uuid,date)'::regprocedure) body) f;
select ok(position('where id=p_series_id for update' in body)>0
  and position('where id=p_series_id for update' in body)<position('o.occurrence_date=candidate_date for update' in body),
  '3A concurrency control: series row is locked before canonical occurrence row')
from (select pg_get_functiondef('private.ensure_recurring_occurrences(uuid,date)'::regprocedure) body) f;
select is((select count(*) from (select series_id,occurrence_date from public.recurring_lesson_occurrences
  group by series_id,occurrence_date having count(*)>1) duplicates),0::bigint,
  '3A concurrency control: repeated refresh retains a single owner row per logical occurrence');

select * from finish();
rollback;
