begin;
select no_plan();

create temporary table epic6_context (
  name text primary key,
  id uuid,
  test_date date,
  instant timestamptz
);
grant select, insert, update on pg_temp.epic6_context to authenticated;

insert into auth.users(id,email) values
  ('60000000-0000-0000-0000-000000000001','epic6-student-a@example.invalid'),
  ('60000000-0000-0000-0000-000000000002','epic6-student-b@example.invalid'),
  ('60000000-0000-0000-0000-000000000003','epic6-teacher-a@example.invalid'),
  ('60000000-0000-0000-0000-000000000004','epic6-teacher-b@example.invalid'),
  ('60000000-0000-0000-0000-000000000005','epic6-admin@example.invalid');

update public.profiles set display_name=case user_id
  when '60000000-0000-0000-0000-000000000001' then 'Epic6 Student A'
  when '60000000-0000-0000-0000-000000000002' then 'Epic6 Student B'
  when '60000000-0000-0000-0000-000000000003' then 'Epic6 Teacher A'
  when '60000000-0000-0000-0000-000000000004' then 'Epic6 Teacher B'
  else 'Epic6 Admin' end
where user_id::text like '60000000-%';

insert into public.user_roles(user_id,role) values
  ('60000000-0000-0000-0000-000000000003','teacher'),
  ('60000000-0000-0000-0000-000000000004','teacher'),
  ('60000000-0000-0000-0000-000000000005','admin');

insert into public.teacher_profiles(
  user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,
  default_meeting_provider,default_meeting_url
) values
  ('60000000-0000-0000-0000-000000000003','epic6-teacher-a','Fake teacher A','active',true,
    array['online']::public.teaching_mode[],500,'manual_google_meet','https://meet.google.com/abc-defg-hij'),
  ('60000000-0000-0000-0000-000000000004','epic6-teacher-b','Fake teacher B','active',true,
    array['online']::public.teaching_mode[],500,'manual_zoom','https://zoom.us/j/123456789');

insert into public.student_teacher_relationships(
  id,student_user_id,teacher_user_id,relationship_status,preferred_mode
) values
  ('60000000-0000-0000-0000-000000000010','60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003','active','online'),
  ('60000000-0000-0000-0000-000000000011','60000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000003','active','online'),
  ('60000000-0000-0000-0000-000000000012','60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000004','active','online');

insert into public.entitlements(
  id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,starts_at,expires_at,
  product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes
) values
  ('60000000-0000-0000-0000-000000000020','60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003','lesson_package','active',now()-interval '1 day',now()+interval '6 months','Flexible A','flexible',50),
  ('60000000-0000-0000-0000-000000000021','60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003','lesson_package','active',now()-interval '1 day',now()+interval '6 months','Fixed A','fixed',50),
  ('60000000-0000-0000-0000-000000000022','60000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000003','lesson_package','active',now()-interval '1 day',now()+interval '6 months','Flexible B','both',50),
  ('60000000-0000-0000-0000-000000000023','60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000004','lesson_package','active',now()-interval '1 day',now()+interval '6 months','Teacher B scope','both',50),
  ('60000000-0000-0000-0000-000000000024','60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003','lesson_package','active',now()-interval '1 day',now()+interval '6 months','No credit fixed','fixed',50);

insert into public.lesson_credit_ledger(
  entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code
) values
  ('60000000-0000-0000-0000-000000000020','60000000-0000-0000-0000-000000000001','allocation',8,'epic6-flex-a-allocation','test_fixture'),
  ('60000000-0000-0000-0000-000000000021','60000000-0000-0000-0000-000000000001','allocation',8,'epic6-fixed-a-allocation','test_fixture'),
  ('60000000-0000-0000-0000-000000000022','60000000-0000-0000-0000-000000000002','allocation',8,'epic6-flex-b-allocation','test_fixture'),
  ('60000000-0000-0000-0000-000000000023','60000000-0000-0000-0000-000000000001','allocation',8,'epic6-teacher-b-allocation','test_fixture');

insert into pg_temp.epic6_context(name,test_date,instant)
select 'slot_day',d,(d::timestamp+time '20:00') at time zone 'Asia/Taipei'
from (select current_date + (7 + ((1-extract(dow from current_date)::integer+7)%7)) d) q;

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.set_teacher_scheduling_settings(
  '60000000-0000-0000-0000-000000000003','Asia/Taipei',0,90,10,'Epic 6 test settings')$$,
  'Teacher A configures scheduling settings');
select lives_ok($$select public.create_teacher_availability_rule(
  '60000000-0000-0000-0000-000000000003',1::smallint,'19:00'::time,'23:30'::time,
  'Asia/Taipei',current_date,current_date+90,'Epic 6 Monday availability')$$,
  'Teacher A creates recurring availability');
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.set_teacher_scheduling_settings(
  '60000000-0000-0000-0000-000000000004','Asia/Taipei',0,90,10,'Epic 6 test settings')$$,
  'Teacher B configures own settings');
select lives_ok($$select public.create_teacher_availability_rule(
  '60000000-0000-0000-0000-000000000004',1::smallint,'19:00'::time,'23:30'::time,
  'Asia/Taipei',current_date,current_date+90,'Epic 6 Monday availability')$$,
  'Teacher B creates own availability');
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.set_teacher_scheduling_settings(
  '60000000-0000-0000-0000-000000000004','UTC',0,90,10,'Cross teacher mutation')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Teacher A cannot configure Teacher B');

reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select * from public.get_available_flexible_slots(
  '60000000-0000-0000-0000-000000000003','60000000-0000-0000-0000-000000000020',now(),now()+interval '7 days')$$,
  '42501',null,'Anonymous cannot discover private scheduling slots');
select throws_ok($$select public.create_lesson_booking(
  '60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000010','60000000-0000-0000-0000-000000000020',
  now()+interval '7 days','Asia/Taipei','epic6-anon-booking-key','Anonymous booking')$$,
  '42501',null,'Anonymous cannot create a booking');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000001',true);
select ok((select count(*)>0 from public.get_available_flexible_slots(
  '60000000-0000-0000-0000-000000000003','60000000-0000-0000-0000-000000000020',
  (select instant-interval '1 hour' from pg_temp.epic6_context where name='slot_day'),
  (select instant+interval '3 hours' from pg_temp.epic6_context where name='slot_day'))),
  'Student sees eligible Teacher slots');
select lives_ok($$select public.create_lesson_booking(
  '60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000010','60000000-0000-0000-0000-000000000020',
  (select instant from pg_temp.epic6_context where name='slot_day'),'Asia/Taipei',
  'epic6-flex-booking-0001','Student flexible booking')$$,'Flexible booking succeeds');
select lives_ok($$select public.create_lesson_booking(
  '60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000010','60000000-0000-0000-0000-000000000020',
  (select instant from pg_temp.epic6_context where name='slot_day'),'Asia/Taipei',
  'epic6-flex-booking-0001','Student flexible booking')$$,'Flexible booking retry is idempotent');
select throws_ok($$select public.create_lesson_booking(
  '60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000010','60000000-0000-0000-0000-000000000021',
  (select instant from pg_temp.epic6_context where name='slot_day'),'Asia/Taipei',
  'epic6-flex-booking-0001','Changed idempotency payload')$$,
  'P0001','BOOKING_ALREADY_EXISTS','Booking key cannot be replayed with another entitlement');
reset role;

insert into pg_temp.epic6_context(name,id)
select 'flex_booking',id from public.bookings where idempotency_key='epic6-flex-booking-0001';
select is((select count(*) from public.bookings where idempotency_key='epic6-flex-booking-0001'),1::bigint,
  'Idempotency creates exactly one Booking');
select is((select count(*) from public.lessons l join public.bookings b on b.lesson_id=l.id where b.id=(select id from pg_temp.epic6_context where name='flex_booking')),1::bigint,
  'Flexible Booking creates exactly one Lesson');
select is((select count(*) from public.lesson_credit_reservations r join public.bookings b on b.credit_reservation_id=r.id where b.id=(select id from pg_temp.epic6_context where name='flex_booking')),1::bigint,
  'Flexible Booking creates exactly one shared credit reservation');
select is((select count(*) from public.lesson_credit_ledger l join public.bookings b on b.credit_reservation_id=l.reservation_id where b.id=(select id from pg_temp.epic6_context where name='flex_booking') and l.entry_type='reservation'),1::bigint,
  'Flexible Booking writes one reservation to the Epic 5 ledger');
select is((select count(*) from public.lessons where lesson_type='trial' and student_user_id::text like '60000000-%'),0::bigint,
  'Scheduling never creates a Trial Lesson');

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.get_own_scheduling_bookings()),0::bigint,
  'Student B cannot read Student A booking DTO');
select throws_ok($$select public.cancel_lesson_booking(
  (select id from pg_temp.epic6_context where name='flex_booking'),'released','Cross student cancel')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Student B cannot cancel Student A booking');
select throws_ok($$select public.create_lesson_booking(
  '60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000010','60000000-0000-0000-0000-000000000020',
  (select instant+interval '1 hour' from pg_temp.epic6_context where name='slot_day'),'Asia/Taipei',
  'epic6-cross-student-0001','Cross student booking')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Student B cannot book as Student A');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.cancel_lesson_booking(
  (select id from pg_temp.epic6_context where name='flex_booking'),'manual_review_required','Forged credit policy')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Student cannot choose a privileged cancellation credit outcome');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.create_teacher_availability_exception(
  '60000000-0000-0000-0000-000000000003','unavailable',
  (select instant+interval '2 hours' from pg_temp.epic6_context where name='slot_day'),
  (select instant+interval '3 hours' from pg_temp.epic6_context where name='slot_day'),
  'Teacher unavailable test')$$,'Teacher creates an unavailable exception');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.get_available_flexible_slots(
  '60000000-0000-0000-0000-000000000003','60000000-0000-0000-0000-000000000020',
  (select instant+interval '2 hours' from pg_temp.epic6_context where name='slot_day'),
  (select instant+interval '3 hours' from pg_temp.epic6_context where name='slot_day'))),0::bigint,
  'Unavailable exception removes public-to-student availability');
reset role;

select throws_ok($$select private.resolve_scheduling_local_datetime('2026-03-08','02:30','America/New_York')$$,
  'P0001','NONEXISTENT_LOCAL_TIME','DST spring-forward nonexistent local time is rejected');
select throws_ok($$select private.resolve_scheduling_local_datetime('2026-11-01','01:30','America/New_York')$$,
  'P0001','AMBIGUOUS_LOCAL_TIME','DST fall-back ambiguous local time is rejected');
select is(private.resolve_scheduling_local_datetime('2026-06-01','20:00','Asia/Taipei'),
  '2026-06-01 12:00:00+00'::timestamptz,'Unambiguous local wall time resolves exactly');

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.create_recurring_lesson_series(
  '60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000010','60000000-0000-0000-0000-000000000021',
  1::smallint,'21:00'::time,'Asia/Taipei',50::smallint,
  (select test_date from pg_temp.epic6_context where name='slot_day'),
  (select test_date+35 from pg_temp.epic6_context where name='slot_day'),'Fixed weekly series test')$$,
  'Teacher creates a Fixed weekly series');
reset role;
insert into pg_temp.epic6_context(name,id)
select 'fixed_series',id from public.recurring_lesson_series where student_user_id='60000000-0000-0000-0000-000000000001';
select is((select count(*) from public.recurring_lesson_occurrences where series_id=(select id from pg_temp.epic6_context where name='fixed_series')),6::bigint,
  'Fixed series creates only bounded priority claims');
select is((select count(*) from public.bookings where recurring_series_id=(select id from pg_temp.epic6_context where name='fixed_series')),0::bigint,
  'Series creation does not eagerly create Bookings');
select is((select count(*) from public.lessons where starts_at=(select instant+interval '1 hour' from pg_temp.epic6_context where name='slot_day')),0::bigint,
  'Series creation does not eagerly create Lessons');
select throws_ok($$set local role authenticated; select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true); select public.create_recurring_lesson_series(
  '60000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000011','60000000-0000-0000-0000-000000000022',
  1::smallint,'21:20'::time,'Asia/Taipei',50::smallint,
  (select test_date from pg_temp.epic6_context where name='slot_day'),
  (select test_date+35 from pg_temp.epic6_context where name='slot_day'),'Conflicting series test')$$,
  'P0001','RECURRING_SERIES_CONFLICT','Overlapping Teacher Fixed series is rejected');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.materialize_recurring_lesson_occurrence(
  (select id from pg_temp.epic6_context where name='fixed_series'),
  (select test_date from pg_temp.epic6_context where name='slot_day'),
  '60000000-0000-0000-0000-000000000021','epic6-fixed-materialize-0001')$$,
  'Fixed occurrence materializes with explicit eligible entitlement');
select lives_ok($$select public.materialize_recurring_lesson_occurrence(
  (select id from pg_temp.epic6_context where name='fixed_series'),
  (select test_date from pg_temp.epic6_context where name='slot_day'),
  '60000000-0000-0000-0000-000000000021','epic6-fixed-materialize-0001')$$,
  'Fixed occurrence materialization retry is idempotent');
reset role;
select is((select count(*) from public.bookings where recurring_series_id=(select id from pg_temp.epic6_context where name='fixed_series') and occurrence_date=(select test_date from pg_temp.epic6_context where name='slot_day')),1::bigint,
  'Fixed occurrence creates exactly one Booking');
select is((select count(*) from public.lesson_credit_reservations r join public.bookings b on b.credit_reservation_id=r.id where b.recurring_series_id=(select id from pg_temp.epic6_context where name='fixed_series')),1::bigint,
  'Fixed occurrence creates exactly one credit reservation');

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select is(public.materialize_recurring_lesson_occurrence(
  (select id from pg_temp.epic6_context where name='fixed_series'),
  (select test_date+7 from pg_temp.epic6_context where name='slot_day'),
  '60000000-0000-0000-0000-000000000024','epic6-fixed-no-credit-001'),null::uuid,
  'Missing credit leaves occurrence for explicit recovery');
reset role;
select is((select status from public.recurring_lesson_occurrences where series_id=(select id from pg_temp.epic6_context where name='fixed_series') and occurrence_date=(select test_date+7 from pg_temp.epic6_context where name='slot_day')),
  'credit_required'::public.recurring_occurrence_status,'No-credit occurrence is marked credit_required');
select is((select count(*) from public.bookings where recurring_series_id=(select id from pg_temp.epic6_context where name='fixed_series') and occurrence_date=(select test_date+7 from pg_temp.epic6_context where name='slot_day')),0::bigint,
  'Credit shortage creates no partial Booking');

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.set_recurring_lesson_series_exception(
  (select id from pg_temp.epic6_context where name='fixed_series'),
  (select test_date+14 from pg_temp.epic6_context where name='slot_day'),
  'skip_holiday',null,null,true,'Skip local holiday')$$,'Teacher releases one Fixed occurrence');
select lives_ok($$select public.set_recurring_lesson_series_status(
  (select id from pg_temp.epic6_context where name='fixed_series'),'paused','Pause weekly lessons')$$,
  'Teacher pauses the Fixed series');
reset role;
select is((select status from public.recurring_lesson_series where id=(select id from pg_temp.epic6_context where name='fixed_series')),
  'paused'::public.recurring_series_status,'Series state is paused');
select is((select status from public.recurring_lesson_occurrences where series_id=(select id from pg_temp.epic6_context where name='fixed_series') and occurrence_date=(select test_date+14 from pg_temp.epic6_context where name='slot_day')),
  'skipped'::public.recurring_occurrence_status,'Per-occurrence release preserves history');

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.epic6_context where name='flex_booking'),
  (select instant-interval '1 hour' from pg_temp.epic6_context where name='slot_day'),
  'Asia/Taipei','Student reschedule test')$$,'Participant reschedules atomically');
reset role;
select is((select status from public.bookings where id=(select id from pg_temp.epic6_context where name='flex_booking')),
  'rescheduled'::public.booking_status,'Booking is rescheduled');
select is((select l.booking_id=b.id from public.bookings b join public.lesson_credit_reservations l on l.id=b.credit_reservation_id where b.id=(select id from pg_temp.epic6_context where name='flex_booking')),
  true,'Reschedule retains the original reservation-to-booking link');

update public.lessons set starts_at=now()-interval '1 hour',ends_at=now()-interval '10 minutes'
where id=(select lesson_id from public.bookings where id=(select id from pg_temp.epic6_context where name='flex_booking'));
update public.bookings set starts_at=now()-interval '1 hour',ends_at=now()-interval '10 minutes'
where id=(select id from pg_temp.epic6_context where name='flex_booking');
insert into public.lesson_credit_ledger(
  entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code
) values(
  '60000000-0000-0000-0000-000000000020','60000000-0000-0000-0000-000000000001',
  'adjustment',-7,'epic6-exhaustion-fixture-adjustment','test_fixture'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.epic6_context where name='flex_booking'),'Visible progress','Private note',
  'Summary','Next goal','Homework')$$,'Assigned Teacher completes the booking');
select lives_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.epic6_context where name='flex_booking'),'Visible progress','Private note',
  'Summary','Next goal','Homework')$$,'Completion retry is idempotent');
reset role;
select is((select status from public.bookings where id=(select id from pg_temp.epic6_context where name='flex_booking')),
  'completed'::public.booking_status,'Booking completion is durable');
select is((select r.status from public.lesson_credit_reservations r join public.bookings b on b.credit_reservation_id=r.id where b.id=(select id from pg_temp.epic6_context where name='flex_booking')),
  'consumed'::public.lesson_credit_reservation_status,'Completion consumes the shared credit reservation');
select is((select count(*) from public.lesson_records lr join public.bookings b on b.lesson_id=lr.lesson_id where b.id=(select id from pg_temp.epic6_context where name='flex_booking')),1::bigint,
  'Completion creates exactly one Lesson record');
select is((select status from public.entitlements where id='60000000-0000-0000-0000-000000000020'),
  'exhausted'::public.entitlement_status,
  'Scheduling completion uses the shared credit core exhausted-state semantics');
select is((select reason_code from public.lesson_credit_ledger ledger
  join public.bookings booking on booking.credit_reservation_id=ledger.reservation_id
  where booking.id=(select id from pg_temp.epic6_context where name='flex_booking')
    and ledger.entry_type='consumption'),'lesson_completed'::text,
  'Scheduling completion records the lesson_completed credit reason code');

insert into pg_temp.epic6_context(name,id)
select 'removed_role_booking',id from public.bookings
where recurring_series_id=(select id from pg_temp.epic6_context where name='fixed_series') limit 1;
delete from public.user_roles where user_id='60000000-0000-0000-0000-000000000003' and role='teacher';
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.epic6_context where name='flex_booking'),'Visible','Private','Summary','Goal','Homework')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Removed Teacher role cannot complete a Booking');
select throws_ok($$select public.cancel_lesson_booking(
  (select id from pg_temp.epic6_context where name='removed_role_booking'),
  'released','Removed Teacher cancellation')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Removed Teacher role cannot cancel a Booking');
reset role;
insert into public.user_roles(user_id,role) values('60000000-0000-0000-0000-000000000003','teacher');

update public.teacher_profiles set teaching_status='paused'
where user_id='60000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.set_teacher_scheduling_settings(
  '60000000-0000-0000-0000-000000000003','Asia/Taipei',0,90,10,'Paused mutation')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot mutate scheduling settings');
select throws_ok($$select public.create_teacher_availability_rule(
  '60000000-0000-0000-0000-000000000003',2::smallint,'19:00'::time,'20:00'::time,
  'Asia/Taipei',current_date,current_date+30,'Paused availability rule')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot create availability rules');
select throws_ok($$select public.create_teacher_availability_exception(
  '60000000-0000-0000-0000-000000000003','unavailable',now()+interval '20 days',
  now()+interval '20 days 1 hour','Paused availability exception')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot create availability exceptions');
select throws_ok($$select public.create_recurring_lesson_series(
  '60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000010','60000000-0000-0000-0000-000000000021',
  2::smallint,'21:00'::time,'Asia/Taipei',50::smallint,current_date+7,current_date+28,
  'Paused recurring series')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot create recurring series');
select throws_ok($$select public.refresh_recurring_series_occurrences(
  (select id from pg_temp.epic6_context where name='fixed_series'),current_date+60)$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot refresh recurring occurrences');
select throws_ok($$select public.set_recurring_lesson_series_status(
  (select id from pg_temp.epic6_context where name='fixed_series'),'paused','Paused status mutation')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot manage recurring series');
select throws_ok($$select public.set_recurring_lesson_series_exception(
  (select id from pg_temp.epic6_context where name='fixed_series'),
  (select test_date+21 from pg_temp.epic6_context where name='slot_day'),
  'skip_holiday',null,null,true,'Paused series exception')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot create series exceptions');
select throws_ok($$select public.materialize_recurring_lesson_occurrence(
  (select id from pg_temp.epic6_context where name='fixed_series'),
  (select test_date+7 from pg_temp.epic6_context where name='slot_day'),
  '60000000-0000-0000-0000-000000000021','epic6-paused-materialize')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot materialize recurring occurrences');
select throws_ok($$select public.create_lesson_booking(
  '60000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000011','60000000-0000-0000-0000-000000000022',
  now()+interval '14 days','Asia/Taipei','epic6-paused-booking','Paused Teacher booking')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot create assigned Bookings');
select throws_ok($$select public.cancel_lesson_booking(
  (select id from pg_temp.epic6_context where name='removed_role_booking'),'released','Paused cancel')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot cancel assigned Bookings');
select throws_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.epic6_context where name='removed_role_booking'),now()+interval '30 days',
  'Asia/Taipei','Paused reschedule')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot reschedule assigned Bookings');
select throws_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.epic6_context where name='removed_role_booking'),
  'Visible','Private','Summary','Goal','Homework')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Paused Teacher cannot complete assigned Bookings');
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000002',true);
select throws_ok($$select * from public.get_available_flexible_slots(
  '60000000-0000-0000-0000-000000000003','60000000-0000-0000-0000-000000000022',
  now()+interval '7 days',now()+interval '14 days')$$,
  'P0001','SLOT_NOT_AVAILABLE','Paused Teacher exposes no new booking slots');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000005',true);
select lives_ok($$select public.set_teacher_scheduling_settings(
  '60000000-0000-0000-0000-000000000003','Asia/Taipei',0,90,10,'Admin paused Teacher override')$$,
  'Active Admin mutation authority is independent of Teacher teaching status');
reset role;

update public.teacher_profiles set teaching_status='draft'
where user_id='60000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.set_teacher_scheduling_settings(
  '60000000-0000-0000-0000-000000000003','Asia/Taipei',0,90,10,'Draft mutation')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Draft Teacher cannot execute scheduling mutations');
reset role;

update public.teacher_profiles set teaching_status='inactive'
where user_id='60000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.set_teacher_scheduling_settings(
  '60000000-0000-0000-0000-000000000003','Asia/Taipei',0,90,10,'Inactive mutation')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Inactive Teacher cannot execute scheduling mutations');
reset role;
update public.teacher_profiles set teaching_status='active'
where user_id='60000000-0000-0000-0000-000000000003';

update public.profiles set account_status='suspended'
where user_id='60000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.set_teacher_scheduling_settings(
  '60000000-0000-0000-0000-000000000003','Asia/Taipei',0,90,10,'Suspended mutation')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Suspended Teacher cannot mutate scheduling settings');
select throws_ok($$select * from public.get_teacher_availability_configuration()$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Suspended Teacher cannot read scheduling DTOs');
reset role;
update public.profiles set account_status='active'
where user_id='60000000-0000-0000-0000-000000000003';

select is((select count(*) from (values
  ('teacher_scheduling_settings'),('teacher_availability_rules'),('teacher_availability_exceptions'),
  ('recurring_lesson_series'),('recurring_lesson_occurrences'),
  ('recurring_lesson_series_exceptions'),('bookings')) t(name)
  where not (select relrowsecurity from pg_class where oid=('public.'||t.name)::regclass)),0::bigint,
  'All Epic 6 tables have RLS enabled');
select is((select count(*) from (values
  ('teacher_scheduling_settings'),('teacher_availability_rules'),('teacher_availability_exceptions'),
  ('recurring_lesson_series'),('recurring_lesson_occurrences'),
  ('recurring_lesson_series_exceptions'),('bookings')) t(name)
  where has_table_privilege('anon','public.'||t.name,'SELECT')
     or has_table_privilege('authenticated','public.'||t.name,'INSERT')
     or has_table_privilege('service_role','public.'||t.name,'UPDATE')),0::bigint,
  'Raw Epic 6 table privileges are revoked');
select is(has_function_privilege('anon','public.create_lesson_booking(uuid,uuid,uuid,uuid,timestamptz,text,text,text)','EXECUTE'),false,
  'Anonymous has no Booking RPC grant');
select is((select count(*) from (values
  ('private.reserve_lesson_credit_core(uuid,uuid,text,uuid,text,uuid)'),
  ('private.release_lesson_credit_core(uuid,text,uuid,jsonb,boolean)'),
  ('private.consume_lesson_credit_core(uuid,uuid,text,uuid,jsonb)'),
  ('private.bind_lesson_credit_reservation_booking_core(uuid,uuid,uuid,uuid,uuid)')
) core(signature) where has_function_privilege('service_role',core.signature,'EXECUTE')),0::bigint,
  'Service role cannot invoke any private shared credit core');
select is((select count(*) from pg_proc where pronamespace='public'::regnamespace
  and proname in('reserve_lesson_credit','release_lesson_credit','consume_lesson_credit')
  and pg_get_functiondef(oid) not like '%_lesson_credit_core%'),0::bigint,
  'Every Epic 5 public credit RPC delegates to the shared authoritative core');
select is((select count(*) from pg_proc where pronamespace='public'::regnamespace
  and proname in('create_lesson_booking','cancel_lesson_booking','materialize_recurring_lesson_occurrence',
    'complete_lesson_booking')
  and pg_get_functiondef(oid) like '%insert into public.lesson_credit_ledger%'),0::bigint,
  'Scheduling orchestration contains no direct shared ledger insert');
select is((select count(*) from pg_proc where pronamespace='public'::regnamespace
  and proname in('set_teacher_scheduling_settings','create_teacher_availability_rule',
    'create_teacher_availability_exception','create_lesson_booking','cancel_lesson_booking',
    'reschedule_lesson_booking','create_recurring_lesson_series','refresh_recurring_series_occurrences',
    'set_recurring_lesson_series_status','set_recurring_lesson_series_exception',
    'materialize_recurring_lesson_occurrence','complete_lesson_booking')
  and case proname
    when 'cancel_lesson_booking' then not (
      pg_get_functiondef(oid) like '%private.cancel_makeup_lesson_booking_core%'
      and pg_get_functiondef(oid) like '%private.cancel_ordinary_lesson_booking_authority%')
    when 'reschedule_lesson_booking' then not (
      pg_get_functiondef(oid) like '%private.reschedule_makeup_lesson_booking_core%'
      and pg_get_functiondef(oid) like '%private.reschedule_ordinary_lesson_booking_authority%')
    when 'complete_lesson_booking' then not (
      pg_get_functiondef(oid) like '%private.complete_makeup_lesson_booking_core%'
      and pg_get_functiondef(oid) like '%private.complete_ordinary_lesson_booking_authority%')
    else pg_get_functiondef(oid) not like '%scheduling_teacher_authorized%'
  end),0::bigint,
  'Every Teacher scheduling mutation entry point delegates to the active-Teacher authorization helper');
select is((select count(*) from pg_proc where pronamespace='public'::regnamespace
  and proname in('create_lesson_booking','cancel_lesson_booking','reschedule_lesson_booking',
    'create_recurring_lesson_series','materialize_recurring_lesson_occurrence','complete_lesson_booking')
  and proconfig<>array['search_path=""']::text[]),0::bigint,
  'Security-definer mutation RPCs pin an empty search_path');
select is((select count(*) from public.entitlements e where e.source_order_id in(select id from public.trial_orders)),0::bigint,
  'Epic 6 does not convert Trial Orders into lesson-package entitlements');

select * from finish();
rollback;
