\if :{?p17_fixture_include}

create temporary table p17_ids(name text primary key,id uuid not null);
grant select,insert,update on pg_temp.p17_ids to authenticated,service_role;

insert into auth.users(id,email) values
  ('7c000000-0000-0000-0000-000000000001','p17-student@example.invalid'),
  ('7c000000-0000-0000-0000-000000000002','p17-teacher@example.invalid'),
  ('7c000000-0000-0000-0000-000000000003','p17-admin@example.invalid');
insert into public.user_roles(user_id,role) values
  ('7c000000-0000-0000-0000-000000000002','teacher'),
  ('7c000000-0000-0000-0000-000000000003','admin');
insert into public.teacher_profiles(
  user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,
  default_meeting_provider,default_meeting_url
) values(
  '7c000000-0000-0000-0000-000000000002','p17-teacher','P1-7 duration fixture',
  'active',true,array['online']::public.teaching_mode[],500,
  'manual_google_meet','https://meet.google.com/abc-defg-hij'
);
insert into public.student_teacher_relationships(
  id,student_user_id,teacher_user_id,relationship_status,preferred_mode
) values(
  '7c000000-0000-0000-0000-000000000010',
  '7c000000-0000-0000-0000-000000000001',
  '7c000000-0000-0000-0000-000000000002','active','online'
);
insert into public.teacher_scheduling_settings(
  teacher_user_id,timezone,minimum_booking_notice_minutes,booking_horizon_days,slot_interval_minutes
) values('7c000000-0000-0000-0000-000000000002','UTC',0,90,10);
insert into public.teacher_availability_rules(
  teacher_user_id,weekday,local_start_time,local_end_time,timezone,
  effective_from,effective_until,is_active,created_by
)
select '7c000000-0000-0000-0000-000000000002',d::smallint,'00:00','23:59','UTC',
  current_date,current_date+90,true,'7c000000-0000-0000-0000-000000000002'
from generate_series(0,6) d;

insert into public.products(
  id,product_type,status,public_slug,name,currency,base_price_amount,
  owner_type,is_public,is_purchasable,published_at
) values
  ('7c000000-0000-0000-0000-000000000020','lesson_package','active',
    'p17-fifty','P1-7 50 minute package','TWD',3200,'platform',true,true,now()),
  ('7c000000-0000-0000-0000-000000000021','lesson_package','active',
    'p17-eighty','P1-7 80 minute package','TWD',4800,'platform',true,true,now());
insert into public.lesson_package_product_configs(
  product_id,lesson_count,validity_value,validity_unit,
  lesson_duration_minutes,booking_mode_eligibility
) values
  ('7c000000-0000-0000-0000-000000000020',4,12,'months',50,'both'),
  ('7c000000-0000-0000-0000-000000000021',4,12,'months',80,'fixed');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000001',true);
insert into pg_temp.p17_ids values
  ('order-50',public.create_checkout_order('p17-fifty',1,'p17-duration-checkout-fifty')),
  ('order-80',public.create_checkout_order('p17-eighty',1,'p17-duration-checkout-eighty'));
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000003',true);
select public.admin_confirm_cash_payment(id,'p17-duration-paid-'||name,'P1-7 paid fixture')
from pg_temp.p17_ids where name like 'order-%';
reset role;

insert into pg_temp.p17_ids
select 'event-'||substr(r.name,7),e.id
from pg_temp.p17_ids r
join public.order_fulfillment_events e on e.order_id=r.id
where r.name like 'order-%';
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select public.process_order_fulfillment_event(id)
from pg_temp.p17_ids where name like 'event-%';
reset role;
insert into pg_temp.p17_ids
select 'ent-'||substr(r.name,7),e.id
from pg_temp.p17_ids r
join public.entitlements e on e.source_order_id=r.id
where r.name like 'order-%';

-- Exercise the supported product configuration authority after fulfillment.
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000003',true);
select public.admin_set_lesson_package_product_config(
  '7c000000-0000-0000-0000-000000000020',4,12,'months',60,'both',
  'P1-7 post-fulfillment product duration change'
);

select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
insert into pg_temp.p17_ids values
  ('series-80',public.create_recurring_lesson_series(
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',
    '7c000000-0000-0000-0000-000000000010',null,
    extract(dow from current_date+14)::smallint,'09:00','UTC',80::smallint,
    current_date+14,current_date+14,'P1-7 80 minute Fixed series')),
  ('series-50',public.create_recurring_lesson_series(
    '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',
    '7c000000-0000-0000-0000-000000000010',null,
    extract(dow from current_date+15)::smallint,'09:00','UTC',50::smallint,
    current_date+15,current_date+15,'P1-7 50 minute Fixed series'));
reset role;

insert into public.lessons(
  id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
  starts_at,ends_at,duration_minutes,timezone_anchor,status,meeting_provider,meeting_url
) values(
  '7c000000-0000-0000-0000-000000000030',
  '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000002',
  '7c000000-0000-0000-0000-000000000010','flexible','online',
  now()-interval '8 days',now()-interval '8 days'+interval '50 minutes',50,'UTC','completed',
  'manual_google_meet','https://meet.google.com/abc-defg-hij'
);
insert into public.makeup_rights(
  id,student_user_id,origin_lesson_id,origin_teacher_user_id,current_teacher_user_id,
  origin_entitlement_id,source,source_operation_key,status,valid_until,reason,created_by
) values(
  '7c000000-0000-0000-0000-000000000031',
  '7c000000-0000-0000-0000-000000000001','7c000000-0000-0000-0000-000000000030',
  '7c000000-0000-0000-0000-000000000002','7c000000-0000-0000-0000-000000000002',
  (select id from pg_temp.p17_ids where name='ent-50'),'admin_compensation',
  'p17-duration-makeup-right','available',now()+interval '60 days',
  'P1-7 Makeup duration control','7c000000-0000-0000-0000-000000000003'
);

\else

begin;
select plan(1);
select pass('P1-7 fixture is side-effect free when discovered as a standalone DB test');
select * from finish();
rollback;

\endif
