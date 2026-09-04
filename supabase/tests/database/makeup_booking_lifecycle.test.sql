begin;
select no_plan();

create temporary table makeup_booking_context(
  name text primary key,
  id uuid,
  test_date date,
  instant timestamptz,
  amount bigint
);
grant select,insert,update on pg_temp.makeup_booking_context to authenticated;

insert into auth.users(id,email) values
  ('69000000-0000-0000-0000-000000000001','makeup-booking-student-a@example.invalid'),
  ('69000000-0000-0000-0000-000000000002','makeup-booking-student-b@example.invalid'),
  ('69000000-0000-0000-0000-000000000003','makeup-booking-teacher-a@example.invalid'),
  ('69000000-0000-0000-0000-000000000004','makeup-booking-teacher-b@example.invalid'),
  ('69000000-0000-0000-0000-000000000005','makeup-booking-admin@example.invalid');

insert into public.user_roles(user_id,role) values
  ('69000000-0000-0000-0000-000000000003','teacher'),
  ('69000000-0000-0000-0000-000000000004','teacher'),
  ('69000000-0000-0000-0000-000000000005','admin');

insert into public.teacher_profiles(
  user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,
  default_meeting_provider,default_meeting_url
) values
  ('69000000-0000-0000-0000-000000000003','makeup-booking-teacher-a','Fixture A',
    'active',true,array['online']::public.teaching_mode[],500,
    'manual_google_meet','https://meet.google.com/abc-defg-hij'),
  ('69000000-0000-0000-0000-000000000004','makeup-booking-teacher-b','Fixture B',
    'active',true,array['online']::public.teaching_mode[],500,
    'manual_zoom','https://zoom.us/j/123456789');

insert into public.student_teacher_relationships(
  id,student_user_id,teacher_user_id,relationship_status,preferred_mode
) values
  ('69000000-0000-0000-0000-000000000010','69000000-0000-0000-0000-000000000001',
    '69000000-0000-0000-0000-000000000003','active','online'),
  ('69000000-0000-0000-0000-000000000011','69000000-0000-0000-0000-000000000002',
    '69000000-0000-0000-0000-000000000003','active','online'),
  ('69000000-0000-0000-0000-000000000012','69000000-0000-0000-0000-000000000001',
    '69000000-0000-0000-0000-000000000004','active','online');

insert into public.entitlements(
  id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,starts_at,expires_at,
  product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes
) values
  ('69000000-0000-0000-0000-000000000020','69000000-0000-0000-0000-000000000001',
    '69000000-0000-0000-0000-000000000003','lesson_package','expired',
    now()-interval '2 months',now()-interval '1 day','Expired origin package','flexible',50),
  ('69000000-0000-0000-0000-000000000021','69000000-0000-0000-0000-000000000001',
    '69000000-0000-0000-0000-000000000003','lesson_package','active',
    now()-interval '1 day',now()+interval '6 months','Fixed priority fixture','fixed',50);

insert into public.lesson_credit_ledger(
  entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code
) values
  ('69000000-0000-0000-0000-000000000020','69000000-0000-0000-0000-000000000001',
    'allocation',3,'makeup-booking-origin-allocation','test_fixture'),
  ('69000000-0000-0000-0000-000000000021','69000000-0000-0000-0000-000000000001',
    'allocation',3,'makeup-booking-fixed-allocation','test_fixture');

insert into pg_temp.makeup_booking_context(name,test_date,instant)
select 'monday',d,(d::timestamp+time '20:00') at time zone 'Asia/Taipei'
from (select current_date+(7+((1-extract(dow from current_date)::integer+7)%7)) d) q;

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select public.set_teacher_scheduling_settings(
  '69000000-0000-0000-0000-000000000003','Asia/Taipei',0,90,10,'Makeup test settings');
select public.create_teacher_availability_rule(
  '69000000-0000-0000-0000-000000000003',1::smallint,'19:00','23:30',
  'Asia/Taipei',current_date,current_date+90,'Makeup Monday availability');
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000004',true);
select public.set_teacher_scheduling_settings(
  '69000000-0000-0000-0000-000000000004','Asia/Taipei',0,90,10,'Overlap test settings');
select public.create_teacher_availability_rule(
  '69000000-0000-0000-0000-000000000004',1::smallint,'19:00','23:30',
  'Asia/Taipei',current_date,current_date+90,'Overlap Monday availability');
reset role;

insert into public.lessons(
  id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,meeting_provider,meeting_url
)
select
  ('69000000-0000-0000-0001-'||lpad(n::text,12,'0'))::uuid,
  '69000000-0000-0000-0000-000000000001','69000000-0000-0000-0000-000000000003',
  '69000000-0000-0000-0000-000000000010','flexible','online',
  now()-(n+10)*interval '1 day',now()-(n+10)*interval '1 day'+interval '50 minutes',
  50,'Asia/Taipei','completed','manual_google_meet','https://meet.google.com/abc-defg-hij'
from generate_series(1,8) n;

insert into public.makeup_rights(
  id,student_user_id,origin_lesson_id,origin_teacher_user_id,current_teacher_user_id,
  origin_entitlement_id,source,source_operation_key,status,valid_until,reason,created_by
)
select
  ('69000000-0000-0000-0002-'||lpad(n::text,12,'0'))::uuid,
  '69000000-0000-0000-0000-000000000001',
  ('69000000-0000-0000-0001-'||lpad(n::text,12,'0'))::uuid,
  '69000000-0000-0000-0000-000000000003',
  '69000000-0000-0000-0000-000000000003',
  '69000000-0000-0000-0000-000000000020',
  'teacher_cancellation','makeup-booking-right-'||lpad(n::text,4,'0'),
  'available',now()+interval '60 days','Makeup booking fixture',
  '69000000-0000-0000-0000-000000000003'
from generate_series(1,8) n;

insert into pg_temp.makeup_booking_context(name,amount) values
  ('ledger_before',(select count(*) from public.lesson_credit_ledger)),
  ('reservations_before',(select count(*) from public.lesson_credit_reservations)),
  ('rights_before',(select count(*) from public.makeup_rights));

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.create_makeup_lesson_booking(
  '69000000-0000-0000-0002-000000000001','69000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000010',
  (select instant from pg_temp.makeup_booking_context where name='monday'),
  'Asia/Taipei','makeup-booking-main-0001','Book valid Makeup Right')$$,
  'C1 available Right creates a Makeup booking');
select lives_ok($$select public.create_makeup_lesson_booking(
  '69000000-0000-0000-0002-000000000001','69000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000010',
  (select instant from pg_temp.makeup_booking_context where name='monday'),
  'Asia/Taipei','makeup-booking-main-0001','Book valid Makeup Right')$$,
  'C19 booking retry is idempotent');
reset role;

insert into pg_temp.makeup_booking_context(name,id)
select 'main_booking',id from public.bookings where idempotency_key='makeup-booking-main-0001';
select is((select status from public.makeup_rights where id='69000000-0000-0000-0002-000000000001'),
  'reserved'::public.makeup_right_status,'C2 booking reserves the same Right');
select ok((select b.makeup_right_id='69000000-0000-0000-0002-000000000001'
  and o.booking_id=b.id and o.lesson_id=b.lesson_id
  from public.bookings b join public.makeup_right_operations o
    on o.makeup_right_id=b.makeup_right_id and o.operation_type='reserve'
  where b.id=(select id from pg_temp.makeup_booking_context where name='main_booking')),
  'C3 Booking, Lesson, Right, and operation are linked');
select is((select l.lesson_type from public.lessons l join public.bookings b on b.lesson_id=l.id
  where b.id=(select id from pg_temp.makeup_booking_context where name='main_booking')),
  'makeup'::public.lesson_type,'C4 Lesson type is makeup');
select is((select credit_reservation_id from public.bookings
  where id=(select id from pg_temp.makeup_booking_context where name='main_booking')),
  null::uuid,'C5 Makeup booking creates no ordinary reservation');
select is((select count(*) from public.lesson_credit_reservations),
  (select amount from pg_temp.makeup_booking_context where name='reservations_before'),
  'C6 Makeup booking does not mutate ordinary reservations');
select ok((select e.status='expired' from public.entitlements e where e.id='69000000-0000-0000-0000-000000000020'),
  'C7 expired origin entitlement does not block a valid Right');

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.create_makeup_lesson_booking(
  '69000000-0000-0000-0002-000000000002','69000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000010',
  now()+interval '61 days','Asia/Taipei','makeup-booking-expired-001','After Right validity')$$,
  'P0001','MAKEUP_RIGHT_EXPIRED','C8 lesson scheduled after valid_until is rejected');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select public.create_recurring_lesson_series(
  '69000000-0000-0000-0000-000000000001','69000000-0000-0000-0000-000000000003',
  '69000000-0000-0000-0000-000000000010','69000000-0000-0000-0000-000000000021',
  1::smallint,'21:00','Asia/Taipei',50::smallint,
  (select test_date from pg_temp.makeup_booking_context where name='monday'),
  (select test_date+21 from pg_temp.makeup_booking_context where name='monday'),
  'Fixed priority Makeup test');
reset role;
insert into pg_temp.makeup_booking_context(name,id)
select 'fixed_series',id from public.recurring_lesson_series
where student_user_id='69000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.create_makeup_lesson_booking(
  '69000000-0000-0000-0002-000000000003','69000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000010',
  (select instant+interval '1 hour' from pg_temp.makeup_booking_context where name='monday'),
  'Asia/Taipei','makeup-booking-fixed-block','Fixed priority must win')$$,
  'P0001','SLOT_NOT_AVAILABLE','C9 active Fixed Priority blocks Makeup booking');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select public.set_recurring_lesson_series_exception(
  (select id from pg_temp.makeup_booking_context where name='fixed_series'),
  (select test_date+7 from pg_temp.makeup_booking_context where name='monday'),
  'skip_holiday',null,null,true,'Release occurrence for Makeup');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.create_makeup_lesson_booking(
  '69000000-0000-0000-0002-000000000004','69000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000010',
  (select instant+interval '7 days 1 hour' from pg_temp.makeup_booking_context where name='monday'),
  'Asia/Taipei','makeup-booking-fixed-release','Released Fixed occurrence')$$,
  'C10 released Fixed occurrence allows Makeup booking');
reset role;
insert into pg_temp.makeup_booking_context(name,id)
select 'released_booking',id from public.bookings
where idempotency_key='makeup-booking-fixed-release';

insert into public.lessons(
  id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,meeting_provider,meeting_url
) values
  ('69000000-0000-0000-0003-000000000001','69000000-0000-0000-0000-000000000001',
   '69000000-0000-0000-0000-000000000004','69000000-0000-0000-0000-000000000012',
   'flexible','online',
   (select instant+interval '14 days' from pg_temp.makeup_booking_context where name='monday'),
   (select instant+interval '14 days 50 minutes' from pg_temp.makeup_booking_context where name='monday'),
   50,'Asia/Taipei','scheduled','manual_zoom','https://zoom.us/j/123456789'),
  ('69000000-0000-0000-0003-000000000002','69000000-0000-0000-0000-000000000002',
   '69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000011',
   'flexible','online',
   (select instant+interval '14 days 2 hours' from pg_temp.makeup_booking_context where name='monday'),
   (select instant+interval '14 days 2 hours 50 minutes' from pg_temp.makeup_booking_context where name='monday'),
   50,'Asia/Taipei','scheduled','manual_google_meet','https://meet.google.com/abc-defg-hij');

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.create_makeup_lesson_booking(
  '69000000-0000-0000-0002-000000000005','69000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000010',
  (select instant+interval '14 days' from pg_temp.makeup_booking_context where name='monday'),
  'Asia/Taipei','makeup-student-overlap-001','Student overlap')$$,
  'P0001','SLOT_NOT_AVAILABLE','C11 Student overlap is rejected');
select throws_ok($$select public.create_makeup_lesson_booking(
  '69000000-0000-0000-0002-000000000006','69000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000010',
  (select instant+interval '14 days 2 hours' from pg_temp.makeup_booking_context where name='monday'),
  'Asia/Taipei','makeup-teacher-overlap-001','Teacher overlap')$$,
  'P0001','SLOT_NOT_AVAILABLE','C12 Teacher overlap is rejected');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select public.create_makeup_lesson_booking(
  '69000000-0000-0000-0002-000000000007','69000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000010',
  (select instant+interval '21 days' from pg_temp.makeup_booking_context where name='monday'),
  'Asia/Taipei','makeup-cancel-student-001','Student cancellation fixture');
reset role;
insert into pg_temp.makeup_booking_context(name,id)
select 'student_cancel_booking',id from public.bookings
where idempotency_key='makeup-cancel-student-001';
set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select public.cancel_lesson_booking(
  (select id from pg_temp.makeup_booking_context where name='student_cancel_booking'),
  'released','Timely Makeup cancellation');
reset role;
select is((select status from public.makeup_rights where id='69000000-0000-0000-0002-000000000007'),
  'available'::public.makeup_right_status,'C15 timely cancellation restores the same Right');
select is((select count(*) from public.makeup_rights),
  (select amount from pg_temp.makeup_booking_context where name='rights_before'),
  'C16 timely cancellation creates no new Makeup Right');

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select public.create_makeup_lesson_booking(
  '69000000-0000-0000-0002-000000000008','69000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000003','69000000-0000-0000-0000-000000000010',
  (select instant+interval '21 days 2 hours' from pg_temp.makeup_booking_context where name='monday'),
  'Asia/Taipei','makeup-cancel-teacher-001','Teacher cancellation fixture');
reset role;
insert into pg_temp.makeup_booking_context(name,id)
select 'teacher_cancel_booking',id from public.bookings
where idempotency_key='makeup-cancel-teacher-001';
set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.cancel_lesson_booking(
  (select id from pg_temp.makeup_booking_context where name='teacher_cancel_booking'),
  'released','Teacher cancels Makeup','teacher_caused')$$,'Teacher cancels Makeup booking');
select lives_ok($$select public.cancel_lesson_booking(
  (select id from pg_temp.makeup_booking_context where name='teacher_cancel_booking'),
  'released','Teacher cancels Makeup','teacher_caused')$$,'Teacher cancellation retry is stable');
reset role;
select ok((select status='available' from public.makeup_rights
  where id='69000000-0000-0000-0002-000000000008')
  and (select count(*) from public.makeup_rights)=
    (select amount from pg_temp.makeup_booking_context where name='rights_before'),
  'C17 Teacher cancellation preserves exactly one Right value');

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.makeup_booking_context where name='released_booking'),
  (select instant+interval '7 days 2 hours' from pg_temp.makeup_booking_context where name='monday'),
  'Asia/Taipei','Reschedule Makeup booking')$$,'Makeup booking reschedules');
reset role;
select is((select makeup_right_id from public.bookings
  where idempotency_key='makeup-booking-fixed-release'),
  '69000000-0000-0000-0002-000000000004'::uuid,'C18 reschedule preserves the same Right');

update public.lessons set starts_at=now()-interval '1 hour',ends_at=now()-interval '10 minutes'
where id=(select lesson_id from public.bookings
  where id=(select id from pg_temp.makeup_booking_context where name='main_booking'));
update public.bookings set starts_at=now()-interval '1 hour',ends_at=now()-interval '10 minutes'
where id=(select id from pg_temp.makeup_booking_context where name='main_booking');

set local role authenticated;
select set_config('request.jwt.claim.sub','69000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.makeup_booking_context where name='main_booking'),
  'Visible notes','Private notes','Performance','Next goal','Homework')$$,
  'Makeup completion succeeds');
select lives_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.makeup_booking_context where name='main_booking'),
  'Visible notes','Private notes','Performance','Next goal','Homework')$$,
  'C20 repeated completion is idempotent');
select throws_ok($$select public.consume_makeup_right(
  '69000000-0000-0000-0002-000000000004','teacher-direct-consume-0001',
  'Teacher may not consume outside completion')$$,
  '42501','UNAUTHORIZED_MAKEUP_ACTION','Teacher cannot arbitrarily consume a Right');
reset role;
select ok((select status='used' from public.makeup_rights
  where id='69000000-0000-0000-0002-000000000001')
  and (select status='completed' from public.bookings
    where id=(select id from pg_temp.makeup_booking_context where name='main_booking'))
  and (select l.status='completed' from public.lessons l join public.bookings b on b.lesson_id=l.id
    where b.id=(select id from pg_temp.makeup_booking_context where name='main_booking')),
  'C13 completion uses the Right and completes Booking and Lesson');
select is((select count(*) from public.lesson_credit_ledger),
  (select amount from pg_temp.makeup_booking_context where name='ledger_before'),
  'C14 completion adds no ordinary credit consumption');
select is((select count(*) from public.makeup_right_operations
  where makeup_right_id='69000000-0000-0000-0002-000000000001'
    and operation_type='consume'),1::bigint,
  'C20 completion retry cannot double-consume');

select * from finish();
rollback;
