\if :{?p16_fixture_include}

create temporary table p16_ids(name text primary key,id uuid not null);
grant select,insert,update on pg_temp.p16_ids to authenticated;

insert into auth.users(id,email) values
  ('7b000000-0000-0000-0000-000000000001','p16-student@example.invalid'),
  ('7b000000-0000-0000-0000-000000000002','p16-teacher@example.invalid'),
  ('7b000000-0000-0000-0000-000000000003','p16-admin@example.invalid');
insert into public.user_roles(user_id,role) values
  ('7b000000-0000-0000-0000-000000000002','teacher'),
  ('7b000000-0000-0000-0000-000000000003','admin');
insert into public.teacher_profiles(
  user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd,
  default_meeting_provider,default_meeting_url
) values(
  '7b000000-0000-0000-0000-000000000002','p16-teacher','P1-6 fixture',
  'active',true,array['online']::public.teaching_mode[],500,
  'manual_google_meet','https://meet.google.com/abc-defg-hij'
);
insert into public.student_teacher_relationships(
  id,student_user_id,teacher_user_id,relationship_status,preferred_mode
) values(
  '7b000000-0000-0000-0000-000000000010',
  '7b000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000002','active','online'
);
insert into public.teacher_scheduling_settings(
  teacher_user_id,timezone,minimum_booking_notice_minutes,booking_horizon_days,slot_interval_minutes
) values('7b000000-0000-0000-0000-000000000002','UTC',0,90,10);
insert into public.teacher_availability_exceptions(
  teacher_user_id,exception_kind,starts_at,ends_at,reason,created_by
) values(
  '7b000000-0000-0000-0000-000000000002','opening',
  (current_date+14)::timestamp+time '08:00',
  (current_date+14)::timestamp+time '23:30',
  'P1-6 fixture opening','7b000000-0000-0000-0000-000000000002'
);

insert into public.entitlements(
  id,beneficiary_user_id,teacher_scope_user_id,entitlement_type,status,starts_at,expires_at,
  product_name_snapshot,booking_mode_eligibility,lesson_duration_minutes
) values
  ('7b000000-0000-0000-0000-000000000020','7b000000-0000-0000-0000-000000000001',
   '7b000000-0000-0000-0000-000000000002','lesson_package','active',
   now()-interval '1 day',now()+interval '6 months','Package A','both',50),
  ('7b000000-0000-0000-0000-000000000021','7b000000-0000-0000-0000-000000000001',
   '7b000000-0000-0000-0000-000000000002','lesson_package','active',
   now()-interval '1 day',now()+interval '6 months','Package B','both',50),
  ('7b000000-0000-0000-0000-000000000022','7b000000-0000-0000-0000-000000000001',
   '7b000000-0000-0000-0000-000000000002','lesson_package','active',
   now()-interval '1 day',now()+interval '6 months','Unrelated Package C','both',50);
insert into public.lesson_credit_ledger(
  entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,reason_code
) values
  ('7b000000-0000-0000-0000-000000000020','7b000000-0000-0000-0000-000000000001',
   'allocation',3,'p16-package-a-allocation','fixture'),
  ('7b000000-0000-0000-0000-000000000021','7b000000-0000-0000-0000-000000000001',
   'allocation',2,'p16-package-b-allocation','fixture'),
  ('7b000000-0000-0000-0000-000000000022','7b000000-0000-0000-0000-000000000001',
   'allocation',1,'p16-package-c-allocation','fixture');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
insert into pg_temp.p16_ids values(
  'completed_booking',public.create_lesson_booking(
    '7b000000-0000-0000-0000-000000000001','7b000000-0000-0000-0000-000000000002',
    '7b000000-0000-0000-0000-000000000010','7b000000-0000-0000-0000-000000000020',
    (current_date+14)::timestamp+time '10:00','UTC',
    'p16-completed-booking-0001','P1-6 completed history fixture'));
insert into pg_temp.p16_ids values(
  'future_a_booking',public.create_lesson_booking(
    '7b000000-0000-0000-0000-000000000001','7b000000-0000-0000-0000-000000000002',
    '7b000000-0000-0000-0000-000000000010','7b000000-0000-0000-0000-000000000020',
    (current_date+14)::timestamp+time '12:00','UTC',
    'p16-future-a-booking-0001','P1-6 future A fixture'));
insert into pg_temp.p16_ids values(
  'future_b_booking',public.create_lesson_booking(
    '7b000000-0000-0000-0000-000000000001','7b000000-0000-0000-0000-000000000002',
    '7b000000-0000-0000-0000-000000000010','7b000000-0000-0000-0000-000000000021',
    (current_date+14)::timestamp+time '14:00','UTC',
    'p16-future-b-booking-0001','P1-6 future B fixture'));
reset role;

update public.lessons set starts_at=now()-interval '1 hour',ends_at=now()-interval '10 minutes'
where id=(select lesson_id from public.bookings where id=(select id from pg_temp.p16_ids where name='completed_booking'));
update public.bookings set starts_at=now()-interval '1 hour',ends_at=now()-interval '10 minutes'
where id=(select id from pg_temp.p16_ids where name='completed_booking');
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000002',true);
select public.complete_lesson_booking(
  (select id from pg_temp.p16_ids where name='completed_booking'),
  'Visible history','Private history','Completed before revoke','Preserve history','Done');
reset role;

insert into public.makeup_rights(
  id,student_user_id,origin_lesson_id,origin_teacher_user_id,current_teacher_user_id,
  source,source_operation_key,status,valid_until,reason,created_by
) values(
  '7b000000-0000-0000-0000-000000000030',
  '7b000000-0000-0000-0000-000000000001',
  (select lesson_id from public.bookings where id=(select id from pg_temp.p16_ids where name='completed_booking')),
  '7b000000-0000-0000-0000-000000000002','7b000000-0000-0000-0000-000000000002',
  'admin_compensation','p16-makeup-right-create-0001','available',
  now()+interval '30 days','Independent Makeup fixture','7b000000-0000-0000-0000-000000000003'
);
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7b000000-0000-0000-0000-000000000001',true);
insert into pg_temp.p16_ids values(
  'makeup_booking',public.create_makeup_lesson_booking(
    '7b000000-0000-0000-0000-000000000030',
    '7b000000-0000-0000-0000-000000000001','7b000000-0000-0000-0000-000000000002',
    '7b000000-0000-0000-0000-000000000010',
    (current_date+14)::timestamp+time '16:00','UTC',
    'p16-makeup-booking-0001','Independent Makeup booking'));
reset role;

insert into public.products(
  id,product_type,status,public_slug,name,currency,base_price_amount,owner_type,
  is_public,is_purchasable,published_at
) values(
  '7b000000-0000-0000-0000-000000000040','lesson_package','active',
  'p16-fixed-product','P1-6 Fixed Product','TWD',1000,'platform',false,false,now()
);
insert into public.lesson_package_product_configs(
  product_id,lesson_count,validity_value,validity_unit,
  lesson_duration_minutes,booking_mode_eligibility
) values(
  '7b000000-0000-0000-0000-000000000040',3,6,'months',50,'both'
);
insert into public.orders(
  id,order_number,buyer_user_id,status,currency,subtotal_amount,total_amount,
  payment_status,source,idempotency_key,paid_at
) values(
  '7b000000-0000-0000-0000-000000000041','ONE-20260904-P160000001',
  '7b000000-0000-0000-0000-000000000001','paid','TWD',1000,1000,
  'paid','admin','7b000000-0000-4000-8000-000000000041',now()
);
insert into public.order_items(
  id,order_id,product_id,product_type_snapshot,product_name_snapshot,
  unit_price_amount,quantity,line_subtotal_amount,line_total_amount,seller_type
) values(
  '7b000000-0000-0000-0000-000000000042','7b000000-0000-0000-0000-000000000041',
  '7b000000-0000-0000-0000-000000000040','lesson_package','P1-6 Fixed Product',
  1000,1,1000,1000,'platform'
);
insert into public.order_fulfillment_events(
  id,order_id,event_type,status,payload,processed_at
) values(
  '7b000000-0000-0000-0000-000000000043','7b000000-0000-0000-0000-000000000041',
  'order.paid','processed','{}',now()
);
insert into public.recurring_lesson_series(
  id,student_user_id,teacher_user_id,relationship_id,preferred_entitlement_id,
  weekday,local_start_time,timezone,duration_minutes,effective_from,effective_until,
  status,created_by,lifecycle_reason
) values(
  '7b000000-0000-0000-0000-000000000044',
  '7b000000-0000-0000-0000-000000000001','7b000000-0000-0000-0000-000000000002',
  '7b000000-0000-0000-0000-000000000010','7b000000-0000-0000-0000-000000000020',
  extract(dow from current_date+21)::smallint,'18:00','UTC',50,
  current_date,current_date+90,'active','7b000000-0000-0000-0000-000000000002',
  'P1-6 active Fixed cycle fixture'
);
insert into public.fixed_entitlement_cycles(
  id,series_id,entitlement_id,student_user_id,teacher_user_id,sequence_number,status,
  source_fulfillment_event_id,source_order_item_id,attached_by,attachment_actor_role,
  attachment_reason
) values(
  '7b000000-0000-0000-0000-000000000045','7b000000-0000-0000-0000-000000000044',
  '7b000000-0000-0000-0000-000000000020','7b000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000002',1,'active',
  '7b000000-0000-0000-0000-000000000043','7b000000-0000-0000-0000-000000000042',
  '7b000000-0000-0000-0000-000000000003','admin','P1-6 cycle fixture'
);

\else

begin;
select plan(1);
select pass('P1-6 fixture is side-effect free when discovered as a standalone DB test');
select * from finish();
rollback;

\endif
