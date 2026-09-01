begin;
select no_plan();

insert into auth.users(id,email) values
  ('42000000-0000-0000-0000-000000000001','hardening-buyer@example.invalid'),
  ('42000000-0000-0000-0000-000000000002','hardening-teacher@example.invalid'),
  ('42000000-0000-0000-0000-000000000003','hardening-admin@example.invalid');
update public.profiles set display_name='Hardening Teacher'
where user_id='42000000-0000-0000-0000-000000000002';
insert into public.user_roles(user_id,role) values
  ('42000000-0000-0000-0000-000000000002','teacher'),
  ('42000000-0000-0000-0000-000000000003','admin');
insert into public.teacher_profiles(
  user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd
) values (
  '42000000-0000-0000-0000-000000000002','hardening-teacher','Teacher',
  'active',true,array['online']::public.teaching_mode[],500
);

insert into public.products(
  id,product_type,status,public_slug,name,currency,base_price_amount,
  owner_type,is_public,is_purchasable,published_at
) values
  ('42000000-0000-0000-0000-000000000010','lesson_package','active',
   'hardening-platform','Platform Product','TWD',3200,'platform',true,true,now()),
  ('42000000-0000-0000-0000-000000000011','recorded_course','active',
   'hardening-coming-soon','Coming Soon','TWD',800,'platform',true,false,now());
insert into public.products(
  id,product_type,status,public_slug,name,currency,base_price_amount,
  owner_type,owner_teacher_user_id,is_public,is_purchasable,published_at
) values (
  '42000000-0000-0000-0000-000000000012','lesson_package','active',
  'hardening-teacher-product','Teacher Product','TWD',2400,'teacher',
  '42000000-0000-0000-0000-000000000002',true,true,now()
);
insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,booking_mode_eligibility)
select id,4,5,'weeks','both' from public.products
where public_slug in('hardening-platform','hardening-teacher-product');

set local role anon;
select is(
  (select count(*) from public.product_public_catalog where public_slug='hardening-coming-soon'),
  1::bigint,
  'non-purchasable Coming Soon product remains publicly visible'
);
select throws_ok(
  $$select product_id from public.product_public_catalog limit 1$$,
  '42501',null,'anonymous cannot select technical product UUID'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000001',true);
select throws_ok(
  $$select public.create_checkout_order('hardening-coming-soon',1,'42000000-0000-4000-8000-000000000101')$$,
  'P0001','Product is unavailable','Coming Soon product cannot be checked out'
);

reset role;
update public.teacher_profiles set teaching_status='paused'
where user_id='42000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000001',true);
select throws_ok(
  $$select public.create_checkout_order('hardening-teacher-product',1,'42000000-0000-4000-8000-000000000102')$$,
  'P0001','Product is unavailable','paused Teacher product checkout is rejected'
);
reset role;
set local role anon;
select is((select count(*) from public.product_public_catalog where public_slug='hardening-teacher-product'),0::bigint,
  'paused Teacher product is absent from public catalog');

reset role;
update public.teacher_profiles set teaching_status='active',is_public=false
where user_id='42000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000001',true);
select throws_ok(
  $$select public.create_checkout_order('hardening-teacher-product',1,'42000000-0000-4000-8000-000000000103')$$,
  'P0001','Product is unavailable','private Teacher product checkout is rejected'
);

reset role;
update public.teacher_profiles set is_public=true
where user_id='42000000-0000-0000-0000-000000000002';
update public.profiles set account_status='suspended'
where user_id='42000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000001',true);
select throws_ok(
  $$select public.create_checkout_order('hardening-teacher-product',1,'42000000-0000-4000-8000-000000000104')$$,
  'P0001','Product is unavailable','suspended Teacher product checkout is rejected'
);

reset role;
update public.profiles set account_status='active'
where user_id='42000000-0000-0000-0000-000000000002';
delete from public.user_roles
where user_id='42000000-0000-0000-0000-000000000002' and role='teacher';
set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000001',true);
select throws_ok(
  $$select public.create_checkout_order('hardening-teacher-product',1,'42000000-0000-4000-8000-000000000105')$$,
  'P0001','Product is unavailable','Teacher product checkout is rejected after role removal'
);

reset role;
insert into public.user_roles(user_id,role)
values('42000000-0000-0000-0000-000000000002','teacher');
set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000001',true);
select lives_ok(
  $$select public.create_checkout_order('hardening-teacher-product',1,'42000000-0000-4000-8000-000000000106')$$,
  'eligible Teacher product checkout succeeds after restoration'
);

reset role;
insert into public.orders(
  id,order_number,buyer_user_id,status,currency,subtotal_amount,total_amount,
  payment_status,source,idempotency_key,expires_at
) values
  ('42000000-0000-0000-0000-000000000020','ONE-20260901-HARDEN0001',
   '42000000-0000-0000-0000-000000000001','awaiting_payment','TWD',3200,3200,
   'pending','web','42000000-0000-4000-8000-000000000201',now()+interval '1 day'),
  ('42000000-0000-0000-0000-000000000021','ONE-20260901-HARDEN0002',
   '42000000-0000-0000-0000-000000000001','awaiting_payment','TWD',3200,3200,
   'pending','web','42000000-0000-4000-8000-000000000202',now()+interval '1 day'),
  ('42000000-0000-0000-0000-000000000022','ONE-20260901-HARDEN0003',
   '42000000-0000-0000-0000-000000000001','awaiting_payment','TWD',3200,3200,
   'unpaid','web','42000000-0000-4000-8000-000000000203',now()+interval '1 day');
insert into public.payments(
  id,order_id,provider,method,status,amount,currency,idempotency_key
) values
  ('42000000-0000-0000-0000-000000000030','42000000-0000-0000-0000-000000000020',
   'manual_bank_transfer','bank_transfer','pending',3200,'TWD','42000000-0000-4000-8000-000000000301'),
  ('42000000-0000-0000-0000-000000000031','42000000-0000-0000-0000-000000000020',
   'manual_bank_transfer','bank_transfer','pending',3200,'TWD','42000000-0000-4000-8000-000000000302'),
  ('42000000-0000-0000-0000-000000000032','42000000-0000-0000-0000-000000000021',
   'manual_bank_transfer','bank_transfer','pending',3200,'TWD','42000000-0000-4000-8000-000000000303');

set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000003',true);
select lives_ok(
  $$select public.admin_confirm_payment(
    '42000000-0000-0000-0000-000000000020','42000000-0000-0000-0000-000000000030',
    'hardening-event-a','first payment')$$,
  'first payment attempt is confirmed'
);
select lives_ok(
  $$select public.admin_confirm_payment(
    '42000000-0000-0000-0000-000000000020','42000000-0000-0000-0000-000000000030',
    'hardening-event-a','idempotent retry')$$,
  'same provider event retry is idempotent'
);
select throws_ok(
  $$select public.admin_confirm_payment(
    '42000000-0000-0000-0000-000000000020','42000000-0000-0000-0000-000000000030',
    'hardening-event-different','different event')$$,
  'P0001','PAYMENT_EVENT_MISMATCH','different event is not treated as the same callback'
);
select throws_ok(
  $$select public.admin_confirm_payment(
    '42000000-0000-0000-0000-000000000020','42000000-0000-0000-0000-000000000031',
    'hardening-event-b','second payment')$$,
  'P0001','ORDER_ALREADY_PAID','second payment attempt receives stable domain rejection'
);

reset role;
select is((select count(*) from public.payments
  where order_id='42000000-0000-0000-0000-000000000020' and status='paid'),1::bigint,
  'exactly one payment is paid');
select is((select count(*) from public.order_fulfillment_events
  where order_id='42000000-0000-0000-0000-000000000020'),1::bigint,
  'exactly one fulfillment event exists');
select is((select count(*) from public.audit_logs
  where action='payment.confirmed' and target_id in(
    '42000000-0000-0000-0000-000000000030','42000000-0000-0000-0000-000000000031')),1::bigint,
  'second payment does not create duplicate financial audit');
select throws_ok(
  $$update public.payments set status='paid',paid_at=now()
    where id='42000000-0000-0000-0000-000000000031'$$,
  '23505',null,'partial unique index blocks a second paid payment'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000003',true);
select throws_ok(
  $$select public.admin_confirm_payment(
    '42000000-0000-0000-0000-000000000021','42000000-0000-0000-0000-000000000032',
    'hardening-event-a','reused event')$$,
  'P0001','PROVIDER_EVENT_ALREADY_USED','provider event cannot be reused by another payment'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000001',true);
select lives_ok(
  $$select public.cancel_own_order('42000000-0000-0000-0000-000000000022','Changed mind')$$,
  'Buyer can cancel own open order'
);
reset role;
select is((select count(*) from public.audit_logs
  where action='buyer_cancel_order' and target_id='42000000-0000-0000-0000-000000000022'),1::bigint,
  'Buyer cancellation creates one durable audit row');

insert into public.products(
  id,product_type,status,public_slug,name,currency,base_price_amount,
  owner_type,owner_teacher_user_id,is_public,is_purchasable
) values (
  '42000000-0000-0000-0000-000000000013','lesson_package','draft',
  'hardening-archive-product','Archive Product','TWD',1200,'teacher',
  '42000000-0000-0000-0000-000000000002',false,false
);
set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000002',true);
select lives_ok(
  $$select public.archive_own_product('42000000-0000-0000-0000-000000000013')$$,
  'Teacher can archive own product'
);
reset role;
select is((select count(*) from public.audit_logs
  where action='teacher_archive_product' and target_id='42000000-0000-0000-0000-000000000013'),1::bigint,
  'Teacher archive creates one durable audit row');

set local role authenticated;
select set_config('request.jwt.claim.sub','42000000-0000-0000-0000-000000000001',true);
select throws_ok(
  $$select private.teacher_owner_is_active('42000000-0000-0000-0000-000000000002')$$,
  '42501',null,'authenticated cannot directly execute private Teacher eligibility helper'
);

reset role;
select is(
  (select proconfig from pg_proc
   where oid='private.teacher_owner_is_active(uuid)'::regprocedure),
  array['search_path=""']::text[],
  'Teacher helper keeps an empty search_path'
);
select is(
  has_function_privilege('authenticated','private.teacher_owner_is_active(uuid)','EXECUTE'),
  false,
  'Teacher helper has no authenticated EXECUTE grant'
);

select * from finish();
rollback;
