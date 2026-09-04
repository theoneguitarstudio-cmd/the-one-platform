-- P1-7 evidence: record current production behavior without correcting it.
begin;
select plan(14);
\set p17_fixture_include 1
\ir lesson_duration_entitlement_fixture.sql

select is(
  (select array[
    (select lesson_duration_minutes from public.lesson_package_product_configs
      where product_id='7c000000-0000-0000-0000-000000000020'),
    (select s.lesson_duration_minutes from public.order_item_fulfillment_snapshots s
      join public.order_items i on i.id=s.order_item_id
      where i.order_id=(select id from pg_temp.p17_ids where name='order-50')),
    (select lesson_duration_minutes from public.entitlements
      where id=(select id from pg_temp.p17_ids where name='ent-50'))
  ]),array[60,50,50],
  'Evidence: current config changes while fulfillment and Entitlement snapshots stay at 50'
);

create temporary table p17_balance_before as
select * from private.lesson_credit_balance((select id from pg_temp.p17_ids where name='ent-50'));
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
select throws_ok($$
  select public.materialize_recurring_lesson_occurrence(
    (select id from pg_temp.p17_ids where name='series-80'),current_date+14,
    (select id from pg_temp.p17_ids where name='ent-50'),'p17-evidence-fixed-mismatch')
$$,'P0001','LESSON_DURATION_MISMATCH',
  'Evidence: Fixed materialization rejects 50-minute value for an 80-minute Lesson');
reset role;
select is(
  (select count(*) from public.bookings b
    where b.recurring_series_id=(select id from pg_temp.p17_ids where name='series-80')),
  0::bigint,'Evidence: rejected mismatch creates no Booking'
);
select is(
  (select row(after.available-before.available,after.reserved-before.reserved,
    after.consumed-before.consumed,after.total-before.total)::text
   from pg_temp.p17_balance_before before
   cross join private.lesson_credit_balance((select id from pg_temp.p17_ids where name='ent-50')) after),
  row(0,0,0,0)::text,
  'Evidence: rejected mismatch leaves credit balances unchanged'
);
select is(
  (select status::text from public.recurring_lesson_occurrences
    where series_id=(select id from pg_temp.p17_ids where name='series-80')
      and occurrence_date=current_date+14),
  'planned','Evidence: rejected mismatch preserves the Fixed occurrence state'
);

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('cycle-50',public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17_ids where name='series-50'),
    (select id from pg_temp.p17_ids where name='ent-50'),
    (select id from pg_temp.p17_ids where name='event-50'),'P1-7 compatible cycle evidence'))
$$,'Evidence: equal-duration Fixed cycle attachment succeeds');
select lives_ok($$
  insert into pg_temp.p17_ids values('cycle-80-on-50',public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17_ids where name='series-50'),
    (select id from pg_temp.p17_ids where name='ent-80'),
    (select id from pg_temp.p17_ids where name='event-80'),'P1-7 mismatched cycle evidence'))
$$,'Evidence: current cycle authority also accepts an 80-minute Entitlement on a 50-minute Series');
reset role;
select is(
  (select array[e.lesson_duration_minutes,s.duration_minutes::integer]
    from public.fixed_entitlement_cycles c
    join public.entitlements e on e.id=c.entitlement_id
    join public.recurring_lesson_series s on s.id=c.series_id
    where c.id=(select id from pg_temp.p17_ids where name='cycle-80-on-50')),
  array[80,50],'Evidence: attached cycle persists the opposite-direction duration mismatch'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('booking-fixed-50',public.materialize_recurring_lesson_occurrence(
    (select id from pg_temp.p17_ids where name='series-50'),current_date+15,
    (select id from pg_temp.p17_ids where name='ent-50'),'p17-evidence-fixed-match'))
$$,'Evidence: exact-match Fixed materialization remains valid');
reset role;
select is(
  (select l.duration_minutes::integer from public.bookings b join public.lessons l on l.id=b.lesson_id
    where b.id=(select id from pg_temp.p17_ids where name='booking-fixed-50')),
  50,'Evidence: exact-match Fixed control produces a 50-minute Lesson'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000001',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('booking-flex-50',public.create_lesson_booking(
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',
    '7c000000-0000-0000-0000-000000000010',(select id from pg_temp.p17_ids where name='ent-50'),
    (current_date+16)::timestamp+time '11:00','UTC','p17-evidence-flex-control','P1-7 Flexible evidence'))
$$,'Evidence: Flexible Booking accepts no independent duration input');
reset role;
select is(
  (select array[e.lesson_duration_minutes,(extract(epoch from (b.ends_at-b.starts_at))/60)::integer]
    from public.bookings b
    join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
    join public.entitlements e on e.id=r.entitlement_id
    where b.id=(select id from pg_temp.p17_ids where name='booking-flex-50')),
  array[50,50],'Evidence: Flexible Booking duration is derived from the selected Entitlement'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000001',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('booking-makeup-50',public.create_makeup_lesson_booking(
    '7c000000-0000-0000-0000-000000000031','7c000000-0000-0000-0000-000000000001',
    '7c000000-0000-0000-0000-000000000002','7c000000-0000-0000-0000-000000000010',
    (current_date+17)::timestamp+time '13:00','UTC','p17-evidence-makeup-control','P1-7 Makeup evidence'))
$$,'Evidence: Makeup Booking remains valid without ordinary credit consumption');
reset role;
select is(
  (select array[origin.duration_minutes::integer,makeup.duration_minutes::integer]
    from public.lessons origin
    join public.bookings b on b.id=(select id from pg_temp.p17_ids where name='booking-makeup-50')
    join public.lessons makeup on makeup.id=b.lesson_id
    where origin.id='7c000000-0000-0000-0000-000000000030'),
  array[50,50],'Evidence: Makeup Booking inherits the origin Lesson duration'
);

select * from finish();
rollback;
