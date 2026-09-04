begin;
select no_plan();
\set p16_fixture_include true
\ir entitlement_revoke_booking_consistency_fixture.sql
\unset p16_fixture_include

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.refresh_recurring_series_occurrences(
  '7b000000-0000-0000-0000-000000000044',current_date+35)$$,
  'C0 Fixed priority occurrences exist before revoke');
reset role;

create temporary table p16c_before as
select
  to_jsonb(s)-'preferred_entitlement_id'-'updated_at' series_without_pointer,
  (select jsonb_agg(to_jsonb(o)-'updated_at' order by o.occurrence_date)
   from public.recurring_lesson_occurrences o where o.series_id=s.id) occurrences,
  to_jsonb(c)-'status'-'updated_at' cycle_identity
from public.recurring_lesson_series s
join public.fixed_entitlement_cycles c on c.series_id=s.id
where c.id='7b000000-0000-0000-0000-000000000045';

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020',
  'P1-6C invalidate active Fixed cycle','p16c-revoke-active-0001')$$,
  'C1 authoritative revoke succeeds');
reset role;

select is((select status from public.fixed_entitlement_cycles
  where id='7b000000-0000-0000-0000-000000000045'),
  'invalidated'::public.fixed_entitlement_cycle_status,
  'C1 active cycle is invalidated');
select is((select preferred_entitlement_id from public.recurring_lesson_series
  where id='7b000000-0000-0000-0000-000000000044'),null::uuid,
  'C2 revoked Entitlement is no longer the preferred source');
select ok((select status='active' from public.recurring_lesson_series
  where id='7b000000-0000-0000-0000-000000000044'),
  'C3 Fixed series remains active');
select ok((select to_jsonb(s)-'preferred_entitlement_id'-'updated_at'=
    (select series_without_pointer from p16c_before)
  from public.recurring_lesson_series s
  where s.id='7b000000-0000-0000-0000-000000000044'),
  'C4 Fixed series scheduling and priority fields are unchanged');
select is((select jsonb_agg(to_jsonb(o)-'updated_at' order by o.occurrence_date)
  from public.recurring_lesson_occurrences o
  where o.series_id='7b000000-0000-0000-0000-000000000044'),
  (select occurrences from p16c_before),
  'C4 Fixed priority occurrences are unchanged');
select ok((select to_jsonb(c)-'status'-'updated_at'=(select cycle_identity from p16c_before)
  from public.fixed_entitlement_cycles c
  where c.id='7b000000-0000-0000-0000-000000000045'),
  'C5 invalidation preserves cycle identity and sequence');
select is((select count(*) from public.audit_logs
  where action='fixed_cycle.invalidated'
    and target_id='7b000000-0000-0000-0000-000000000045'),1::bigint,
  'C1 cycle invalidation has one audit');
select is((select count(*) from public.audit_logs
  where action='recurring_series.preferred_entitlement_cleared'
    and target_id='7b000000-0000-0000-0000-000000000044'),1::bigint,
  'C2 preferred pointer clearing has one audit');

-- Other active packages exist, but revoke does not attach or prefer one.
select is((select count(*) from public.fixed_entitlement_cycles
  where entitlement_id in(
    '7b000000-0000-0000-0000-000000000021',
    '7b000000-0000-0000-0000-000000000022'
  )),0::bigint,'C7 revoke does not auto-attach another Entitlement');

create temporary table p16c_repeat_counts as
select
  (select count(*) from public.audit_logs where action='fixed_cycle.invalidated'
    and target_id='7b000000-0000-0000-0000-000000000045') cycle_audits,
  (select count(*) from public.audit_logs
    where action='recurring_series.preferred_entitlement_cleared'
      and target_id='7b000000-0000-0000-0000-000000000044') pointer_audits,
  (select count(*) from public.audit_logs where action='entitlement.revoked'
    and target_id='7b000000-0000-0000-0000-000000000020') entitlement_audits;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select is(public.admin_revoke_entitlement(
  '7b000000-0000-0000-0000-000000000020',
  'P1-6C repeated revoke','p16c-revoke-repeat-0001'),
  '7b000000-0000-0000-0000-000000000020'::uuid,
  'C8 repeated revoke is state-idempotent');
reset role;
select ok((select
    cycle_audits=(select count(*) from public.audit_logs where action='fixed_cycle.invalidated'
      and target_id='7b000000-0000-0000-0000-000000000045')
    and pointer_audits=(select count(*) from public.audit_logs
      where action='recurring_series.preferred_entitlement_cleared'
        and target_id='7b000000-0000-0000-0000-000000000044')
    and entitlement_audits=(select count(*) from public.audit_logs where action='entitlement.revoked'
      and target_id='7b000000-0000-0000-0000-000000000020')
  from p16c_repeat_counts),'C8 repeated revoke creates no duplicate audit');

-- Explicit revoked source fails without selecting another package.
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000002',true);
select is(public.materialize_recurring_lesson_occurrence(
  '7b000000-0000-0000-0000-000000000044',current_date+21,
  '7b000000-0000-0000-0000-000000000020','p16c-revoked-materialize-0001'),
  null::uuid,'C9 revoked Entitlement cannot materialize a future occurrence');
reset role;
select ok((select status='credit_required' and booking_id is null
  from public.recurring_lesson_occurrences
  where series_id='7b000000-0000-0000-0000-000000000044'
    and occurrence_date=current_date+21),
  'C9 missing valid explicit source does not fallback');

-- Create two real paid replacement sources through existing commerce authority.
insert into public.products(
  id,product_type,status,public_slug,name,currency,base_price_amount,owner_type,
  is_public,is_purchasable,published_at
) values(
  '7e000000-0000-0000-0000-000000000040','lesson_package','active',
  'p16c-fixed-replacement','P1-6C Fixed Replacement','TWD',1000,'platform',true,true,now()
);
insert into public.lesson_package_product_configs(
  product_id,lesson_count,validity_value,validity_unit,
  lesson_duration_minutes,booking_mode_eligibility
) values('7e000000-0000-0000-0000-000000000040',2,6,'months',50,'fixed');
create temporary table p16c_ids(name text primary key,id uuid not null);
grant select,insert on pg_temp.p16c_ids to authenticated,service_role;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
insert into pg_temp.p16c_ids values
  ('replacement_order',public.create_checkout_order(
    'p16c-fixed-replacement',1,'p16c-replacement-order-0001')),
  ('historical_order',public.create_checkout_order(
    'p16c-fixed-replacement',1,'p16c-historical-order-0001'));
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select public.admin_confirm_cash_payment(id,'p16c-cash-'||name,'P1-6C paid source')
from pg_temp.p16c_ids where name like '%_order';
reset role;
insert into p16c_ids
select replace(name,'order','event'),e.id from p16c_ids x
join public.order_fulfillment_events e on e.order_id=x.id
where name like '%_order';
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select public.process_order_fulfillment_event(id)
from pg_temp.p16c_ids where name like '%_event';
reset role;
insert into p16c_ids
select replace(name,'order','entitlement'),e.id from p16c_ids x
join public.entitlements e on e.source_order_id=x.id
where name like '%_order';

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
insert into pg_temp.p16c_ids values(
  'replacement_cycle',public.attach_fixed_entitlement_cycle(
    '7b000000-0000-0000-0000-000000000044',
    (select id from p16c_ids where name='replacement_entitlement'),
    (select id from p16c_ids where name='replacement_event'),
    'P1-6C explicit replacement attachment'));
reset role;
select ok((select c.status='active' and c.entitlement_id=
    (select id from p16c_ids where name='replacement_entitlement')
  from public.fixed_entitlement_cycles c
  where c.id=(select id from p16c_ids where name='replacement_cycle')),
  'C10 a valid replacement cycle is attached explicitly');
select is((select preferred_entitlement_id from public.recurring_lesson_series
  where id='7b000000-0000-0000-0000-000000000044'),null::uuid,
  'C10 explicit attachment does not silently rewrite preferred source');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000002',true);
insert into pg_temp.p16c_ids values(
  'replacement_booking',public.materialize_recurring_lesson_occurrence(
    '7b000000-0000-0000-0000-000000000044',current_date+21,
    (select id from p16c_ids where name='replacement_entitlement'),
    'p16c-replacement-materialize-0001'));
reset role;
select ok((select b.fixed_cycle_id=(select id from p16c_ids where name='replacement_cycle')
    and b.credit_reservation_id is not null
  from public.bookings b where b.id=(select id from p16c_ids where name='replacement_booking')),
  'C10 future materialization uses the explicit replacement cycle');

-- A completed historical cycle remains immutable when its Entitlement is revoked.
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
insert into pg_temp.p16c_ids values(
  'historical_cycle',public.attach_fixed_entitlement_cycle(
    '7b000000-0000-0000-0000-000000000044',
    (select id from p16c_ids where name='historical_entitlement'),
    (select id from p16c_ids where name='historical_event'),
    'P1-6C historical attachment'));
reset role;
update public.fixed_entitlement_cycles
set status='completed',completed_at=now(),
  completed_by='7b000000-0000-0000-0000-000000000003',updated_at=now()
where id=(select id from p16c_ids where name='historical_cycle');
update public.recurring_lesson_series
set preferred_entitlement_id=(select id from p16c_ids where name='replacement_entitlement'),
  updated_at=now()
where id='7b000000-0000-0000-0000-000000000044';
create temporary table p16c_historical_before as
select to_jsonb(c) cycle from public.fixed_entitlement_cycles c
where c.id=(select id from p16c_ids where name='historical_cycle');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.admin_revoke_entitlement(
  (select id from pg_temp.p16c_ids where name='historical_entitlement'),
  'P1-6C revoke completed historical source','p16c-revoke-historical-0001')$$,
  'C6 historical Entitlement revoke succeeds');
reset role;
select ok((select to_jsonb(c)=(select cycle from p16c_historical_before)
  from public.fixed_entitlement_cycles c
  where c.id=(select id from p16c_ids where name='historical_cycle')),
  'C5 completed historical cycle, sequence, and Entitlement identity are preserved');
select ok((select c.status='active'
  from public.fixed_entitlement_cycles c
  where c.id=(select id from p16c_ids where name='replacement_cycle')),
  'C6 historical revoke leaves the current active cycle unchanged');
select is((select preferred_entitlement_id from public.recurring_lesson_series
  where id='7b000000-0000-0000-0000-000000000044'),
  (select id from p16c_ids where name='replacement_entitlement'),
  'C6 historical revoke leaves the current preferred source unchanged');
select ok((select action='fixed_cycle.invalidated'
    and actor_user_id='7b000000-0000-0000-0000-000000000003'
    and before_snapshot->>'entitlement_id'='7b000000-0000-0000-0000-000000000020'
    and after_snapshot->>'series_id'='7b000000-0000-0000-0000-000000000044'
    and reason='P1-6C invalidate active Fixed cycle'
    and created_at is not null
  from public.audit_logs
  where target_id='7b000000-0000-0000-0000-000000000045'
    and action='fixed_cycle.invalidated'),
  'Cycle audit preserves actor, Entitlement, Series, before, after, reason, and timestamp');
select is((select count(*) from (values('anon'),('authenticated'),('service_role')) roles(name)
  where has_function_privilege(name,
    'private.reconcile_fixed_cycles_on_entitlement_revoke(uuid,uuid,text)','EXECUTE')),0::bigint,
  'Private reconciliation helper is not executable by application roles');

select * from finish();
rollback;
