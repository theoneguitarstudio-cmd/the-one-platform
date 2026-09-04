-- P1-7C exact-match validation for generic, renewal, and checkout cycle flows.
begin;
select plan(35);
\set p17_fixture_include 1
\ir lesson_duration_entitlement_fixture.sql

create temporary table p17c_ids(name text primary key,id uuid not null);
grant select,insert,update on pg_temp.p17c_ids to authenticated,service_role;

insert into public.products(
  id,product_type,status,public_slug,name,currency,base_price_amount,
  owner_type,is_public,is_purchasable,published_at
) values
  ('7d000000-0000-0000-0000-000000000020','lesson_package','active','p17c-four-50',
    'P1-7C four by 50','TWD',3200,'platform',true,true,now()),
  ('7d000000-0000-0000-0000-000000000021','lesson_package','active','p17c-twelve-50',
    'P1-7C twelve by 50','TWD',8400,'platform',true,true,now()),
  ('7d000000-0000-0000-0000-000000000022','lesson_package','active','p17c-twelve-80',
    'P1-7C twelve by 80','TWD',12000,'platform',true,true,now());
insert into public.lesson_package_product_configs(
  product_id,lesson_count,validity_value,validity_unit,
  lesson_duration_minutes,booking_mode_eligibility
) values
  ('7d000000-0000-0000-0000-000000000020',4,12,'months',50,'fixed'),
  ('7d000000-0000-0000-0000-000000000021',12,12,'months',50,'fixed'),
  ('7d000000-0000-0000-0000-000000000022',12,12,'months',80,'fixed');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000001',true);
insert into pg_temp.p17c_ids values
  ('order-four-a',public.create_checkout_order('p17c-four-50',1,'p17c-checkout-four-a')),
  ('order-four-b',public.create_checkout_order('p17c-four-50',1,'p17c-checkout-four-b')),
  ('order-four-c',public.create_checkout_order('p17c-four-50',1,'p17c-checkout-four-c')),
  ('order-four-d',public.create_checkout_order('p17c-four-50',1,'p17c-checkout-four-d')),
  ('order-twelve-50',public.create_checkout_order('p17c-twelve-50',1,'p17c-checkout-twelve-50')),
  ('order-twelve-80',public.create_checkout_order('p17c-twelve-80',1,'p17c-checkout-twelve-80')),
  ('order-new-60',public.create_checkout_order('p17-fifty',1,'p17c-checkout-new-sixty'));
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000003',true);
select public.admin_confirm_cash_payment(id,'p17c-paid-'||name,'P1-7C paid fixture')
from pg_temp.p17c_ids where name like 'order-%';
reset role;

insert into pg_temp.p17c_ids
select 'event-'||substr(r.name,7),e.id
from pg_temp.p17c_ids r
join public.order_fulfillment_events e on e.order_id=r.id
where r.name like 'order-%';
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select public.process_order_fulfillment_event(id)
from pg_temp.p17c_ids where name like 'event-%';
reset role;
insert into pg_temp.p17c_ids
select 'ent-'||substr(r.name,7),e.id
from pg_temp.p17c_ids r
join public.entitlements e on e.source_order_id=r.id
where r.name like 'order-%';

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
insert into pg_temp.p17c_ids values
  ('series-renew-good',public.create_recurring_lesson_series(
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',
    '7c000000-0000-0000-0000-000000000010',null,
    extract(dow from current_date+19)::smallint,'09:00','UTC',50::smallint,
    current_date+19,current_date+19,'P1-7C compatible renewal series')),
  ('series-renew-bad',public.create_recurring_lesson_series(
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',
    '7c000000-0000-0000-0000-000000000010',null,
    extract(dow from current_date+20)::smallint,'09:00','UTC',50::smallint,
    current_date+20,current_date+20,'P1-7C incompatible renewal series')),
  ('series-renew-sixty',public.create_recurring_lesson_series(
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',
    '7c000000-0000-0000-0000-000000000010',null,
    extract(dow from current_date+21)::smallint,'09:00','UTC',50::smallint,
    current_date+21,current_date+21,'P1-7C new snapshot renewal series'));
reset role;

select ok(not has_function_privilege(
  'anon','private.validate_lesson_duration_compatibility(uuid,integer)','EXECUTE'),
  'anon cannot execute the shared duration validator');
select ok(not has_function_privilege(
  'authenticated','private.validate_lesson_duration_compatibility(uuid,integer)','EXECUTE'),
  'authenticated cannot execute the shared duration validator');
select ok(not has_function_privilege(
  'service_role','private.validate_lesson_duration_compatibility(uuid,integer)','EXECUTE'),
  'service_role cannot directly execute the shared duration validator');

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$
  insert into pg_temp.p17c_ids values('cycle-exact',public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17_ids where name='series-50'),
    (select id from pg_temp.p17_ids where name='ent-50'),
    (select id from pg_temp.p17_ids where name='event-50'),'P1-7C exact attachment'))
$$,'C1 Series 50 accepts Entitlement 50');
select is(public.attach_fixed_entitlement_cycle(
  (select id from pg_temp.p17_ids where name='series-50'),
  (select id from pg_temp.p17_ids where name='ent-50'),
  (select id from pg_temp.p17_ids where name='event-50'),'P1-7C exact attachment retry'),
  (select id from pg_temp.p17c_ids where name='cycle-exact'),
  'C12 compatible attachment retry returns the same cycle');
reset role;
select is(
  (select array[s.duration_minutes::integer,e.lesson_duration_minutes,c.sequence_number]
   from public.fixed_entitlement_cycles c
   join public.recurring_lesson_series s on s.id=c.series_id
   join public.entitlements e on e.id=c.entitlement_id
   where c.id=(select id from pg_temp.p17c_ids where name='cycle-exact')),
  array[50,50,1],'C1 exact attachment stores Cycle 1 with equal durations');

create temporary table p17c_mismatch_before as
select
  (select count(*) from public.fixed_entitlement_cycles) cycles,
  (select coalesce(max(sequence_number),0) from public.fixed_entitlement_cycles
    where series_id=(select id from pg_temp.p17_ids where name='series-50')) sequence_number,
  (select preferred_entitlement_id from public.recurring_lesson_series
    where id=(select id from pg_temp.p17_ids where name='series-50')) preferred_entitlement_id,
  (select status::text from public.recurring_lesson_series
    where id=(select id from pg_temp.p17_ids where name='series-50')) series_status,
  (select count(*) from public.audit_logs where action='fixed_cycle.attached') attach_audits,
  (select count(*) from public.lesson_credit_ledger) ledger_entries,
  (select count(*) from public.recurring_lesson_occurrences
    where series_id=(select id from pg_temp.p17_ids where name='series-50')
      and status in('planned','credit_required')) priority_occurrences;

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select throws_ok($$
  select public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17_ids where name='series-50'),
    (select id from pg_temp.p17_ids where name='ent-80'),
    (select id from pg_temp.p17_ids where name='event-80'),'P1-7C forward mismatch')
$$,'P0001','LESSON_DURATION_MISMATCH','C2 Series 50 rejects Entitlement 80');
select throws_ok($$
  select public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17_ids where name='series-50'),
    (select id from pg_temp.p17_ids where name='ent-80'),
    (select id from pg_temp.p17_ids where name='event-80'),'P1-7C forward mismatch retry')
$$,'P0001','LESSON_DURATION_MISMATCH','C12 repeated mismatch remains a stable rejection');
reset role;
select is((select count(*) from public.fixed_entitlement_cycles),(select cycles from pg_temp.p17c_mismatch_before),
  'C4 mismatch inserts no cycle');
select is(
  (select coalesce(max(sequence_number),0) from public.fixed_entitlement_cycles
   where series_id=(select id from pg_temp.p17_ids where name='series-50')),
  (select sequence_number from pg_temp.p17c_mismatch_before),'C5 mismatch consumes no sequence');
select is(
  (select preferred_entitlement_id from public.recurring_lesson_series
   where id=(select id from pg_temp.p17_ids where name='series-50')),
  (select preferred_entitlement_id from pg_temp.p17c_mismatch_before),'C6 mismatch leaves preferred pointer unchanged');
select is((select count(*) from public.audit_logs where action='fixed_cycle.attached'),
  (select attach_audits from pg_temp.p17c_mismatch_before),'Mismatch writes no attachment success audit');
select is((select count(*) from public.lesson_credit_ledger),(select ledger_entries from pg_temp.p17c_mismatch_before),
  'Mismatch writes no credit ledger entry');
select is(
  (select row(status::text,(select count(*) from public.recurring_lesson_occurrences o
      where o.series_id=s.id and o.status in('planned','credit_required')))::text
   from public.recurring_lesson_series s where s.id=(select id from pg_temp.p17_ids where name='series-50')),
  (select row(series_status,priority_occurrences)::text from pg_temp.p17c_mismatch_before),
  'Mismatch preserves Series status and Fixed priority');

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select throws_ok($$
  select public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17_ids where name='series-80'),
    (select id from pg_temp.p17c_ids where name='ent-four-a'),
    (select id from pg_temp.p17c_ids where name='event-four-a'),'P1-7C reverse mismatch')
$$,'P0001','LESSON_DURATION_MISMATCH','C3 Series 80 rejects Entitlement 50');
reset role;
select is((select count(*) from public.fixed_entitlement_cycles
  where entitlement_id=(select id from pg_temp.p17c_ids where name='ent-four-a')),0::bigint,
  'C3 reverse mismatch inserts no cycle');

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$
  insert into pg_temp.p17c_ids values('cycle-sequence-2',public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17_ids where name='series-50'),
    (select id from pg_temp.p17c_ids where name='ent-four-d'),
    (select id from pg_temp.p17c_ids where name='event-four-d'),'P1-7C sequence control'))
$$,'Compatible attachment succeeds after rejected mismatch');
reset role;
select is((select sequence_number from public.fixed_entitlement_cycles
  where id=(select id from pg_temp.p17c_ids where name='cycle-sequence-2')),2,
  'C5 next compatible attachment receives Cycle 2, not Cycle 3');

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$
  insert into pg_temp.p17c_ids values('cycle-renew-good',public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17c_ids where name='series-renew-good'),
    (select id from pg_temp.p17c_ids where name='ent-four-a'),
    (select id from pg_temp.p17c_ids where name='event-four-a'),'P1-7C renewal good current'))
$$,'Compatible 4x50 current cycle attaches');
select lives_ok($$
  insert into pg_temp.p17c_ids values('cycle-renew-bad',public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17c_ids where name='series-renew-bad'),
    (select id from pg_temp.p17c_ids where name='ent-four-b'),
    (select id from pg_temp.p17c_ids where name='event-four-b'),'P1-7C renewal bad current'))
$$,'Mismatch-control 4x50 current cycle attaches');
select lives_ok($$
  insert into pg_temp.p17c_ids values('cycle-renew-sixty',public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17c_ids where name='series-renew-sixty'),
    (select id from pg_temp.p17c_ids where name='ent-four-c'),
    (select id from pg_temp.p17c_ids where name='event-four-c'),'P1-7C renewal sixty current'))
$$,'New-snapshot control 4x50 current cycle attaches');
reset role;

insert into public.fixed_cycle_renewals(
  id,series_id,current_cycle_id,current_entitlement_id,student_user_id,teacher_user_id,
  trigger_remaining_lessons,deadline_offset_seconds,renewal_hold_seconds,
  non_renew_release_offset_seconds,current_cycle_completed_at,renewal_deadline_at,reminder_due_at
) values
  ('7d000000-0000-0000-0000-000000000100',(select id from pg_temp.p17c_ids where name='series-renew-good'),
    (select id from pg_temp.p17c_ids where name='cycle-renew-good'),(select id from pg_temp.p17c_ids where name='ent-four-a'),
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',1,86400,3600,0,
    clock_timestamp(),clock_timestamp()+interval '1 day',clock_timestamp()),
  ('7d000000-0000-0000-0000-000000000101',(select id from pg_temp.p17c_ids where name='series-renew-bad'),
    (select id from pg_temp.p17c_ids where name='cycle-renew-bad'),(select id from pg_temp.p17c_ids where name='ent-four-b'),
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',1,86400,3600,0,
    clock_timestamp(),clock_timestamp()+interval '1 day',clock_timestamp()),
  ('7d000000-0000-0000-0000-000000000102',(select id from pg_temp.p17c_ids where name='series-renew-sixty'),
    (select id from pg_temp.p17c_ids where name='cycle-renew-sixty'),(select id from pg_temp.p17c_ids where name='ent-four-c'),
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',1,86400,3600,0,
    clock_timestamp(),clock_timestamp()+interval '1 day',clock_timestamp());
insert into public.fixed_renewal_holds(
  id,renewal_id,order_id,student_user_id,idempotency_key,created_at,expires_at
) values
  ('7d000000-0000-0000-0000-000000000110','7d000000-0000-0000-0000-000000000100',
    (select id from pg_temp.p17c_ids where name='order-twelve-50'),'7c000000-0000-0000-0000-000000000001',
    'p17c-renewal-good-hold',clock_timestamp(),clock_timestamp()+interval '1 hour'),
  ('7d000000-0000-0000-0000-000000000111','7d000000-0000-0000-0000-000000000101',
    (select id from pg_temp.p17c_ids where name='order-twelve-80'),'7c000000-0000-0000-0000-000000000001',
    'p17c-renewal-bad-hold',clock_timestamp(),clock_timestamp()+interval '1 hour'),
  ('7d000000-0000-0000-0000-000000000112','7d000000-0000-0000-0000-000000000102',
    (select id from pg_temp.p17c_ids where name='order-new-60'),'7c000000-0000-0000-0000-000000000001',
    'p17c-renewal-sixty-hold',clock_timestamp(),clock_timestamp()+interval '1 hour');

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select is(public.convert_fixed_renewal(
  '7d000000-0000-0000-0000-000000000100','7d000000-0000-0000-0000-000000000110',
  (select id from pg_temp.p17c_ids where name='ent-twelve-50'),
  (select id from pg_temp.p17c_ids where name='event-twelve-50'),'P1-7C compatible renewal')->>'status',
  'renewed','C7 4x50 to 12x50 renewal succeeds');
reset role;
select is(
  (select array[e.lesson_duration_minutes,c.sequence_number]
   from public.fixed_cycle_renewals r
   join public.fixed_entitlement_cycles c on c.id=r.successful_next_cycle_id
   join public.entitlements e on e.id=c.entitlement_id
   where r.id='7d000000-0000-0000-0000-000000000100'),
  array[50,2],'C7 compatible renewal creates 12x50 Cycle 2');
insert into pg_temp.p17c_ids
select 'renewed-cycle-good',successful_next_cycle_id
from public.fixed_cycle_renewals
where id='7d000000-0000-0000-0000-000000000100';

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select is((public.convert_fixed_renewal(
  '7d000000-0000-0000-0000-000000000100','7d000000-0000-0000-0000-000000000110',
  (select id from pg_temp.p17c_ids where name='ent-twelve-50'),
  (select id from pg_temp.p17c_ids where name='event-twelve-50'),'P1-7C compatible renewal retry')->>'cycle_id')::uuid,
  (select id from pg_temp.p17c_ids where name='renewed-cycle-good'),
  'Compatible renewal retry returns the same Cycle 2');
select is(public.convert_fixed_renewal(
  '7d000000-0000-0000-0000-000000000101','7d000000-0000-0000-0000-000000000111',
  (select id from pg_temp.p17c_ids where name='ent-twelve-80'),
  (select id from pg_temp.p17c_ids where name='event-twelve-80'),'P1-7C incompatible renewal')->>'status',
  'rejected','C8 4x50 to 12x80 renewal is rejected');
select is(public.convert_fixed_renewal(
  '7d000000-0000-0000-0000-000000000101','7d000000-0000-0000-0000-000000000111',
  (select id from pg_temp.p17c_ids where name='ent-twelve-80'),
  (select id from pg_temp.p17c_ids where name='event-twelve-80'),'P1-7C incompatible renewal retry')->>'error',
  'LESSON_DURATION_MISMATCH','C12 incompatible renewal retry returns the stable error');
reset role;
select is((select count(*) from public.fixed_entitlement_cycles
  where entitlement_id=(select id from pg_temp.p17c_ids where name='ent-twelve-80')),0::bigint,
  'C8 mismatched renewal creates no next cycle');
select is(
  (select row(r.state::text,h.status::text,s.status::text,c.status::text)::text
   from public.fixed_cycle_renewals r
   join public.fixed_renewal_holds h on h.renewal_id=r.id
   join public.recurring_lesson_series s on s.id=r.series_id
   join public.fixed_entitlement_cycles c on c.id=r.current_cycle_id
   where r.id='7d000000-0000-0000-0000-000000000101'),
  row('window_open','active','active','active')::text,
  'C8 rejection preserves renewal, hold, Series priority, and current cycle history');

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select is(public.convert_fixed_renewal(
  '7d000000-0000-0000-0000-000000000102','7d000000-0000-0000-0000-000000000112',
  (select id from pg_temp.p17c_ids where name='ent-new-60'),
  (select id from pg_temp.p17c_ids where name='event-new-60'),'P1-7C new snapshot mismatch')->>'error',
  'LESSON_DURATION_MISMATCH','C10 new 60-minute Entitlement cannot renew a 50-minute Series');
reset role;
select is((select count(*) from public.fixed_entitlement_cycles
  where entitlement_id=(select id from pg_temp.p17c_ids where name='ent-new-60')),0::bigint,
  'C10 rejected new snapshot creates no cycle');
select is(
  (select array[
    (select lesson_duration_minutes from public.lesson_package_product_configs
      where product_id='7c000000-0000-0000-0000-000000000020'),
    (select lesson_duration_minutes from public.entitlements
      where id=(select id from pg_temp.p17_ids where name='ent-50')),
    (select lesson_duration_minutes from public.entitlements
      where id=(select id from pg_temp.p17c_ids where name='ent-new-60'))
  ]),array[60,50,60],
  'C9/C10 attachment uses each purchase-time Entitlement snapshot, not mutable Product config');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000003',true);
select public.set_fixed_checkout_hold_policy(
  '7c000000-0000-0000-0000-000000000020',1800,'P1-7C checkout hold policy');
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000001',true);
insert into pg_temp.p17c_ids values('checkout-hold',public.claim_fixed_checkout_hold(
  '7c000000-0000-0000-0000-000000000002','7c000000-0000-0000-0000-000000000010',
  'p17-fifty',extract(dow from current_date+25)::smallint,'15:00','UTC',current_date+25,current_date+25,
  'p17c-checkout-hold-sixty'));
reset role;
insert into pg_temp.p17c_ids
select 'checkout-order',order_id from public.fixed_checkout_holds
where id=(select id from pg_temp.p17c_ids where name='checkout-hold');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000003',true);
select public.admin_confirm_cash_payment(
  (select id from pg_temp.p17c_ids where name='checkout-order'),
  'p17c-checkout-hold-paid','P1-7C checkout hold paid');
reset role;
insert into pg_temp.p17c_ids
select 'checkout-event',id from public.order_fulfillment_events
where order_id=(select id from pg_temp.p17c_ids where name='checkout-order');
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select public.process_order_fulfillment_event(
  (select id from pg_temp.p17c_ids where name='checkout-event'));
reset role;
insert into pg_temp.p17c_ids
select 'checkout-ent',id from public.entitlements
where source_order_id=(select id from pg_temp.p17c_ids where name='checkout-order');
create temporary table p17c_checkout_before as
select (select count(*) from public.recurring_lesson_series) series_count,
  (select count(*) from public.fixed_entitlement_cycles) cycle_count;

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select is(public.convert_fixed_checkout_hold(
  (select id from pg_temp.p17c_ids where name='checkout-hold'),
  (select id from pg_temp.p17_ids where name='ent-50'),
  (select id from pg_temp.p17c_ids where name='checkout-event'),'P1-7C checkout mismatch')->>'error',
  'HOLD_ENTITLEMENT_MISMATCH','C11 checkout conversion rejects a mismatched Entitlement snapshot');
reset role;
select is(
  (select row(h.status::text,
    (select count(*) from public.recurring_lesson_series)-(select series_count from pg_temp.p17c_checkout_before),
    (select count(*) from public.fixed_entitlement_cycles)-(select cycle_count from pg_temp.p17c_checkout_before))::text
   from public.fixed_checkout_holds h where h.id=(select id from pg_temp.p17c_ids where name='checkout-hold')),
  row('active',0::bigint,0::bigint)::text,
  'C11 rejected checkout conversion fully rolls back ownership and cycle mutations');
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select is(public.convert_fixed_checkout_hold(
  (select id from pg_temp.p17c_ids where name='checkout-hold'),
  (select id from pg_temp.p17c_ids where name='checkout-ent'),
  (select id from pg_temp.p17c_ids where name='checkout-event'),'P1-7C checkout compatible retry')->>'status',
  'converted','C11 compatible checkout conversion succeeds after rejected mismatch');
reset role;
select is(
  (select array[s.duration_minutes::integer,e.lesson_duration_minutes]
   from public.fixed_checkout_holds h
   join public.recurring_lesson_series s on s.id=h.series_id
   join public.fixed_entitlement_cycles c on c.id=h.cycle_id
   join public.entitlements e on e.id=c.entitlement_id
   where h.id=(select id from pg_temp.p17c_ids where name='checkout-hold')),
  array[60,60],'C11 compatible checkout conversion persists equal Series and Entitlement durations');

select * from finish();
rollback;
