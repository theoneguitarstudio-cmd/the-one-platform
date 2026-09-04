-- P1-7 contract: value-bearing duration must be revalidated at the write boundary.
-- Expected red lights intentionally remain visible where production lacks policy.
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
  'D5 product config mutation does not rewrite fulfillment or Entitlement duration snapshots'
);

create temporary table p17_before as
select b.available,b.reserved,b.consumed,b.total,
  (select count(*) from public.bookings x where x.recurring_series_id=(select id from pg_temp.p17_ids where name='series-80')) booking_count,
  (select count(*) from public.lessons x where x.lesson_type='fixed' and x.duration_minutes=80) lesson_count,
  (select count(*) from public.lesson_credit_reservations x where x.entitlement_id=(select id from pg_temp.p17_ids where name='ent-50')) reservation_count,
  (select status::text from public.recurring_lesson_occurrences x
    where x.series_id=(select id from pg_temp.p17_ids where name='series-80')
      and x.occurrence_date=current_date+14) occurrence_status
from private.lesson_credit_balance((select id from pg_temp.p17_ids where name='ent-50')) b;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
select throws_ok($$
  select public.materialize_recurring_lesson_occurrence(
    (select id from pg_temp.p17_ids where name='series-80'),current_date+14,
    (select id from pg_temp.p17_ids where name='ent-50'),'p17-mismatch-fixed-materialization'
  )
$$,'P0001','LESSON_DURATION_MISMATCH',
  'D1 50-minute Entitlement must reject an 80-minute Fixed materialization'
);
reset role;

select is(
  (select row(booking_count,lesson_count,reservation_count,occurrence_status)::text from pg_temp.p17_before),
  (select row(
    (select count(*) from public.bookings x where x.recurring_series_id=(select id from pg_temp.p17_ids where name='series-80')),
    (select count(*) from public.lessons x where x.lesson_type='fixed' and x.duration_minutes=80),
    (select count(*) from public.lesson_credit_reservations x where x.entitlement_id=(select id from pg_temp.p17_ids where name='ent-50')),
    (select status::text from public.recurring_lesson_occurrences x
      where x.series_id=(select id from pg_temp.p17_ids where name='series-80')
        and x.occurrence_date=current_date+14)
  )::text),
  'D3 rejected mismatch must create no Booking, Lesson, or Reservation and must preserve occurrence priority'
);
select is(
  (select row(available,reserved,consumed,total)::text from pg_temp.p17_before),
  (select row(available,reserved,consumed,total)::text
    from private.lesson_credit_balance((select id from pg_temp.p17_ids where name='ent-50'))),
  'D3 rejected mismatch must leave available, reserved, consumed, and total unchanged'
);

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('cycle-50',public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17_ids where name='series-50'),
    (select id from pg_temp.p17_ids where name='ent-50'),
    (select id from pg_temp.p17_ids where name='event-50'),'P1-7 compatible cycle control'))
$$,'D8 compatible Fixed cycle attachment remains allowed');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('booking-fixed-50',public.materialize_recurring_lesson_occurrence(
    (select id from pg_temp.p17_ids where name='series-50'),current_date+15,
    (select id from pg_temp.p17_ids where name='ent-50'),'p17-compatible-fixed-materialization'))
$$,'D2 exact 50-to-50 Fixed materialization remains allowed');
reset role;
select is(
  (select l.duration_minutes::integer from public.bookings b join public.lessons l on l.id=b.lesson_id
    where b.id=(select id from pg_temp.p17_ids where name='booking-fixed-50')),
  50,'D2 compatible Fixed Lesson preserves the 50-minute duration'
);

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select throws_ok($$
  select public.attach_fixed_entitlement_cycle(
    (select id from pg_temp.p17_ids where name='series-50'),
    (select id from pg_temp.p17_ids where name='ent-80'),
    (select id from pg_temp.p17_ids where name='event-80'),'P1-7 incompatible cycle contract')
$$,'P0001','LESSON_DURATION_MISMATCH',
  'D4 strict duration compatibility rejects attaching 80-minute value to a 50-minute Fixed cycle');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000001',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('booking-flex-50',public.create_lesson_booking(
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',
    '7c000000-0000-0000-0000-000000000010',(select id from pg_temp.p17_ids where name='ent-50'),
    (current_date+16)::timestamp+time '11:00','UTC','p17-flex-duration-control','P1-7 Flexible duration control'))
$$,'D6 Flexible booking derives duration from the selected Entitlement');
reset role;
select is(
  (select extract(epoch from (b.ends_at-b.starts_at))/60 from public.bookings b
    where b.id=(select id from pg_temp.p17_ids where name='booking-flex-50')),
  50::numeric,'D6 Flexible Booking duration equals the Entitlement snapshot'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000001',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('booking-makeup-50',public.create_makeup_lesson_booking(
    '7c000000-0000-0000-0000-000000000031','7c000000-0000-0000-0000-000000000001',
    '7c000000-0000-0000-0000-000000000002','7c000000-0000-0000-0000-000000000010',
    (current_date+17)::timestamp+time '13:00','UTC','p17-makeup-duration-control','P1-7 Makeup duration control'))
$$,'D7 Makeup booking remains independent of ordinary credit duration validation');
reset role;
select is(
  (select array[origin.duration_minutes::integer,makeup.duration_minutes::integer]
    from public.lessons origin
    join public.bookings b on b.id=(select id from pg_temp.p17_ids where name='booking-makeup-50')
    join public.lessons makeup on makeup.id=b.lesson_id
    where origin.id='7c000000-0000-0000-0000-000000000030'),
  array[50,50],'D7 Makeup Lesson duration is inherited from the origin Lesson'
);

select ok(
  (select count(*)=1 from public.order_item_fulfillment_snapshots s
    join public.entitlements e on e.source_order_item_id=s.order_item_id
    where e.id=(select id from pg_temp.p17_ids where name='ent-50')
      and s.lesson_duration_minutes=e.lesson_duration_minutes),
  'D5 the immutable fulfillment snapshot remains the Entitlement duration source'
);
select ok(
  (select count(*)=1 from public.fixed_entitlement_cycles c
    join public.recurring_lesson_series s on s.id=c.series_id
    join public.entitlements e on e.id=c.entitlement_id
    where c.id=(select id from pg_temp.p17_ids where name='cycle-50')
      and s.duration_minutes=e.lesson_duration_minutes),
  'D8 compatible cycle control retains equal Series and Entitlement durations'
);

select * from finish();
rollback;
