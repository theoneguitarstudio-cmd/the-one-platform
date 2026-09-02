-- P1-3B: local horizon controls; fixtures follow scheduling_booking_core.
-- Domain transitions use authenticated public RPCs; owner reads compare
-- authority and integrity without exposing private helpers. All fixtures roll back.
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
  current_date,null,'Fixed ownership without credit')$$,'Fixture: first Fixed expansion succeeds without credit');
reset role;
select ok((select series_id is not null from priority_context),'Fixture: active base series exists');
select ok((select count(*)>1 from public.recurring_lesson_occurrences),'Fixture: initial expansion contains multiple occurrences');
select is((select count(*) from public.lessons),0::bigint,'Priority creation does not create Lessons');
select is((select count(*) from public.bookings),0::bigint,'Priority creation does not create Bookings');
select is((select count(*) from public.entitlements where beneficiary_user_id=(select student_a from priority_context)),
  0::bigint,'Fixed priority owner has no credit package');



-- P1-3B direct base-rule authority controls. The initial fixture uses a 28-day
-- horizon and gives Fixed owner A no entitlement. No original expectation changes.
create temporary table horizon_times as select
  private.resolve_scheduling_local_datetime(gap_day,'20:00','Asia/Taipei') as target,
  private.resolve_scheduling_local_datetime(gap_day+7,'20:00','Asia/Taipei') as next_target,
  private.resolve_scheduling_local_datetime(first_day,'20:00','Asia/Taipei') as expanded_target
from priority_context;
grant select on horizon_times to authenticated;
select is((select count(*) from public.recurring_lesson_occurrences where occurrence_date=(select gap_day from priority_context)),
  0::bigint,'3B fixture: target occurrence has never been expanded');
select is((select count(*) from public.entitlements where beneficiary_user_id=(select student_a from priority_context)),
  0::bigint,'3B fixture: Fixed owner has no usable credit');
create temporary table horizon_before as select
  (select jsonb_agg(to_jsonb(o) order by o.id) from public.recurring_lesson_occurrences o) as occurrences,
  (select jsonb_agg(to_jsonb(s) order by s.id) from public.recurring_lesson_series s) as series,
  (select coalesce(jsonb_agg(to_jsonb(b) order by b.id),'[]'::jsonb) from public.bookings b) as bookings,
  (select coalesce(jsonb_agg(to_jsonb(l) order by l.id),'[]'::jsonb) from public.lessons l) as lessons,
  (select coalesce(jsonb_agg(to_jsonb(r) order by r.id),'[]'::jsonb) from public.lesson_credit_reservations r) as reservations,
  (select jsonb_agg(to_jsonb(l) order by l.id) from public.lesson_credit_ledger l) as ledger,
  (select count(*) from public.recurring_lesson_occurrences) as occurrence_count;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select teacher::text from priority_context),true);
select lives_ok($$select public.set_teacher_scheduling_settings(teacher,'Asia/Taipei',0,60,10,'Expand horizon control')
  from priority_context$$,'3B: formally expand booking horizon 28 to 60');
select set_config('request.jwt.claim.sub',(select student_b::text from priority_context),true);
-- Deliberately call booking BEFORE discovery; no prior read can supply coverage.
select throws_ok($$select public.create_lesson_booking(student_b,teacher,relationship_b,flex_entitlement,
  target,'Asia/Taipei','horizon-direct-rejected','Direct booking without discovery')
  from priority_context cross join horizon_times$$,'P0001','SLOT_NOT_AVAILABLE',
  '3B: direct booking rejects unexpanded Fixed priority without discovery');
select is((select count(*) from priority_context c cross join horizon_times t
  cross join lateral public.get_available_flexible_slots(c.teacher,c.flex_entitlement,t.target,t.target+interval '50 minutes') slots),
  0::bigint,'3B: discovery excludes the same unexpanded Fixed slot');
select throws_ok($$select public.create_lesson_booking(student_b,teacher,relationship_b,flex_entitlement,
  target,'Asia/Taipei','horizon-after-discovery','Booking after blocked discovery')
  from priority_context cross join horizon_times$$,'P0001','SLOT_NOT_AVAILABLE',
  '3B: booking after discovery is independently rejected');
reset role;
select is((select private.scheduling_slot_clear(student_b,teacher,target,target+interval '50 minutes')
  from priority_context cross join horizon_times),false,'3B: shared collision authority enforces base priority');
select is((select private.scheduling_slot_clear(student_b,teacher,target+interval '10 minutes',target+interval '60 minutes')
  from priority_context cross join horizon_times),false,'3B: partial UTC overlap is blocked, not only equal start times');
select is((select private.scheduling_slot_clear(student_b,teacher,target+interval '50 minutes',target+interval '100 minutes')
  from priority_context cross join horizon_times),true,'3B: half-open adjacent interval remains clear');
select is((select private.scheduling_slot_clear(student_a,'63000000-0000-0000-0000-000000000004',
  target,target+interval '50 minutes') from priority_context cross join horizon_times),false,
  '3B: student resource also respects their Fixed priority with another Teacher');
select is((select coalesce(jsonb_agg(to_jsonb(b) order by b.id),'[]'::jsonb) from public.bookings b),
  (select bookings from horizon_before),'3B: rejected requests create no Booking');
select is((select coalesce(jsonb_agg(to_jsonb(l) order by l.id),'[]'::jsonb) from public.lessons l),
  (select lessons from horizon_before),'3B: rejected requests create no Lesson');
select is((select coalesce(jsonb_agg(to_jsonb(r) order by r.id),'[]'::jsonb) from public.lesson_credit_reservations r),
  (select reservations from horizon_before),'3B: rejected requests create no reservation');
select is((select jsonb_agg(to_jsonb(l) order by l.id) from public.lesson_credit_ledger l),
  (select ledger from horizon_before),'3B: rejected requests do not mutate ledger');
select is((select jsonb_agg(to_jsonb(o) order by o.id) from public.recurring_lesson_occurrences o),
  (select occurrences from horizon_before),'3B: authority checks generate zero occurrence rows');
select is((select jsonb_agg(to_jsonb(s) order by s.id) from public.recurring_lesson_series s),
  (select series from horizon_before),'3B: Fixed base owner remains unchanged');
select diag('3B occurrence count before='||(select occurrence_count::text from horizon_before)||
  ', after='||(select count(*)::text from public.recurring_lesson_occurrences));

set local role authenticated;
select set_config('request.jwt.claim.sub',(select teacher::text from priority_context),true);
select throws_ok($$select public.create_recurring_lesson_series(student_b,teacher,relationship_b,null,
  3::smallint,'20:00'::time,'Asia/Taipei',50::smallint,gap_day,gap_day,'Future same-zone duplicate owner')
  from priority_context$$,'P0001','RECURRING_SERIES_CONFLICT','3B: same-zone Fixed-vs-Fixed future ownership remains protected');

-- Explicit refresh only prepares a future release; it is not required for safety.
select lives_ok($$select public.refresh_recurring_series_occurrences(series_id,gap_day) from priority_context$$,
  '3B: explicit refresh can still expand its own base priority');
select lives_ok($$select public.set_recurring_lesson_series_exception(series_id,gap_day,'release',null,null,true,
  'Release future occurrence') from priority_context$$,'3B: explicitly release one future date');
select set_config('request.jwt.claim.sub',(select student_b::text from priority_context),true);
select is((select count(*) from priority_context c cross join horizon_times t
  cross join lateral public.get_available_flexible_slots(c.teacher,c.flex_entitlement,t.target,t.target+interval '50 minutes') slots),
  1::bigint,'3B: explicit release supersedes active base rule in discovery');
select lives_ok($$select public.create_lesson_booking(student_b,teacher,relationship_b,flex_entitlement,
  target,'Asia/Taipei','horizon-released-booking','Booking explicitly released date')
  from priority_context cross join horizon_times$$,'3B: released future date permits a legitimate Flexible booking');
select is((select count(*) from priority_context c cross join horizon_times t
  cross join lateral public.get_available_flexible_slots(c.teacher,c.flex_entitlement,t.next_target,t.next_target+interval '50 minutes') slots),
  0::bigint,'3B: next unexpanded recurrence stays protected after a one-off release');
select throws_ok($$select public.create_lesson_booking(student_b,teacher,relationship_b,flex_entitlement,
  next_target,'Asia/Taipei','horizon-next-rejected','Next recurrence still owned')
  from priority_context cross join horizon_times$$,'P0001','SLOT_NOT_AVAILABLE',
  '3B: next recurrence also rejects direct booking');
reset role;
select is((select count(*) from public.recurring_lesson_occurrences where occurrence_date=(select gap_day+7 from priority_context)),
  0::bigint,'3B: next-date protection still requires no expansion');

-- Preserve status semantics: pause keeps existing occurrence claims, while the
-- new unexpanded-base check applies only to active series. End releases claims.
set local role authenticated;
select set_config('request.jwt.claim.sub',(select teacher::text from priority_context),true);
select lives_ok($$select public.set_recurring_lesson_series_status(series_id,'paused','Paused control')
  from priority_context$$,'3B: pause remains available');
reset role;
select is((select private.scheduling_slot_clear(student_b,teacher,expanded_target,expanded_target+interval '50 minutes')
  from priority_context cross join horizon_times),false,'3B: pause retains already-expanded priority as before');
select is((select private.scheduling_slot_clear(student_b,teacher,next_target,next_target+interval '50 minutes')
  from priority_context cross join horizon_times),true,'3B: inactive base alone does not gain new priority');
set local role authenticated;
select lives_ok($$select public.set_recurring_lesson_series_status(series_id,'active','Resume control')
  from priority_context$$,'3B: resume remains available');
reset role;
select is((select private.scheduling_slot_clear(student_b,teacher,next_target,next_target+interval '50 minutes')
  from priority_context cross join horizon_times),false,'3B: resumed active base is immediately authoritative');
set local role authenticated;
select lives_ok($$select public.set_recurring_lesson_series_status(series_id,'ended','Ended control')
  from priority_context$$,'3B: end remains available');
reset role;
select is((select private.scheduling_slot_clear(student_b,teacher,next_target,next_target+interval '50 minutes')
  from priority_context cross join horizon_times),true,'3B: ended base does not block future unexpanded slots');

select is((select count(*) from (values ('anon'),('authenticated'),('service_role')) roles(name)
  cross join (values
  ('private.scheduling_instance_slot_clear(uuid,uuid,timestamptz,timestamptz,uuid,uuid)'),
  ('private.unexpanded_fixed_priority_clear(uuid,uuid,timestamptz,timestamptz,uuid,date)')) helpers(signature)
  where has_function_privilege(roles.name,helpers.signature,'EXECUTE')),0::bigint,
  '3B security: no application role can directly execute the new private helpers');
select is((select count(*) from (values ('lessons'),('bookings'),('recurring_lesson_series'),
  ('recurring_lesson_occurrences')) tables(name) where has_table_privilege('authenticated','public.'||name,'INSERT')
  or has_table_privilege('authenticated','public.'||name,'UPDATE') or has_table_privilege('authenticated','public.'||name,'DELETE')),
  0::bigint,'3B security: no authenticated raw scheduling DML');
select is((select count(*) from pg_class where oid in('public.lessons'::regclass,'public.bookings'::regclass,
  'public.recurring_lesson_series'::regclass,'public.recurring_lesson_occurrences'::regclass) and not relrowsecurity),
  0::bigint,'3B security: RLS remains enabled');
select ok(position('private.lock_lesson_schedule_resources' in body)>0
  and position('private.lock_lesson_schedule_resources' in body)<position('private.flexible_slot_is_available' in body),
  '3B locking control: booking collision check remains inside schedule locks')
from (select pg_get_functiondef('public.create_lesson_booking(uuid,uuid,uuid,uuid,timestamptz,text,text,text)'::regprocedure) body) f;
select is((select count(*) from pg_proc where oid in(
  'public.create_recurring_lesson_series(uuid,uuid,uuid,uuid,smallint,time,text,smallint,date,date,text)'::regprocedure,
  'public.refresh_recurring_series_occurrences(uuid,date)'::regprocedure)
  and position('private.lock_lesson_schedule_resources' in prosrc)=0),0::bigint,
  '3B locking control: Fixed create and refresh use the same schedule-lock authority');
select * from finish();
rollback;
