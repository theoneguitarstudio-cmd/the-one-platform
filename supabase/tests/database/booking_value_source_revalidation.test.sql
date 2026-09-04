begin;
select no_plan();
\set p16_fixture_include true
\ir entitlement_revoke_booking_consistency_fixture.sql
\unset p16_fixture_include

insert into public.teacher_availability_exceptions(
  teacher_user_id,exception_kind,starts_at,ends_at,reason,created_by
) values
  ('7b000000-0000-0000-0000-000000000002','opening',
   (current_date+15)::timestamp+time '08:00',(current_date+15)::timestamp+time '23:30',
   'P1-6B next-day opening','7b000000-0000-0000-0000-000000000002'),
  ('7b000000-0000-0000-0000-000000000002','opening',
   (current_date+21)::timestamp+time '08:00',(current_date+21)::timestamp+time '23:30',
   'P1-6B fixed reschedule opening','7b000000-0000-0000-0000-000000000002');

insert into public.entitlements(
  id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,starts_at,expires_at,
  product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes
) values(
  '7d000000-0000-0000-0000-000000000020','7b000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000002','lesson_package','active',
  now()-interval '1 day',now()+interval '20 days','P1-6B expiring package','both',50
);
insert into public.lesson_credit_ledger(
  entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code
) values(
  '7d000000-0000-0000-0000-000000000020','7b000000-0000-0000-0000-000000000001',
  'allocation',2,'p16b-expiring-allocation','fixture'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
insert into pg_temp.p16_ids values(
  'valid_ordinary_booking',public.create_lesson_booking(
    '7b000000-0000-0000-0000-000000000001','7b000000-0000-0000-0000-000000000002',
    '7b000000-0000-0000-0000-000000000010','7d000000-0000-0000-0000-000000000020',
    (current_date+14)::timestamp+time '20:00','UTC',
    'p16b-valid-ordinary-0001','P1-6B valid ordinary booking'));
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select public.refresh_recurring_series_occurrences(
  '7b000000-0000-0000-0000-000000000044',current_date+30);
insert into pg_temp.p16_ids values(
  'valid_fixed_booking',public.materialize_recurring_lesson_occurrence(
    '7b000000-0000-0000-0000-000000000044',current_date+21,
    '7b000000-0000-0000-0000-000000000020','p16b-fixed-materialize-0001'));
reset role;

insert into public.makeup_rights(
  id,student_user_id,origin_lesson_id,origin_teacher_user_id,current_teacher_user_id,
  source,source_operation_key,status,valid_until,reason,created_by
) values
  ('7d000000-0000-0000-0000-000000000030','7b000000-0000-0000-0000-000000000001',
   (select lesson_id from public.bookings where id=(select id from p16_ids where name='future_a_booking')),
   '7b000000-0000-0000-0000-000000000002','7b000000-0000-0000-0000-000000000002',
   'admin_compensation','p16b-revoked-right-create','available',now()+interval '30 days',
   'P1-6B revoked Right fixture','7b000000-0000-0000-0000-000000000003'),
  ('7d000000-0000-0000-0000-000000000031','7b000000-0000-0000-0000-000000000001',
   (select lesson_id from public.bookings where id=(select id from p16_ids where name='future_b_booking')),
   '7b000000-0000-0000-0000-000000000002','7b000000-0000-0000-0000-000000000002',
   'admin_compensation','p16b-expired-right-create','available',now()+interval '30 days',
   'P1-6B expired Right fixture','7b000000-0000-0000-0000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
insert into pg_temp.p16_ids values(
  'revoked_makeup_booking',public.create_makeup_lesson_booking(
    '7d000000-0000-0000-0000-000000000030',
    '7b000000-0000-0000-0000-000000000001','7b000000-0000-0000-0000-000000000002',
    '7b000000-0000-0000-0000-000000000010',
    (current_date+14)::timestamp+time '19:00','UTC',
    'p16b-revoked-makeup-0001','P1-6B revoked Makeup booking'));
insert into pg_temp.p16_ids values(
  'expired_makeup_booking',public.create_makeup_lesson_booking(
    '7d000000-0000-0000-0000-000000000031',
    '7b000000-0000-0000-0000-000000000001','7b000000-0000-0000-0000-000000000002',
    '7b000000-0000-0000-0000-000000000010',
    (current_date+14)::timestamp+time '21:00','UTC',
    'p16b-expired-makeup-0001','P1-6B expired Makeup booking'));
reset role;

-- B4/B5: a valid Flexible ordinary Booking revalidates and reschedules.
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.p16_ids where name='valid_ordinary_booking'),
  (current_date+15)::timestamp+time '20:00','UTC','P1-6B valid ordinary reschedule')$$,
  'B4 valid ordinary Booking reschedules');
reset role;
select ok((select b.status='rescheduled' and b.starts_at=(current_date+15)::timestamp+time '20:00'
  and l.starts_at=b.starts_at and r.status='reserved'
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
  where b.id=(select id from p16_ids where name='valid_ordinary_booking')),
  'B4 valid ordinary source remains reserved and bound after reschedule');
create temporary table p16b_valid_schedule as
select to_jsonb(b) booking,to_jsonb(l) lesson
from public.bookings b join public.lessons l on l.id=b.lesson_id
where b.id=(select id from p16_ids where name='valid_ordinary_booking');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.p16_ids where name='valid_ordinary_booking'),
  (current_date+25)::timestamp+time '20:00','UTC','P1-6B after expiry')$$,
  'P0001','ENTITLEMENT_EXPIRED','B3 target after Entitlement expiry is rejected');
reset role;
select ok((select to_jsonb(b)=(select booking from p16b_valid_schedule)
    and to_jsonb(l)=(select lesson from p16b_valid_schedule)
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  where b.id=(select id from p16_ids where name='valid_ordinary_booking')),
  'B5 failed reschedule preserves the old Booking and Lesson schedule exactly');

-- Fixed and Flexible ordinary sources share the same validator.
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.p16_ids where name='valid_fixed_booking'),
  (current_date+21)::timestamp+time '20:00','UTC','P1-6B valid Fixed reschedule')$$,
  'Valid Fixed ordinary Booking uses the shared source validator');
reset role;

-- B1/B6: defense in depth for a manually stale released Reservation.
update public.lesson_credit_reservations
set status='released',released_at=now(),updated_at=now()
where id=(select credit_reservation_id from public.bookings
  where id=(select id from p16_ids where name='future_a_booking'));
create temporary table p16b_released_schedule as
select to_jsonb(b) booking,to_jsonb(l) lesson
from public.bookings b join public.lessons l on l.id=b.lesson_id
where b.id=(select id from p16_ids where name='future_a_booking');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.p16_ids where name='future_a_booking'),
  (current_date+15)::timestamp+time '12:00','UTC','P1-6B released source')$$,
  'P0001','CREDIT_ALREADY_RELEASED','B1 released ordinary Reservation rejects reschedule');
reset role;
select ok((select to_jsonb(b)=(select booking from p16b_released_schedule)
    and to_jsonb(l)=(select lesson from p16b_released_schedule)
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  where b.id=(select id from p16_ids where name='future_a_booking')),
  'B1 released-source reschedule failure preserves schedule');
update public.lessons set starts_at=now()-interval '1 hour',ends_at=now()-interval '10 minutes'
where id=(select lesson_id from public.bookings where id=(select id from p16_ids where name='future_a_booking'));
update public.bookings set starts_at=now()-interval '1 hour',ends_at=now()-interval '10 minutes'
where id=(select id from p16_ids where name='future_a_booking');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.p16_ids where name='future_a_booking'),
  'Visible','Private','Summary','Goal','Homework')$$,
  'P0001','CREDIT_ALREADY_RELEASED','B6 released ordinary Reservation rejects completion explicitly');
reset role;
select ok((select b.status='confirmed' and l.status='scheduled'
    and not exists(select 1 from public.lesson_records lr where lr.lesson_id=l.id)
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  where b.id=(select id from p16_ids where name='future_a_booking')),
  'B6 rejected completion mutates no Booking, Lesson, or Lesson Record');

-- B2/B7/B14: a stale revoked explicit source cannot fall back to another package.
update public.entitlements
set status='revoked',revoked_at=now(),revoked_by='7b000000-0000-0000-0000-000000000003',
  revoked_reason='P1-6B manual stale state',updated_at=now()
where id='7b000000-0000-0000-0000-000000000021';
create temporary table p16b_revoked_binding as
select b.credit_reservation_id,to_jsonb(b) booking,to_jsonb(l) lesson
from public.bookings b join public.lessons l on l.id=b.lesson_id
where b.id=(select id from p16_ids where name='future_b_booking');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.p16_ids where name='future_b_booking'),
  (current_date+15)::timestamp+time '14:00','UTC','P1-6B revoked source')$$,
  'P0001','ENTITLEMENT_NOT_ACTIVE','B2 revoked Entitlement rejects reschedule');
reset role;
select ok((select to_jsonb(b)=(select booking from p16b_revoked_binding)
    and to_jsonb(l)=(select lesson from p16b_revoked_binding)
    and b.credit_reservation_id=(select credit_reservation_id from p16b_revoked_binding)
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  where b.id=(select id from p16_ids where name='future_b_booking')),
  'B2/B14 revoked source failure preserves schedule and explicit Reservation identity');
update public.lessons set starts_at=now()-interval '2 hours',ends_at=now()-interval '70 minutes'
where id=(select lesson_id from public.bookings where id=(select id from p16_ids where name='future_b_booking'));
update public.bookings set starts_at=now()-interval '2 hours',ends_at=now()-interval '70 minutes'
where id=(select id from p16_ids where name='future_b_booking');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.p16_ids where name='future_b_booking'),
  'Visible','Private','Summary','Goal','Homework')$$,
  'P0001','ENTITLEMENT_NOT_ACTIVE','B7 revoked Entitlement rejects completion');
reset role;
select is((select count(*) from public.lesson_credit_ledger
  where entitlement_id='7b000000-0000-0000-0000-000000000022'),1::bigint,
  'B14 another active Entitlement is not used as fallback');

-- B8: processing after expiry is allowed when the scheduled Lesson was valid.
update public.lessons set starts_at=now()-interval '3 hours',ends_at=now()-interval '130 minutes'
where id=(select lesson_id from public.bookings where id=(select id from p16_ids where name='valid_ordinary_booking'));
update public.bookings set starts_at=now()-interval '3 hours',ends_at=now()-interval '130 minutes'
where id=(select id from p16_ids where name='valid_ordinary_booking');
update public.entitlements set status='expired',expires_at=now()-interval '2 hours',updated_at=now()
where id='7d000000-0000-0000-0000-000000000020';
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.p16_ids where name='valid_ordinary_booking'),
  'Visible','Private','Summary','Goal','Homework')$$,
  'B8 valid scheduled ordinary Lesson completes after processing-time expiry');
reset role;
select ok((select b.status='completed' and l.status='completed' and r.status='consumed'
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
  where b.id=(select id from p16_ids where name='valid_ordinary_booking')),
  'B8 valid ordinary Booking consumes its original Reservation');

-- B9/B10/B12: invalid Makeup Right lifecycle states are rejected explicitly.
update public.makeup_rights
set status='revoked',revoked_at=now(),revoked_by='7b000000-0000-0000-0000-000000000003',
  revoked_reason='P1-6B stale revoked Right',updated_at=now()
where id='7d000000-0000-0000-0000-000000000030';
update public.makeup_rights
set status='expired',expired_at=now(),expired_by='7b000000-0000-0000-0000-000000000003',
  updated_at=now()
where id='7d000000-0000-0000-0000-000000000031';
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.p16_ids where name='revoked_makeup_booking'),
  (current_date+15)::timestamp+time '19:00','UTC','P1-6B revoked Right')$$,
  'P0001','MAKEUP_RIGHT_NOT_RESERVED','B9 revoked Makeup Right rejects reschedule');
select throws_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.p16_ids where name='expired_makeup_booking'),
  (current_date+15)::timestamp+time '21:00','UTC','P1-6B expired Right')$$,
  'P0001','MAKEUP_RIGHT_EXPIRED','B10 expired Makeup Right rejects reschedule');
reset role;
update public.lessons set starts_at=now()-interval '4 hours',ends_at=now()-interval '190 minutes'
where id=(select lesson_id from public.bookings where id=(select id from p16_ids where name='revoked_makeup_booking'));
update public.bookings set starts_at=now()-interval '4 hours',ends_at=now()-interval '190 minutes'
where id=(select id from p16_ids where name='revoked_makeup_booking');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.p16_ids where name='revoked_makeup_booking'),
  'Visible','Private','Summary','Goal','Homework')$$,
  'P0001','MAKEUP_RIGHT_NOT_RESERVED','B12 non-reserved Makeup Right rejects completion');
reset role;

-- B11/B13: valid Makeup keeps and consumes the exact same Right, never credit.
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.p16_ids where name='makeup_booking'),
  (current_date+15)::timestamp+time '16:00','UTC','P1-6B valid Makeup reschedule')$$,
  'B11 valid Makeup Booking reschedules');
reset role;
select is((select makeup_right_id from public.bookings
  where id=(select id from p16_ids where name='makeup_booking')),
  '7b000000-0000-0000-0000-000000000030'::uuid,
  'B11 reschedule preserves the same Makeup Right identity');
update public.lessons set starts_at=now()-interval '5 hours',ends_at=now()-interval '250 minutes'
where id=(select lesson_id from public.bookings where id=(select id from p16_ids where name='makeup_booking'));
update public.bookings set starts_at=now()-interval '5 hours',ends_at=now()-interval '250 minutes'
where id=(select id from p16_ids where name='makeup_booking');
create temporary table p16b_ledger_before_makeup as select count(*) n from public.lesson_credit_ledger;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.complete_lesson_booking(
  (select id from pg_temp.p16_ids where name='makeup_booking'),
  'Visible','Private','Summary','Goal','Homework')$$,
  'B13 valid Makeup Booking completes');
reset role;
select ok((select b.status='completed' and l.status='completed' and mr.status='used'
    and b.makeup_right_id='7b000000-0000-0000-0000-000000000030'
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  join public.makeup_rights mr on mr.id=b.makeup_right_id
  where b.id=(select id from p16_ids where name='makeup_booking')),
  'B13 completion consumes the same Makeup Right');
select is((select count(*) from public.lesson_credit_ledger),
  (select n from p16b_ledger_before_makeup),
  'B13 Makeup completion touches no ordinary credit ledger');

select is((select count(*) from (values('anon'),('authenticated'),('service_role')) roles(name)
  where has_function_privilege(name,
    'private.validate_booking_value_source(uuid,timestamptz,text)','EXECUTE')),0::bigint,
  'Private value-source validator is not executable by application roles');

select * from finish();
rollback;
