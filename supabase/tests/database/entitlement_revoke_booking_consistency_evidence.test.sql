begin;
select no_plan();
\set p16_fixture_include true
\ir entitlement_revoke_booking_consistency_fixture.sql
\unset p16_fixture_include

create temporary table p16_before as
select
  (select count(*) from public.lesson_credit_ledger where entitlement_id='7b000000-0000-0000-0000-000000000020') ledger_a,
  (select count(*) from public.audit_logs where action='entitlement.revoked'
    and target_id='7b000000-0000-0000-0000-000000000020') revoke_audits,
  (select count(*) from public.makeup_rights) makeup_rights;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020','Unauthorized Student revoke',
  'p16-unauthorized-revoke-0001')$$,'42501','Not authorized',
  'Student cannot invoke Admin Entitlement revoke authority');
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020','P1-6 evidence revocation',
  'p16-revoke-package-a-0001')$$,'Current revoke RPC succeeds');
reset role;

select is((select status from public.entitlements where id='7b000000-0000-0000-0000-000000000020'),
  'revoked'::public.entitlement_status,'Entitlement becomes revoked');
select is((select r.status from public.lesson_credit_reservations r join public.bookings b
  on b.credit_reservation_id=r.id where b.id=(select id from p16_ids where name='future_a_booking')),
  'released'::public.lesson_credit_reservation_status,'Future reservation becomes released');
select is((select status from public.bookings where id=(select id from p16_ids where name='future_a_booking')),
  'cancelled'::public.booking_status,'P1-6A: revoke reconciles Booking to cancelled');
select is((select l.status from public.lessons l join public.bookings b on b.lesson_id=l.id
  where b.id=(select id from p16_ids where name='future_a_booking')),
  'admin_cancelled'::public.lesson_status,'P1-6A: revoke reconciles Lesson to admin_cancelled');
select is((select count(*) from public.lesson_credit_ledger
  where entitlement_id='7b000000-0000-0000-0000-000000000020' and entry_type='revocation'),
  1::bigint,'Revoke records one ledger revocation');
select is((select count(*) from public.audit_logs where action='entitlement.revoked'
  and target_id='7b000000-0000-0000-0000-000000000020'),1::bigint,
  'Revoke records one durable audit');
select is((select count(*) from public.makeup_rights),(select makeup_rights from p16_before),
  'Entitlement revoke creates no Makeup Right');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.reschedule_lesson_booking(
  (select id from pg_temp.p16_ids where name='future_a_booking'),
  (current_date+14)::timestamp+time '20:00','UTC','P1-6 evidence reschedule')$$,
  'P0001','BOOKING_NOT_RESCHEDULABLE',
  'P1-6A reconciled Booking cannot be rescheduled');
reset role;
select is((select status from public.bookings where id=(select id from p16_ids where name='future_a_booking')),
  'cancelled'::public.booking_status,'Failed reschedule leaves reconciled Booking cancelled');

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
  'P0001','CREDIT_ALREADY_RELEASED','Completion explicitly rejects the released value source');
reset role;
select is((select status from public.bookings where id=(select id from p16_ids where name='future_a_booking')),
  'cancelled'::public.booking_status,'Failed completion leaves Booking cancelled');
select is((select l.status from public.lessons l join public.bookings b on b.lesson_id=l.id
  where b.id=(select id from p16_ids where name='future_a_booking')),
  'admin_cancelled'::public.lesson_status,'Failed completion leaves Lesson admin_cancelled');

create temporary table p16_release_before as
select count(*) n from public.lesson_credit_ledger
where reservation_id=(select credit_reservation_id from public.bookings
  where id=(select id from p16_ids where name='future_a_booking')) and entry_type='release';
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.cancel_lesson_booking(
  (select id from pg_temp.p16_ids where name='future_a_booking'),
  'released','Cancel after Entitlement revoke')$$,'Later cancellation is idempotent over released reservation');
reset role;
select is((select count(*) from public.lesson_credit_ledger
  where reservation_id=(select credit_reservation_id from public.bookings
    where id=(select id from p16_ids where name='future_a_booking')) and entry_type='release'),
  (select n from p16_release_before),'Later cancellation does not double-release');

select ok((select e.status='active' and r.status='reserved' and b.status='confirmed'
  from public.entitlements e join public.lesson_credit_reservations r on r.entitlement_id=e.id
  join public.bookings b on b.credit_reservation_id=r.id
  where e.id='7b000000-0000-0000-0000-000000000021'),
  'Package B and its explicit Booking are unaffected');
select ok((select b.status='completed' and l.status='completed' and r.status='consumed'
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
  where b.id=(select id from p16_ids where name='completed_booking')),
  'Completed Lesson and consumed reservation history remain preserved');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000022','Unrelated ordinary revoke',
  'p16-revoke-package-c-0001');
reset role;
select ok((select b.status='confirmed' and l.status='scheduled' and mr.status='reserved'
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  join public.makeup_rights mr on mr.id=b.makeup_right_id
  where b.id=(select id from p16_ids where name='makeup_booking')),
  'Makeup booking remains isolated from unrelated ordinary revoke');
select ok((select c.status='invalidated' and e.status='revoked'
  from public.fixed_entitlement_cycles c join public.entitlements e on e.id=c.entitlement_id
  where c.id='7b000000-0000-0000-0000-000000000045'),
  'Fixed Cycle is invalidated when its attached Entitlement is revoked');
select is((select preferred_entitlement_id from public.recurring_lesson_series
  where id='7b000000-0000-0000-0000-000000000044'),null::uuid,
  'Series preferred_entitlement_id is cleared when that Entitlement is revoked');
select is(private.scheduling_entitlement_eligible(
  '7b000000-0000-0000-0000-000000000020',
  '7b000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000002','fixed'),false,
  'Future materialization eligibility rejects the revoked cycle Entitlement');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020','P1-6 evidence revocation',
  'p16-revoke-package-a-0001')$$,'Repeated revoke is stable');
reset role;
select is((select count(*) from public.lesson_credit_ledger
  where entitlement_id='7b000000-0000-0000-0000-000000000020' and entry_type='revocation'),
  1::bigint,'Repeated revoke creates no second ledger entry');
select is((select count(*) from public.audit_logs where action='entitlement.revoked'
  and target_id='7b000000-0000-0000-0000-000000000020'),1::bigint,
  'Repeated revoke creates no second audit');

select * from finish();
rollback;
