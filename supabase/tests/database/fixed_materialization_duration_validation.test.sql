-- P1-7A exact-match validation at the Fixed materialization mutation boundary.
begin;
select plan(26);
\set p17_fixture_include 1
\ir lesson_duration_entitlement_fixture.sql

select has_function(
  'private','validate_lesson_duration_compatibility',array['uuid','integer'],
  'Shared private duration compatibility authority exists'
);
select ok(not has_function_privilege(
  'anon','private.validate_lesson_duration_compatibility(uuid,integer)','EXECUTE'),
  'anon cannot execute the private duration validator'
);
select ok(not has_function_privilege(
  'authenticated','private.validate_lesson_duration_compatibility(uuid,integer)','EXECUTE'),
  'authenticated cannot execute the private duration validator'
);
select ok(not has_function_privilege(
  'service_role','private.validate_lesson_duration_compatibility(uuid,integer)','EXECUTE'),
  'service_role cannot directly execute the private duration validator'
);
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
  'A10 mutable Product change does not alter fulfillment or Entitlement snapshots'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('p17a-exact-booking',public.materialize_recurring_lesson_occurrence(
    (select id from pg_temp.p17_ids where name='series-50'),current_date+15,
    (select id from pg_temp.p17_ids where name='ent-50'),'p17a-exact-duration-materialization'))
$$,'A1 exact 50-to-50 Fixed materialization succeeds');
reset role;
select is(
  (select row(l.duration_minutes,r.status::text,o.status::text)::text
   from public.bookings b
   join public.lessons l on l.id=b.lesson_id
   join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
   join public.recurring_lesson_occurrences o on o.booking_id=b.id
   where b.id=(select id from pg_temp.p17_ids where name='p17a-exact-booking')),
  row(50,'reserved','materialized')::text,
  'A1 exact match creates the 50-minute Lesson, ordinary reservation, and materialized occurrence'
);

create temporary table p17a_before as
select b.available,b.reserved,b.consumed,b.total,
  (select count(*) from public.bookings) bookings,
  (select count(*) from public.lessons) lessons,
  (select count(*) from public.lesson_credit_reservations) reservations,
  (select count(*) from public.lesson_credit_ledger) ledger_entries,
  (select status::text from public.recurring_lesson_occurrences
    where series_id=(select id from pg_temp.p17_ids where name='series-80')
      and occurrence_date=current_date+14) occurrence_status
from private.lesson_credit_balance((select id from pg_temp.p17_ids where name='ent-50')) b;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
select throws_ok($$
  select public.materialize_recurring_lesson_occurrence(
    (select id from pg_temp.p17_ids where name='series-80'),current_date+14,
    (select id from pg_temp.p17_ids where name='ent-50'),'p17a-forward-duration-mismatch')
$$,'P0001','LESSON_DURATION_MISMATCH','A2 50-to-80 Fixed mismatch is rejected');
reset role;
select is((select count(*) from public.bookings),(select bookings from pg_temp.p17a_before),
  'A4 mismatch creates no Booking');
select is((select count(*) from public.lessons),(select lessons from pg_temp.p17a_before),
  'A5 mismatch creates no Lesson');
select is((select count(*) from public.lesson_credit_reservations),(select reservations from pg_temp.p17a_before),
  'A6 mismatch creates no Reservation');
select is((select count(*) from public.lesson_credit_ledger),(select ledger_entries from pg_temp.p17a_before),
  'A7 mismatch creates no ledger entry');
select is(
  (select status::text from public.recurring_lesson_occurrences
    where series_id=(select id from pg_temp.p17_ids where name='series-80')
      and occurrence_date=current_date+14),
  (select occurrence_status from pg_temp.p17a_before),'A8 mismatch preserves occurrence state'
);
select is(
  (select row(available,reserved,consumed,total)::text
    from private.lesson_credit_balance((select id from pg_temp.p17_ids where name='ent-50'))),
  (select row(available,reserved,consumed,total)::text from pg_temp.p17a_before),
  'A7 mismatch preserves available, reserved, consumed, and total credit balances'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
insert into pg_temp.p17_ids values('p17a-reverse-series',public.create_recurring_lesson_series(
  '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',
  '7c000000-0000-0000-0000-000000000010',null,
  extract(dow from current_date+18)::smallint,'09:00','UTC',50::smallint,
  current_date+18,current_date+18,'P1-7A reverse mismatch series'));
select throws_ok($$
  select public.materialize_recurring_lesson_occurrence(
    (select id from pg_temp.p17_ids where name='p17a-reverse-series'),current_date+18,
    (select id from pg_temp.p17_ids where name='ent-80'),'p17a-reverse-duration-mismatch')
$$,'P0001','LESSON_DURATION_MISMATCH','A3 80-to-50 Fixed mismatch is rejected');
reset role;
select is(
  (select count(*) from public.bookings
    where recurring_series_id=(select id from pg_temp.p17_ids where name='p17a-reverse-series')),
  0::bigint,'A3 reverse mismatch creates no Booking'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
select is(public.materialize_recurring_lesson_occurrence(
  (select id from pg_temp.p17_ids where name='series-80'),current_date+14,null,
  'p17a-credit-required-transition'),null::uuid,
  'A9 missing entitlement transitions the occurrence to credit_required');
select throws_ok($$
  select public.materialize_recurring_lesson_occurrence(
    (select id from pg_temp.p17_ids where name='series-80'),current_date+14,
    (select id from pg_temp.p17_ids where name='ent-50'),'p17a-credit-required-wrong-duration')
$$,'P0001','LESSON_DURATION_MISMATCH','A9 credit_required occurrence still rejects wrong duration');
reset role;
select is(
  (select status::text from public.recurring_lesson_occurrences
    where series_id=(select id from pg_temp.p17_ids where name='series-80')
      and occurrence_date=current_date+14),
  'credit_required','A9 rejected retry preserves credit_required state'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000001',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('p17a-flex-booking',public.create_lesson_booking(
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',
    '7c000000-0000-0000-0000-000000000010',(select id from pg_temp.p17_ids where name='ent-50'),
    (current_date+16)::timestamp+time '11:00','UTC','p17a-flex-duration-control','P1-7A Flexible control'))
$$,'A11 Flexible booking remains unchanged');
reset role;
select is(
  (select extract(epoch from (ends_at-starts_at))/60 from public.bookings
    where id=(select id from pg_temp.p17_ids where name='p17a-flex-booking')),
  50::numeric,'A11 Flexible duration still derives from the Entitlement snapshot'
);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000001',true);
select lives_ok($$
  insert into pg_temp.p17_ids values('p17a-makeup-booking',public.create_makeup_lesson_booking(
    '7c000000-0000-0000-0000-000000000031','7c000000-0000-0000-0000-000000000001',
    '7c000000-0000-0000-0000-000000000002','7c000000-0000-0000-0000-000000000010',
    (current_date+17)::timestamp+time '13:00','UTC','p17a-makeup-duration-control','P1-7A Makeup control'))
$$,'A12 Makeup booking remains isolated from ordinary entitlement duration validation');
reset role;
select is(
  (select array[origin.duration_minutes::integer,makeup.duration_minutes::integer]
   from public.lessons origin
   join public.bookings b on b.id=(select id from pg_temp.p17_ids where name='p17a-makeup-booking')
   join public.lessons makeup on makeup.id=b.lesson_id
   where origin.id='7c000000-0000-0000-0000-000000000030'),
  array[50,50],'A12 Makeup duration remains inherited from the origin Lesson'
);

select is(
  (select count(*) from public.bookings
   where recurring_series_id=(select id from pg_temp.p17_ids where name='series-80')),
  0::bigint,'All wrong-duration attempts leave the 80-minute Series without a Booking'
);
select is(
  (select count(*) from public.lesson_credit_reservations r
   where r.entitlement_id=(select id from pg_temp.p17_ids where name='ent-80')),
  0::bigint,'Reverse mismatch leaves the 80-minute Entitlement without a Reservation'
);
select is(
  (select lesson_duration_minutes from public.entitlements
   where id=(select id from pg_temp.p17_ids where name='ent-50')),
  50,'Validator continues to use the immutable Entitlement snapshot after Product mutation'
);

select * from finish();
rollback;
