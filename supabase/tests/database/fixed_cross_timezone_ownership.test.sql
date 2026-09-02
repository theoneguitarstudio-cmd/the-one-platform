-- P1-3C: real authenticated RPC controls. Each case has independent participants;
-- all fixtures roll back. Helpers only remove repetitive fixture setup.
begin;
select no_plan();
create function pg_temp.uid(c integer,n integer) returns uuid language sql immutable as $$
  select ('65000000-0000-0000-0000-'||lpad((c*100+n)::text,12,'0'))::uuid;
$$;
insert into auth.users(id,email)
select pg_temp.uid(c,n),'cross-zone-'||c||'-'||n||'@example.invalid'
from generate_series(1,18) c cross join generate_series(1,4) n;
insert into public.user_roles(user_id,role)
select pg_temp.uid(c,n),'teacher' from generate_series(1,18) c cross join generate_series(3,4) n;
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,
  teaching_modes,trial_price_twd,default_meeting_provider,default_meeting_url)
select pg_temp.uid(c,n),'cross-zone-'||c||'-'||n,'Timezone fixture','active',true,
  array['online']::public.teaching_mode[],500,'manual_google_meet','https://meet.google.com/abc-defg-hij'
from generate_series(1,18) c cross join generate_series(3,4) n;
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode)
select pg_temp.uid(c,10+(t-3)*2+s),pg_temp.uid(c,s),pg_temp.uid(c,t),'active','online'
from generate_series(1,18) c cross join generate_series(1,2) s cross join generate_series(3,4) t;
create temporary table dates as select
  current_date+14 as near_day,current_date+77 as far_day,
  make_date(extract(year from current_date)::integer+1,1,6) as winter,
  make_date(extract(year from current_date)::integer+1,7,7) as summer;
grant select on dates to authenticated;
create function pg_temp.claim(c integer,s integer,t integer,d date,wall time,tz text,last_day date)
returns uuid language plpgsql security invoker as $$
begin
  perform set_config('request.jwt.claim.sub',pg_temp.uid(c,t)::text,true);
  perform public.set_teacher_scheduling_settings(pg_temp.uid(c,t),tz,0,14,10,'Cross timezone fixture');
  return public.create_recurring_lesson_series(pg_temp.uid(c,s),pg_temp.uid(c,t),
    pg_temp.uid(c,10+(t-3)*2+s),null,extract(dow from d)::smallint,wall,tz,50::smallint,d,last_day,
    'Cross timezone ownership');
end;
$$;
create temporary table claims(c integer,id uuid);
grant select,insert on claims to authenticated;

set local role authenticated;
select lives_ok($$insert into claims select 1,pg_temp.claim(1,1,3,near_day,'20:00','Asia/Taipei',near_day) from dates$$,'C1: initial Taipei Teacher owner');
select lives_ok($$select pg_temp.claim(1,2,3,near_day,'20:00','America/Los_Angeles',near_day) from dates$$,'C1: same local schedule, different UTC Teacher ALLOW');

select lives_ok($$insert into claims select 2,pg_temp.claim(2,1,3,far_day,'20:00','Asia/Taipei',far_day) from dates$$,'C2: unexpanded Teacher base owner');
reset role;
select is((select count(*) from public.recurring_lesson_occurrences where teacher_user_id=pg_temp.uid(2,3)),0::bigint,'C2: no expanded occurrence exists');
create temporary table cross_dates as
select far_day,instant,(instant at time zone 'America/Los_Angeles')::date as la_day,
  (instant at time zone 'America/Los_Angeles')::time as la_time
from dates cross join lateral (select private.resolve_scheduling_local_datetime(far_day,'20:00','Asia/Taipei') instant) x;
grant select on cross_dates to authenticated;
set local role authenticated;
select throws_ok($$select pg_temp.claim(2,2,3,la_day,la_time,'America/Los_Angeles',la_day) from cross_dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','C2: different local schedule, UTC overlap Teacher REJECT beyond expansion');
reset role;
select is((select count(*) from public.recurring_lesson_series where teacher_user_id=pg_temp.uid(2,3)),1::bigint,'C2: exactly one base owner');
select is((select timezone from public.recurring_lesson_series where id=(select id from claims where c=2)),'Asia/Taipei','Series timezone is retained');
select is((select count(*) from public.audit_logs where actor_user_id=pg_temp.uid(2,3) and action='recurring_series.created'),1::bigint,'Rejected claim adds no creation audit');
set local role authenticated;
select lives_ok($$select pg_temp.claim(3,1,3,far_day,'20:00','Asia/Taipei',far_day) from dates$$,'C3: first Student owner');
select lives_ok($$select pg_temp.claim(3,1,4,far_day,'20:00','America/Los_Angeles',far_day) from dates$$,'C3: same Student, same local schedule, disjoint UTC ALLOW');
select lives_ok($$select pg_temp.claim(4,1,3,far_day,'20:00','Asia/Taipei',far_day) from dates$$,'C4: first Student overlap owner');
select throws_ok($$select pg_temp.claim(4,1,4,la_day,la_time,'America/Los_Angeles',la_day) from cross_dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','C4: same Student across Teachers, UTC overlap REJECT');
select lives_ok($$select pg_temp.claim(5,1,3,far_day,'20:00','Asia/Taipei',far_day) from dates$$,'C5: first partial overlap owner');
select throws_ok($$select pg_temp.claim(5,2,3,la_day,la_time+interval '30 minutes','America/Los_Angeles',la_day) from cross_dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','C5: partial UTC duration overlap REJECT');
select lives_ok($$select pg_temp.claim(6,1,3,far_day,'20:00','Asia/Taipei',far_day) from dates$$,'C6: first adjacent owner');
select lives_ok($$select pg_temp.claim(6,2,3,la_day,la_time+interval '50 minutes','America/Los_Angeles',la_day) from cross_dates$$,
  'C6: half-open UTC boundary touch ALLOW');
select lives_ok($$select pg_temp.claim(7,1,3,far_day,'20:00','Asia/Taipei',far_day) from dates$$,'C7: first limited effective range');
select lives_ok($$select pg_temp.claim(7,2,3,far_day+7,'20:00','Asia/Taipei',far_day+7) from dates$$,'C7: disjoint effective dates ALLOW');

-- Future January/July, same weekday for each weekly pair. LA 04:00 conflicts
-- with Taipei 20:00 in winter, but resolves one hour earlier during summer.
select lives_ok($$select pg_temp.claim(8,1,3,winter,'20:00','Asia/Taipei',winter) from dates$$,'C8: winter Taipei owner');
select throws_ok($$select pg_temp.claim(8,2,3,winter,'04:00','America/Los_Angeles',winter) from dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','C8: winter UTC overlap REJECT');
select lives_ok($$select pg_temp.claim(9,1,3,summer,'20:00','Asia/Taipei',summer) from dates$$,'C8: summer Taipei owner');
select lives_ok($$select pg_temp.claim(9,2,3,summer,'04:00','America/Los_Angeles',summer) from dates$$,'C8: summer UTC disjoint ALLOW');
select lives_ok($$select pg_temp.claim(10,1,3,summer,'20:00','Asia/Taipei',summer+210) from dates$$,'C8: weekly Taipei series across DST seasons');
select throws_ok($$select pg_temp.claim(10,2,3,summer,'04:00','America/Los_Angeles',summer+210) from dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','C8: first date disjoint but later winter overlaps: REJECT');
reset role;
select is(private.resolve_scheduling_local_datetime(winter,'04:00','America/Los_Angeles'),
  private.resolve_scheduling_local_datetime(winter,'20:00','Asia/Taipei'),'Winter resolver: LA 04:00 and Taipei 20:00 both 12:00Z') from dates;
select is(private.resolve_scheduling_local_datetime(summer,'04:00','America/Los_Angeles'),
  private.resolve_scheduling_local_datetime(summer,'20:00','Asia/Taipei')-interval '1 hour','Summer resolver: LA 04:00 = 11:00Z, Taipei 20:00 = 12:00Z') from dates;
select diag('DST resolver UTC results: '||jsonb_build_object(
  'winter',private.resolve_scheduling_local_datetime(winter,'04:00','America/Los_Angeles'),
  'summer',private.resolve_scheduling_local_datetime(summer,'04:00','America/Los_Angeles'))::text) from dates;

-- Existing logical-date exceptions supersede base priority.
set local role authenticated;
select lives_ok($$insert into claims select 11,pg_temp.claim(11,1,3,near_day,'20:00','Asia/Taipei',near_day+7) from dates$$,'Release: first concrete owner');
select lives_ok($$select public.set_recurring_lesson_series_exception(id,near_day,'release',null,null,true,'Release date control') from claims cross join dates where c=11$$,'Release through official exception RPC');
select lives_ok($$select pg_temp.claim(11,2,3,near_day,'20:00','Asia/Taipei',near_day) from dates$$,'Released date: candidate usage ALLOW');
select throws_ok($$select pg_temp.claim(11,2,3,near_day+7,'20:00','Asia/Taipei',near_day+7) from dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','Next recurrence stays BLOCKED');

select lives_ok($$insert into claims select 12,pg_temp.claim(12,1,3,far_day,'20:00','Asia/Taipei',far_day) from dates$$,'Paused: first unexpanded owner');
select lives_ok($$select public.set_recurring_lesson_series_status(id,'paused','Pause preserves ownership') from claims where c=12$$,'Pause using official lifecycle');
select throws_ok($$select pg_temp.claim(12,2,3,la_day,la_time,'America/Los_Angeles',la_day) from cross_dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','Paused base ownership stays protected in create precheck');

-- Date-line rollover: disjoint local effective dates can own the same UTC slot.
select lives_ok($$select pg_temp.claim(13,1,3,far_day,'00:30','Pacific/Kiritimati',far_day) from dates$$,'Date line: initial owner');
select throws_ok($$select pg_temp.claim(13,2,3,far_day-1,'00:30','Pacific/Honolulu',far_day-1) from dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','Different local weekdays/dates, same UTC interval REJECT');

-- Far future intersection is examined directly without generating years of rows.
select lives_ok($$select pg_temp.claim(14,1,3,far_day,'20:00','Asia/Taipei',null) from dates$$,'Long range: open-ended first owner');
select throws_ok($$select pg_temp.claim(14,2,3,far_day+7*260,'20:00','Asia/Taipei',far_day+7*260) from dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','Five years beyond expansion: pair intersection still protected');
reset role;
select is((select count(*) from public.recurring_lesson_occurrences where teacher_user_id=pg_temp.uid(14,3)),0::bigint,'Long-range check creates no speculative occurrences');

create temporary table replacement as select near_day,
  private.resolve_scheduling_local_datetime(near_day+1,'20:00','Asia/Taipei') instant from dates;
grant select on replacement to authenticated;
set local role authenticated;
select lives_ok($$insert into claims select 15,pg_temp.claim(15,1,3,near_day,'20:00','Asia/Taipei',near_day) from dates$$,'Reschedule: initial concrete owner');
select lives_ok($$select public.set_recurring_lesson_series_exception(id,near_day,'reschedule',instant,instant+interval '50 minutes',false,'Move concrete priority')
  from claims cross join replacement where c=15$$,'Reschedule outside original effective range through official RPC');
select lives_ok($$select pg_temp.claim(15,2,3,near_day,'20:00','Asia/Taipei',near_day) from dates$$,'Rescheduled date: original base time ALLOW');
select throws_ok($$select pg_temp.claim(15,2,3,near_day+1,'20:00','Asia/Taipei',near_day+1) from dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','Rescheduled persisted interval remains authoritative outside base effective range');
select lives_ok($$insert into claims select 16,pg_temp.claim(16,1,3,near_day,'20:00','Asia/Taipei',near_day+7) from dates$$,'Skip: initial concrete owner');
select lives_ok($$select public.set_recurring_lesson_series_exception(id,near_day,'skip_holiday',null,null,false,'Skip this logical date')
  from claims cross join dates where c=16$$,'Skip through official exception RPC');
select lives_ok($$select pg_temp.claim(16,2,3,near_day,'20:00','Asia/Taipei',near_day) from dates$$,'Skipped date: candidate ALLOW');
select throws_ok($$select pg_temp.claim(16,2,3,near_day+7,'20:00','Asia/Taipei',near_day+7) from dates$$,
  'P0001','RECURRING_SERIES_CONFLICT','Skip does not release next recurring date');
select lives_ok($$insert into claims select 17,pg_temp.claim(17,1,3,current_date,'20:00','Asia/Taipei',current_date+35)$$,'End: already-effective series');
select lives_ok($$select public.set_recurring_lesson_series_status(id,'ended','End future ownership') from claims where c=17$$,'End through official lifecycle');
select lives_ok($$select pg_temp.claim(17,2,3,current_date+7,'20:00','Asia/Taipei',current_date+7)$$,'Ended series does not retain future base priority');
reset role;
select is((select count(*) from public.bookings where teacher_user_id::text like '65000000-%'),0::bigint,'Ownership checks create no bookings');
select is((select count(*) from public.lesson_credit_reservations where beneficiary_user_id::text like '65000000-%'),0::bigint,'Ownership checks reserve no credit');
select ok((select prosecdef and pg_get_userbyid(proowner)='postgres' and proconfig=array['search_path=""']
  from pg_proc where oid='private.recurring_ownership_clear(uuid,uuid,smallint,time,text,smallint,date,date)'::regprocedure),
  'Private helper SECURITY DEFINER, postgres owner, empty search_path');
select ok(not has_function_privilege(r,'private.recurring_ownership_clear(uuid,uuid,smallint,time,text,smallint,date,date)','EXECUTE'),
  r||' cannot execute private ownership helper') from unnest(array['anon','authenticated','service_role']) r;
select ok((select pg_get_functiondef(oid) like '%lock_lesson_schedule_resources%recurring_ownership_clear%insert into public.recurring_lesson_series%'
  from pg_proc where oid='public.create_recurring_lesson_series(uuid,uuid,uuid,uuid,smallint,time,text,smallint,date,date,text)'::regprocedure),
  'Create authority locks before ownership check and insertion');
select * from finish();
rollback;
