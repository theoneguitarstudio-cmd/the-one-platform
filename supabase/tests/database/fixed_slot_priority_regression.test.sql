-- P1-3: real local PostgreSQL regressions; fixtures follow scheduling_booking_core.
-- All domain transitions use authenticated public RPCs. Owner reads diagnose
-- authority, and one rolled-back insert probes the existing GiST backstop.
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
create temporary table priority_results(name text primary key, result jsonb);
grant select,insert,update on priority_context,priority_results to authenticated;

-- SECURITY INVOKER: preserve the real actor and SQLSTATE, retaining successful
-- writes until the outer rollback so unsafe successes are observable.
create function pg_temp.priority_call(statement text) returns jsonb
language plpgsql security invoker as $$
declare value text; error_state text; error_message text; error_context text; error_constraint text;
begin
  execute statement into value;
  return jsonb_build_object('state','00000','value',value);
exception when others then
  get stacked diagnostics error_state=returned_sqlstate,error_message=message_text,
    error_context=pg_exception_context,error_constraint=constraint_name;
  return jsonb_build_object('state',error_state,'message',error_message,
    'context',error_context,'constraint',error_constraint);
end;
$$;

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
-- Fixed owner A deliberately has NO entitlement: priority is independent of credit.
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

-- R1: repeated refresh must leave existing priority and credit exactly intact.
create temporary table priority_before as select
  (select jsonb_agg(to_jsonb(o) order by o.id) from public.recurring_lesson_occurrences o) as occurrences,
  (select jsonb_agg(to_jsonb(s) order by s.id) from public.recurring_lesson_series s) as series,
  (select jsonb_agg(to_jsonb(l) order by l.id) from public.lesson_credit_ledger l) as ledger;
set local role authenticated;
insert into priority_results select 'R1',pg_temp.priority_call(
  'select public.refresh_recurring_series_occurrences(series_id,current_date+28) from pg_temp.priority_context');
select is((select result->>'state' from priority_results where name='R1'),'00000','R1: repeated refresh must succeed');
select diag('R1 actual: '||(select result::text from priority_results where name='R1'));
reset role;
select is((select jsonb_agg(to_jsonb(o) order by o.id) from public.recurring_lesson_occurrences o),
  (select occurrences from priority_before),'R1: no duplicate or changed occurrence/owner/state');
select is((select jsonb_agg(to_jsonb(s) order by s.id) from public.recurring_lesson_series s),
  (select series from priority_before),'R1: base owner unchanged');
select is((select jsonb_agg(to_jsonb(l) order by l.id) from public.lesson_credit_ledger l),
  (select ledger from priority_before),'R1: credit unchanged');
select is((select count(*) from public.lessons),0::bigint,'R1: refresh creates no Lesson');
select is((select count(*) from public.bookings),0::bigint,'R1: refresh creates no Booking');
select diag('R1 earliest candidate: '||(select jsonb_build_object('id',o.id,'date',o.occurrence_date,
  'status',o.status,'clear_with_no_ignore',private.scheduling_slot_clear(o.student_user_id,o.teacher_user_id,o.starts_at,o.ends_at,null,null),
  'clear_ignoring_self',private.scheduling_slot_clear(o.student_user_id,o.teacher_user_id,o.starts_at,o.ends_at,null,o.id))::text
  from public.recurring_lesson_occurrences o order by occurrence_date limit 1));

set local role authenticated;
select is((select public.materialize_recurring_lesson_occurrence(series_id,first_day,null,'priority-credit-required-control')
  from priority_context),null::uuid,'Control: missing credit records credit_required, not a Lesson');
insert into priority_results select 'R1-credit-required',pg_temp.priority_call(
  'select public.refresh_recurring_series_occurrences(series_id,current_date+28) from pg_temp.priority_context');
select is((select result->>'state' from priority_results where name='R1-credit-required'),'00000',
  'R1: credit_required occurrence must not conflict with its own refresh');
reset role;
select is((select status::text from public.recurring_lesson_occurrences where occurrence_date=(select first_day from priority_context)),
  'credit_required','R1: existing credit_required state retained');

-- Controls: existing priority blocks discovery AND booking; release is one date.
set local role authenticated;
select set_config('request.jwt.claim.sub',(select student_b::text from priority_context),true);
-- Resolve instants as owner below; no test grants to private production helpers.
reset role;
create temporary table priority_times as select first_day,
  private.resolve_scheduling_local_datetime(first_day,'20:00','Asia/Taipei') as first_start,
  private.resolve_scheduling_local_datetime(first_day+7,'20:00','Asia/Taipei') as next_start,
  private.resolve_scheduling_local_datetime(gap_day,'20:00','Asia/Taipei') as gap_start,
  private.resolve_scheduling_local_datetime(first_day+14,'20:00','Asia/Taipei') as overlap_start,
  private.resolve_scheduling_local_datetime(beyond_day,'20:00','Asia/Taipei') as beyond_start
from priority_context;
grant select on priority_times to authenticated;
set local role authenticated;
select is((select count(*) from priority_context c cross join priority_times t
  cross join lateral public.get_available_flexible_slots(c.teacher,c.flex_entitlement,t.first_start,t.first_start+interval '50 minutes') s),
  0::bigint,'Control: existing credit_required priority blocks Flexible discovery');
select throws_ok($$select public.create_lesson_booking(student_b,teacher,relationship_b,flex_entitlement,
  first_start,'Asia/Taipei','priority-existing-denied','Fixed priority control') from priority_context cross join priority_times$$,
  'P0001','SLOT_NOT_AVAILABLE','Control: existing priority rejects Flexible booking');
select set_config('request.jwt.claim.sub',(select teacher::text from priority_context),true);
select lives_ok($$select public.set_recurring_lesson_series_exception(series_id,first_day,'release',null,null,true,'One date release')
  from priority_context$$,'R5: release one occurrence through official RPC');
reset role;
select is((select jsonb_agg(to_jsonb(s) order by s.id) from public.recurring_lesson_series s),
  (select series from priority_before),'R5: one-off release never changes base rule');
select is((select status::text from public.recurring_lesson_occurrences where occurrence_date=(select first_day from priority_context)),
  'released','R5: released date loses priority');
set local role authenticated;
select set_config('request.jwt.claim.sub',(select student_b::text from priority_context),true);
select is((select count(*) from priority_context c cross join priority_times t
  cross join lateral public.get_available_flexible_slots(c.teacher,c.flex_entitlement,t.first_start,t.first_start+interval '50 minutes') s),
  1::bigint,'R5: released date is discoverable');
select lives_ok($$select public.create_lesson_booking(student_b,teacher,relationship_b,flex_entitlement,
  first_start,'Asia/Taipei','priority-released-allowed','Released occurrence control') from priority_context cross join priority_times$$,
  'R5: Flexible can book released date');
select is((select count(*) from priority_context c cross join priority_times t
  cross join lateral public.get_available_flexible_slots(c.teacher,c.flex_entitlement,t.next_start,t.next_start+interval '50 minutes') s),
  0::bigint,'R5: next recurring date remains blocked in discovery');
select throws_ok($$select public.create_lesson_booking(student_b,teacher,relationship_b,flex_entitlement,
  next_start,'Asia/Taipei','priority-next-week-denied','Next week control') from priority_context cross join priority_times$$,
  'P0001','SLOT_NOT_AVAILABLE','R5: next recurring date rejects Flexible booking');

-- Same-zone ownership is checked even beyond expansion.
select set_config('request.jwt.claim.sub',(select teacher::text from priority_context),true);
select throws_ok($$select public.create_recurring_lesson_series(student_b,teacher,relationship_b,null,
  3::smallint,'20:00'::time,'Asia/Taipei',50::smallint,first_day+7,first_day+7,'Duplicate Fixed owner') from priority_context$$,
  'P0001','RECURRING_SERIES_CONFLICT','Control: same Fixed slot has one owner inside expanded horizon');
select throws_ok($$select public.create_recurring_lesson_series(student_b,teacher,relationship_b,null,
  3::smallint,'20:00'::time,'Asia/Taipei',50::smallint,beyond_day,beyond_day,'Future duplicate owner') from priority_context$$,
  'P0001','RECURRING_SERIES_CONFLICT','Control: same-zone base rule prevents duplicate owner beyond horizon');

-- R2: grow the booking window through a legitimate RPC. This deterministically
-- opens a future date without editing the clock or deleting generated rows.
select lives_ok($$select public.set_teacher_scheduling_settings(teacher,'Asia/Taipei',0,60,10,'Expand booking horizon') from priority_context$$,
  'R2 fixture: officially expand horizon from 28 to 60 days');
reset role;
select is((select status::text from public.recurring_lesson_series where id=(select series_id from priority_context)),
  'active','R2: base Fixed rule remains active');
select ok((select gap_day>current_date+28 and gap_day<current_date+60 from priority_context),
  'R2: candidate lies beyond original expansion but inside new booking horizon');
select diag('R2 candidate: '||(select jsonb_build_object('date',gap_day,'utc',gap_start,
  'occurrences',(select count(*) from public.recurring_lesson_occurrences where occurrence_date=c.gap_day))::text
  from priority_context c cross join priority_times));
select is((select count(*) from public.lessons where starts_at=(select gap_start from priority_times)),0::bigint,
  'R2 fixture: candidate has no Lesson instance');
select is((select private.scheduling_slot_clear(student_b,teacher,gap_start,gap_start+interval '50 minutes')
  from priority_context cross join priority_times),false,'R2: active base priority must block collision check beyond expansion');
set local role authenticated;
select set_config('request.jwt.claim.sub',(select student_b::text from priority_context),true);
select is((select count(*) from priority_context c cross join priority_times t
  cross join lateral public.get_available_flexible_slots(c.teacher,c.flex_entitlement,t.gap_start,t.gap_start+interval '50 minutes') s),
  0::bigint,'R2: active base priority must block Flexible discovery beyond expansion');
insert into priority_results select 'R2',pg_temp.priority_call(
  $$select public.create_lesson_booking(student_b,teacher,relationship_b,flex_entitlement,
    gap_start,'Asia/Taipei','priority-horizon-denied','Future Fixed priority') from pg_temp.priority_context cross join pg_temp.priority_times$$);
select is((select result->>'message' from priority_results where name='R2'),'SLOT_NOT_AVAILABLE',
  'R2: Flexible booking must reject active unexpanded Fixed priority');
select diag('R2 booking actual: '||(select result::text from priority_results where name='R2'));
reset role;
select is((select count(*) from public.bookings where starts_at=(select gap_start from priority_times)),0::bigint,
  'R2: no Flexible Booking may steal future Fixed ownership');

-- C: settings.timezone must match new RPC input. Change it through the public
-- settings RPC; the existing Asia/Taipei base series retains its own timezone.
set local role authenticated;
select set_config('request.jwt.claim.sub',(select teacher::text from priority_context),true);
select lives_ok($$select public.set_teacher_scheduling_settings(teacher,'America/Los_Angeles',0,60,10,'Timezone ownership lifecycle')
  from priority_context$$,'C fixture: Teacher changes timezone through official RPC');
reset role;
select is((select timezone from public.recurring_lesson_series where id=(select series_id from priority_context)),
  'Asia/Taipei','C fixture: old series retains its original timezone');
select ok((select not (tstzrange(overlap_start,overlap_start+interval '50 minutes','[)') &&
  tstzrange(private.resolve_scheduling_local_datetime(c.first_day+14,'20:00','America/Los_Angeles'),
    private.resolve_scheduling_local_datetime(c.first_day+14,'20:00','America/Los_Angeles')+interval '50 minutes','[)'))
  from priority_context c cross join priority_times),'C1 fixture: same Wednesday 20:00 has no actual UTC overlap');
set local role authenticated;
insert into priority_results select 'C1',pg_temp.priority_call(
  $$select public.create_recurring_lesson_series(student_b,teacher,relationship_b,null,3::smallint,'20:00'::time,
    'America/Los_Angeles',50::smallint,first_day+14,first_day+14,'Nonoverlapping timezone owner') from pg_temp.priority_context$$);
select is((select result->>'state' from priority_results where name='C1'),'00000',
  'R3/C1: same local schedule with disjoint UTC must be allowed');
select diag('C1 actual: '||(select result::text from priority_results where name='C1'));
reset role;

-- Derive BOTH LA calendar date and wall time from the resolver's UTC instant.
-- No numeric offset or hand-written DST rule is used.
create temporary table priority_cross as
select 'expanded'::text as name,overlap_start as instant,
  (overlap_start at time zone 'America/Los_Angeles')::date as local_date,
  (overlap_start at time zone 'America/Los_Angeles')::time as local_time
from priority_times union all
select 'beyond',beyond_start,(beyond_start at time zone 'America/Los_Angeles')::date,
  (beyond_start at time zone 'America/Los_Angeles')::time from priority_times;
grant select on priority_cross to authenticated;
select ok(bool_and(local_time<>time '20:00' and
  private.resolve_scheduling_local_datetime(local_date,local_time,'America/Los_Angeles')=instant),
  'C2 fixture: different LA wall time resolves to exactly the Taipei UTC instant') from priority_cross;
select diag('C2 resolved candidates: '||(select jsonb_agg(to_jsonb(x))::text from priority_cross x));
set local role authenticated;
insert into priority_results select 'C2-expanded',pg_temp.priority_call(
  $$select public.create_recurring_lesson_series(student_b,teacher,relationship_b,null,
    extract(dow from local_date)::smallint,local_time,'America/Los_Angeles',50::smallint,
    local_date,local_date,'Overlapping UTC expanded owner') from pg_temp.priority_context cross join pg_temp.priority_cross where name='expanded'$$);
select is((select result->>'message' from priority_results where name='C2-expanded'),'RECURRING_SERIES_CONFLICT',
  'R4/C2: overlapping UTC inside expanded horizon must reject');
select diag('C2 expanded protection path: '||(select result::text from priority_results where name='C2-expanded'));
insert into priority_results select 'C2-beyond',pg_temp.priority_call(
  $$select public.create_recurring_lesson_series(student_b,teacher,relationship_b,null,
    extract(dow from local_date)::smallint,local_time,'America/Los_Angeles',50::smallint,
    local_date,local_date,'Overlapping UTC future owner') from pg_temp.priority_context cross join pg_temp.priority_cross where name='beyond'$$);
select is((select result->>'message' from priority_results where name='C2-beyond'),'RECURRING_SERIES_CONFLICT',
  'C2: overlapping UTC base ownership must reject even beyond expansion');
select diag('C2 beyond actual: '||(select result::text from priority_results where name='C2-beyond'));
reset role;
select is((select count(*) from public.recurring_lesson_series s cross join priority_context c cross join priority_cross x
  where x.name='beyond' and s.teacher_user_id=c.teacher and s.status='active'
    and x.local_date between s.effective_from and coalesce(s.effective_until,'infinity'::date)
    and private.resolve_scheduling_local_datetime(x.local_date,s.local_start_time,s.timezone)=x.instant),
  1::bigint,'C2: unexpanded real UTC slot must have exactly one base owner');

-- Independently prove the occurrence GiST backstop; owner fixture insertion is
-- intentionally not evidence that public prechecks are correct.
select throws_ok($$insert into public.recurring_lesson_occurrences(
  series_id,student_user_id,teacher_user_id,occurrence_date,starts_at,ends_at,status)
  select o.series_id,o.student_user_id,o.teacher_user_id,o.occurrence_date+1,o.starts_at,o.ends_at,'planned'
  from public.recurring_lesson_occurrences o where o.series_id=(select series_id from priority_context)
    and o.occurrence_date=(select first_day+7 from priority_context)$$,
  '23P01',null,'Control: GiST rejects actual overlapping occurrence rows');

-- A narrowly scoped DST control for ownership comparison, using the existing
-- resolver in winter and summer rather than assuming a fixed LA offset.
select ok(bool_and(not(tstzrange(taipei,taipei+interval '50 minutes','[)') &&
  tstzrange(la,la+interval '50 minutes','[)'))),
  'DST control: equal LA/Taipei local schedules remain distinct UTC ownership in winter and summer')
from (select private.resolve_scheduling_local_datetime(d,'20:00','Asia/Taipei') taipei,
  private.resolve_scheduling_local_datetime(d,'20:00','America/Los_Angeles') la
  from (values(make_date(extract(year from current_date)::integer+1,1,15)),
    (make_date(extract(year from current_date)::integer+1,7,15))) dates(d)) instants;

select * from finish();
rollback;
