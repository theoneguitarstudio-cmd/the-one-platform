-- P1-4 positive controls and missing-flow evidence using EXISTING domain RPCs.
-- Passing these controls does NOT implement cycles, renewal or checkout holds.
-- Missing-domain expectations live in fixed_renewal_lifecycle_contract.test.sql.
begin;
select no_plan();
create temporary table renewal_ids(name text primary key,id uuid);
grant select,insert,update on renewal_ids to authenticated,service_role;
insert into auth.users(id,email) values
('66000000-0000-0000-0000-000000000001','renewal-a@example.invalid'),
('66000000-0000-0000-0000-000000000002','renewal-b@example.invalid'),
('66000000-0000-0000-0000-000000000003','renewal-teacher@example.invalid'),
('66000000-0000-0000-0000-000000000004','renewal-admin@example.invalid');
insert into public.user_roles(user_id,role) values
('66000000-0000-0000-0000-000000000003','teacher'),('66000000-0000-0000-0000-000000000004','admin');
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,
  teaching_modes,trial_price_twd,default_meeting_provider,default_meeting_url) values
('66000000-0000-0000-0000-000000000003','renewal-teacher','Renewal fixture','active',true,
  array['online']::public.teaching_mode[],500,'manual_google_meet','https://meet.google.com/abc-defg-hij');
insert into public.student_teacher_relationships(id,student_user_id,teacher_user_id,relationship_status,preferred_mode) values
('66000000-0000-0000-0000-000000000011','66000000-0000-0000-0000-000000000001','66000000-0000-0000-0000-000000000003','active','online'),
('66000000-0000-0000-0000-000000000012','66000000-0000-0000-0000-000000000002','66000000-0000-0000-0000-000000000003','active','online');
insert into public.products(id,product_type,status,public_slug,name,currency,base_price_amount,
  owner_type,is_public,is_purchasable,published_at) values
('66000000-0000-0000-0000-000000000021','lesson_package','active','renewal-four','Four Fixed','TWD',3200,'platform',true,true,now()),
('66000000-0000-0000-0000-000000000022','lesson_package','active','renewal-twelve','Twelve Fixed','TWD',8400,'platform',true,true,now());
insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,
  lesson_duration_minutes,booking_mode_eligibility) values
('66000000-0000-0000-0000-000000000021',4,12,'months',50,'fixed'),
('66000000-0000-0000-0000-000000000022',12,12,'months',50,'fixed');
-- END CONCURRENCY FIXTURE: the in-memory two-session audit reuses only this
-- setup, then exercises checkout; it does not invent a production hold function.

set local role authenticated;
select set_config('request.jwt.claim.sub','66000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.set_teacher_scheduling_settings('66000000-0000-0000-0000-000000000003','Asia/Taipei',0,60,10,'Renewal fixture')$$,'Configure Teacher horizon');
select lives_ok($$insert into renewal_ids values('series',public.create_recurring_lesson_series(
  '66000000-0000-0000-0000-000000000001','66000000-0000-0000-0000-000000000003',
  '66000000-0000-0000-0000-000000000011',null,extract(dow from current_date)::smallint,
  '20:00','Asia/Taipei',50::smallint,current_date,null,'Long term Fixed owner'))$$,
  'Current authority: Teacher can create permanent series before purchase or fulfillment');
reset role;
create temporary table series_before as select * from public.recurring_lesson_series where id=(select id from renewal_ids where name='series');
select is((select count(*) from public.entitlements where beneficiary_user_id='66000000-0000-0000-0000-000000000001'),0::bigint,
  'Series already owns priority without any entitlement/cycle');
select ok(not private.scheduling_slot_clear('66000000-0000-0000-0000-000000000002',
  '66000000-0000-0000-0000-000000000003',private.resolve_scheduling_local_datetime(current_date+35,'20:00','Asia/Taipei'),
  private.resolve_scheduling_local_datetime(current_date+35,'20:00','Asia/Taipei')+interval '50 minutes'),
  'Existing Fixed priority blocks another Student independently of payment');

set local role authenticated;
select set_config('request.jwt.claim.sub','66000000-0000-0000-0000-000000000001',true);
select lives_ok($$insert into renewal_ids select name,public.create_checkout_order(slug,1,'p14-audit-'||name||'-checkout')
  from (values('order-four-a','renewal-four'),('order-four-b','renewal-four'),('order-twelve','renewal-twelve')) x(name,slug)$$,
  'Buy compatible 4 / 4 / 12 products through checkout RPC');
reset role;
select is((select count(*) from public.orders where buyer_user_id='66000000-0000-0000-0000-000000000001' and payment_status='unpaid'),3::bigint,
  '4B/C/R2: order creation remains unpaid, not renewal success');
select is((select count(*) from public.entitlements where beneficiary_user_id='66000000-0000-0000-0000-000000000001'),0::bigint,
  'Unpaid orders create no entitlement');
select is((select count(*) from public.order_fulfillment_events where order_id in(select id from renewal_ids where name like 'order-%')),0::bigint,
  'Unpaid orders emit no paid fulfillment event');
set local role authenticated;
select set_config('request.jwt.claim.sub','66000000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.admin_confirm_cash_payment(id,'p14-cash-'||name,'Confirmed local cash fixture')
  from renewal_ids where name like 'order-%'$$,'Existing payment authority confirms the three purchases');
reset role;
insert into renewal_ids select 'event-'||r.name,e.id from renewal_ids r join public.order_fulfillment_events e on e.order_id=r.id where r.name like 'order-%';
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$select public.process_order_fulfillment_event(id) from renewal_ids where name like 'event-%'$$,'Service-only fulfillment handles paid orders');
select lives_ok($$select public.process_order_fulfillment_event(id) from renewal_ids where name like 'event-%'$$,'Repeat fulfillment delivery is safe');
reset role;
select is((select count(*) from public.order_fulfillment_events where id in(select id from renewal_ids where name like 'event-%') and status='processed'),3::bigint,'Three fulfilled events processed');
select is((select count(*) from public.entitlements where beneficiary_user_id='66000000-0000-0000-0000-000000000001'),3::bigint,'Retry creates exactly three entitlements, no duplicate');
select is((select sum(available_delta) from public.lesson_credit_ledger where beneficiary_user_id='66000000-0000-0000-0000-000000000001'),20::bigint,'Epic5 alone allocates 4 + 4 + 12 credits once');
select is((select to_jsonb(s) from public.recurring_lesson_series s where id=(select id from renewal_ids where name='series')),
  (select to_jsonb(s) from series_before s),'Fulfillment leaves the entire series unchanged: no cycle attachment transition');
insert into renewal_ids select 'ent-'||r.name,e.id from renewal_ids r join public.entitlements e on e.source_order_id=r.id where r.name like 'order-%';

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','66000000-0000-0000-0000-000000000003',true);
select lives_ok($$insert into renewal_ids select 'booking-'||x.n,public.materialize_recurring_lesson_occurrence(
  (select id from renewal_ids where name='series'),current_date+7*x.n,r.id,'p14-materialize-package-'||x.n)
  from (values(1,'ent-order-four-a'),(2,'ent-order-four-b'),(3,'ent-order-twelve')) x(n,name)
  join renewal_ids r on r.name=x.name$$,'Same series can select three purchased packages per occurrence');
reset role;
select is((select count(distinct b.recurring_series_id) from public.bookings b where b.id in(select id from renewal_ids where name like 'booking-%')),1::bigint,
  'Per-occurrence package changes keep one series ID');
select is((select count(distinct r.entitlement_id) from public.bookings b join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
  where b.id in(select id from renewal_ids where name like 'booking-%')),3::bigint,'Reservation history preserves three package sources');
select is((select count(*) from public.lesson_credit_ledger where beneficiary_user_id='66000000-0000-0000-0000-000000000001' and entry_type='consumption'),0::bigint,
  'These are reservations, not completed cycles; do not infer cycle completion');
select is((select to_jsonb(s) from public.recurring_lesson_series s where id=(select id from renewal_ids where name='series')),
  (select to_jsonb(s) from series_before s),'Owner/base rule/preferred entitlement unchanged across materializations');

set local role authenticated;
select lives_ok($$select public.create_teacher_availability_rule('66000000-0000-0000-0000-000000000003',
  extract(dow from current_date+22)::smallint,'20:00','21:00','Asia/Taipei',current_date,current_date+60,
  'Reschedule availability fixture')$$,'Teacher opens a valid alternate slot');
select lives_ok($$select public.reschedule_lesson_booking((select id from renewal_ids where name='booking-3'),
  private_start,'Asia/Taipei','Lawful final-lesson delay') from
  (select ((current_date+22)+time '20:00') at time zone 'Asia/Taipei' private_start) x$$,'Existing reschedule moves a lesson without consuming credit');
reset role;
select is((select r.status from public.bookings b join public.lesson_credit_reservations r on r.id=b.credit_reservation_id
  where b.id=(select id from renewal_ids where name='booking-3')),'reserved'::public.lesson_credit_reservation_status,
  'Delayed lesson keeps reserved value; no cycle completion model exists');
set local role authenticated;
select set_config('request.jwt.claim.sub','66000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.set_recurring_lesson_series_status((select id from renewal_ids where name='series'),'ended','Student non-renew intent')$$,
  '42501','UNAUTHORIZED_BOOKING_ACTION','Student cannot use Teacher/Admin immediate-end RPC as renewal intent');
select set_config('request.jwt.claim.sub','66000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.set_recurring_lesson_series_status((select id from renewal_ids where name='series'),'ended','Explicit admin-style lifecycle end')$$,
  'Manual lifecycle end is available without a renewal deadline guard');
select lives_ok($$insert into renewal_ids values('series-b',public.create_recurring_lesson_series(
  '66000000-0000-0000-0000-000000000002','66000000-0000-0000-0000-000000000003',
  '66000000-0000-0000-0000-000000000012',null,extract(dow from current_date+35)::smallint,
  '20:00','Asia/Taipei',50::smallint,current_date+35,null,'B acquires released future priority'))$$,'B can acquire released future slot through existing Teacher authority');
select throws_ok($$select public.create_recurring_lesson_series(
  '66000000-0000-0000-0000-000000000001','66000000-0000-0000-0000-000000000003',
  '66000000-0000-0000-0000-000000000011',null,extract(dow from current_date+35)::smallint,
  '20:00','Asia/Taipei',50::smallint,current_date+35,null,'A tries to retake B slot')$$,
  'P0001','RECURRING_SERIES_CONFLICT','P1-3 still blocks direct series creation from displacing B');
reset role;
select is((select count(*) from public.bookings where id in(select id from renewal_ids where name like 'booking-%') and status in('confirmed','rescheduled')),3::bigint,
  'Immediate series end leaves existing materialized bookings; it is not cycle-end intent');
select * from finish();
rollback;
