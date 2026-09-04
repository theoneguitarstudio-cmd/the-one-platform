begin;
select no_plan();
\set p16_fixture_include true
\ir entitlement_revoke_booking_consistency_fixture.sql
\unset p16_fixture_include

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020','P1-6 contract revocation',
  'p16-contract-revoke-a-0001');
reset role;

select is((select count(*) from public.bookings b
  join public.lessons l on l.id=b.lesson_id
  join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
  join public.entitlements e on e.id=r.entitlement_id
  where e.id='7b000000-0000-0000-0000-000000000020'
    and b.status in('confirmed','rescheduled') and l.status='scheduled'
    and (r.status<>'reserved' or e.status<>'active')),0::bigint,
  'R1 revoke leaves no confirmed/scheduled Booking without valid value');
select is((select r.status from public.lesson_credit_reservations r join public.bookings b
  on b.credit_reservation_id=r.id where b.id=(select id from p16_ids where name='future_a_booking')),
  'released'::public.lesson_credit_reservation_status,'R2 revoked reservation is no longer usable');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.p16_ids where name='future_a_booking'),
  (current_date+14)::timestamp+time '20:00','UTC','P1-6 contract reschedule')$$,
  'P0001','BOOKING_NOT_RESCHEDULABLE','R3 invalid value source cannot reschedule');
reset role;

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
  'P0001','CREDIT_ALREADY_RELEASED','R4 invalid value source cannot complete');
reset role;

create temporary table p16_release_before as
select count(*) n from public.lesson_credit_ledger
where reservation_id=(select credit_reservation_id from public.bookings
  where id=(select id from p16_ids where name='future_a_booking')) and entry_type='release';
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.cancel_lesson_booking(
  (select id from pg_temp.p16_ids where name='future_a_booking'),
  'released','Cancel invalid source Booking')$$,'R5 cancel after revoke remains idempotent');
reset role;
select is((select count(*) from public.lesson_credit_ledger
  where reservation_id=(select credit_reservation_id from public.bookings
    where id=(select id from p16_ids where name='future_a_booking')) and entry_type='release'),
  (select n from p16_release_before),'R5 cancel does not double-release');
select ok((select e.status='active' and r.status='reserved' and b.status='confirmed'
  from public.entitlements e join public.lesson_credit_reservations r on r.entitlement_id=e.id
  join public.bookings b on b.credit_reservation_id=r.id
  where e.id='7b000000-0000-0000-0000-000000000021'),
  'R6 revoke A does not affect explicit Package B Booking');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000022','Unrelated ordinary revoke',
  'p16-contract-revoke-c-0001');
reset role;
select ok((select b.status='confirmed' and l.status='scheduled' and mr.status='reserved'
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  join public.makeup_rights mr on mr.id=b.makeup_right_id
  where b.id=(select id from p16_ids where name='makeup_booking')),
  'R7 ordinary revoke does not affect Makeup booking');
select ok((select b.status='completed' and l.status='completed' and r.status='consumed'
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
  where b.id=(select id from p16_ids where name='completed_booking')),
  'R8 completed Lesson and consumed history remain preserved');
select is((select count(*) from public.fixed_entitlement_cycles c
  join public.entitlements e on e.id=c.entitlement_id
  where c.status='active' and e.status='revoked'),0::bigint,
  'R9 no active Fixed Cycle remains attached to revoked Entitlement');

create temporary table p16_revoke_before as
select
  (select count(*) from public.lesson_credit_ledger where entitlement_id='7b000000-0000-0000-0000-000000000020'
    and entry_type='revocation') ledger_count,
  (select count(*) from public.audit_logs where action='entitlement.revoked'
    and target_id='7b000000-0000-0000-0000-000000000020') audit_count;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020','P1-6 contract revocation',
  'p16-contract-revoke-a-0001')$$,'R10 repeated revoke is stable');
reset role;
select ok((select count(*) from public.lesson_credit_ledger
    where entitlement_id='7b000000-0000-0000-0000-000000000020' and entry_type='revocation')
    =(select ledger_count from p16_revoke_before)
  and (select count(*) from public.audit_logs where action='entitlement.revoked'
    and target_id='7b000000-0000-0000-0000-000000000020')
    =(select audit_count from p16_revoke_before),
  'R10 repeated revoke creates no duplicate ledger or audit');

select * from finish();
rollback;
