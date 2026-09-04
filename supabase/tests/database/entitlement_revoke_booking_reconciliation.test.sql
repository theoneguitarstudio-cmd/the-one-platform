begin;
select no_plan();
\set p16_fixture_include true
\ir entitlement_revoke_booking_consistency_fixture.sql
\unset p16_fixture_include

-- A cancelled ordinary Booking is historical lifecycle state and must not be
-- rewritten by the later Entitlement revoke.
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
insert into pg_temp.p16_ids values(
  'already_cancelled_booking',public.create_lesson_booking(
    '7b000000-0000-0000-0000-000000000001','7b000000-0000-0000-0000-000000000002',
    '7b000000-0000-0000-0000-000000000010','7b000000-0000-0000-0000-000000000020',
    (current_date+14)::timestamp+time '19:00','UTC',
    'p16-already-cancelled-0001','P1-6A cancelled history fixture'));
select public.cancel_lesson_booking(
  (select id from pg_temp.p16_ids where name='already_cancelled_booking'),
  'released','P1-6A cancelled history fixture');
reset role;

-- Materialize an actual Fixed ordinary Booking using the same explicit
-- Entitlement. The recurring series and cycle are intentionally out of scope.
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select public.refresh_recurring_series_occurrences(
  '7b000000-0000-0000-0000-000000000044',current_date+30);
insert into pg_temp.p16_ids values(
  'fixed_a_booking',public.materialize_recurring_lesson_occurrence(
    '7b000000-0000-0000-0000-000000000044',current_date+21,
    '7b000000-0000-0000-0000-000000000020','p16-fixed-a-materialize-0001'));
reset role;

create temporary table p16a_before as
select
  (select count(*) from public.makeup_rights) as makeup_count,
  (select to_jsonb(b) from public.bookings b
    where b.id=(select id from p16_ids where name='already_cancelled_booking')) as cancelled_booking,
  (select to_jsonb(l) from public.lessons l join public.bookings b on b.lesson_id=l.id
    where b.id=(select id from p16_ids where name='already_cancelled_booking')) as cancelled_lesson,
  (select to_jsonb(s) from public.recurring_lesson_series s
    where s.id='7b000000-0000-0000-0000-000000000044') as fixed_series,
  (select to_jsonb(c) from public.fixed_entitlement_cycles c
    where c.id='7b000000-0000-0000-0000-000000000045') as fixed_cycle;

-- Force a late reconciliation failure and prove the entire revoke rolls back.
create function pg_temp.p16a_fail_reconciliation_audit()
returns trigger language plpgsql as $$
begin
  raise exception using errcode='P0001',message='P16_TEST_RECONCILIATION_AUDIT_FAILURE';
end;
$$;
create trigger p16a_fail_reconciliation_audit
before insert on public.audit_logs
for each row when (new.action='entitlement_revoke.booking_reconciled')
execute function pg_temp.p16a_fail_reconciliation_audit();

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000021','P1-6A forced rollback',
  'p16a-forced-rollback-0001')$$,'P0001','P16_TEST_RECONCILIATION_AUDIT_FAILURE',
  'A14 reconciliation audit failure aborts the authoritative revoke');
reset role;
drop trigger p16a_fail_reconciliation_audit on public.audit_logs;

select ok((select e.status='active' and r.status='reserved' and b.status='confirmed'
    and l.status='scheduled'
  from public.entitlements e
  join public.lesson_credit_reservations r on r.entitlement_id=e.id
  join public.bookings b on b.credit_reservation_id=r.id
  join public.lessons l on l.id=b.lesson_id
  where e.id='7b000000-0000-0000-0000-000000000021'),
  'A14 failed revoke leaves Entitlement, Reservation, Booking, and Lesson unchanged');
select is((select count(*) from public.lesson_credit_ledger
  where entitlement_id='7b000000-0000-0000-0000-000000000021'
    and entry_type='revocation'),0::bigint,
  'A14 failed revoke leaves no revocation ledger movement');
select is((select count(*) from public.audit_logs
  where target_id='7b000000-0000-0000-0000-000000000021'
    and action='entitlement.revoked'),0::bigint,
  'A14 failed revoke leaves no Entitlement revoke audit');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020','P1-6A reconciliation',
  'p16a-revoke-package-a-0001')$$,'P1-6A authoritative revoke succeeds');
reset role;

select is((select status from public.bookings
  where id=(select id from p16_ids where name='future_a_booking')),
  'cancelled'::public.booking_status,'A1 Flexible ordinary Booking is cancelled');
select is((select l.status from public.lessons l join public.bookings b on b.lesson_id=l.id
  where b.id=(select id from p16_ids where name='future_a_booking')),
  'admin_cancelled'::public.lesson_status,'A2 Flexible Lesson is no longer scheduled');
select is((select r.status from public.lesson_credit_reservations r
  join public.bookings b on b.credit_reservation_id=r.id
  where b.id=(select id from p16_ids where name='future_a_booking')),
  'released'::public.lesson_credit_reservation_status,'A3 Flexible reservation is released');
select is((select available from private.lesson_credit_balance(
  '7b000000-0000-0000-0000-000000000020')),0::integer,
  'A4 revoke reconciliation does not restore ordinary available credit');
select is((select count(*) from public.lesson_credit_ledger
  where entitlement_id='7b000000-0000-0000-0000-000000000020'
    and entry_type='revocation'),1::bigint,'A5 revocation ledger is written exactly once');
select is((select count(*) from public.lesson_credit_ledger ll
  join public.bookings b on b.credit_reservation_id=ll.reservation_id
  where b.id in(
    (select id from p16_ids where name='future_a_booking'),
    (select id from p16_ids where name='fixed_a_booking')
  ) and ll.entry_type='release'),0::bigint,
  'A5 reconciliation creates no per-reservation release ledger movement');
select is((select count(*) from public.makeup_rights),(select makeup_count from p16a_before),
  'A6 revoke reconciliation creates no Makeup Right');

select ok((select b.status='cancelled' and l.status='admin_cancelled'
    and r.status='released'
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
  where b.id=(select id from p16_ids where name='fixed_a_booking') and b.source='fixed'),
  'A7 Fixed materialized ordinary Booking receives the same reconciliation');
select ok((select to_jsonb(s)=(select fixed_series from p16a_before)
  from public.recurring_lesson_series s
  where s.id='7b000000-0000-0000-0000-000000000044'),
  'A7 Fixed recurring priority and series state are unchanged');
select ok((select to_jsonb(c)=(select fixed_cycle from p16a_before)
  from public.fixed_entitlement_cycles c
  where c.id='7b000000-0000-0000-0000-000000000045'),
  'A7 Fixed Cycle lifecycle remains outside P1-6A');

select is((select l.status from public.lessons l join public.bookings b on b.lesson_id=l.id
  where b.id=(select id from p16_ids where name='completed_booking')),
  'completed'::public.lesson_status,'A8 completed Lesson is preserved');
select is((select r.status from public.lesson_credit_reservations r
  join public.bookings b on b.credit_reservation_id=r.id
  where b.id=(select id from p16_ids where name='completed_booking')),
  'consumed'::public.lesson_credit_reservation_status,'A9 consumed reservation is preserved');
select ok((select b.status='confirmed' and l.status='scheduled' and mr.status='reserved'
  from public.bookings b join public.lessons l on l.id=b.lesson_id
  join public.makeup_rights mr on mr.id=b.makeup_right_id
  where b.id=(select id from p16_ids where name='makeup_booking')),
  'A10 Makeup booking is unaffected');
select ok((select e.status='active' and r.status='reserved' and b.status='confirmed'
    and l.status='scheduled'
  from public.entitlements e
  join public.lesson_credit_reservations r on r.entitlement_id=e.id
  join public.bookings b on b.credit_reservation_id=r.id
  join public.lessons l on l.id=b.lesson_id
  where e.id='7b000000-0000-0000-0000-000000000021'),
  'A11 Entitlement B and its explicit Booking are unaffected');
select ok((select to_jsonb(b)=(select cancelled_booking from p16a_before)
  from public.bookings b
  where b.id=(select id from p16_ids where name='already_cancelled_booking')),
  'A12 already cancelled Booking remains unchanged');
select ok((select to_jsonb(l)=(select cancelled_lesson from p16a_before)
  from public.lessons l join public.bookings b on b.lesson_id=l.id
  where b.id=(select id from p16_ids where name='already_cancelled_booking')),
  'A12 already cancelled Lesson remains unchanged');

create temporary table p16a_revoke_counts as
select
  (select count(*) from public.lesson_credit_ledger
    where entitlement_id='7b000000-0000-0000-0000-000000000020'
      and entry_type='revocation') as ledger_count,
  (select count(*) from public.audit_logs
    where action='entitlement_revoke.booking_reconciled'
      and before_snapshot->>'entitlement_id'='7b000000-0000-0000-0000-000000000020') as reconciliation_count;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020','P1-6A reconciliation retry',
  'p16a-revoke-package-a-retry')$$,'A13 repeated revoke is state-idempotent');
reset role;
select ok(
  (select count(*) from public.lesson_credit_ledger
    where entitlement_id='7b000000-0000-0000-0000-000000000020'
      and entry_type='revocation')=(select ledger_count from p16a_revoke_counts)
  and
  (select count(*) from public.audit_logs
    where action='entitlement_revoke.booking_reconciled'
      and before_snapshot->>'entitlement_id'='7b000000-0000-0000-0000-000000000020')
      =(select reconciliation_count from p16a_revoke_counts),
  'A13 repeated revoke creates no duplicate ledger or cancellation audit');

select is((select count(*) from public.audit_logs
  where action='entitlement_revoke.booking_reconciled'
    and before_snapshot ?& array[
      'entitlement_id','reservation_id','booking_id','lesson_id','booking_status','lesson_status'
    ]
    and after_snapshot ?& array[
      'entitlement_id','reservation_id','booking_id','lesson_id','booking_status','lesson_status'
    ]
    and actor_user_id='7b000000-0000-0000-0000-000000000003'
    and reason='P1-6A reconciliation'),2::bigint,
  'Reconciliation audit traces Entitlement, Reservation, Booking, Lesson, actor, reason, before, and after');
select is((select count(*) from (values
  ('anon'),('authenticated'),('service_role')
) roles(role_name) where has_function_privilege(
  role_name,'private.reconcile_bookings_on_entitlement_revoke(uuid,uuid,text,text)','EXECUTE'
)),0::bigint,'Private reconciliation helper is not directly executable by API roles');

select * from finish();
rollback;
