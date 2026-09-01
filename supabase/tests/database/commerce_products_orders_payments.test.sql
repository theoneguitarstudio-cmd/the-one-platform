begin;
select no_plan();
create temporary table commerce_ids(name text primary key,id uuid not null) on commit drop;
grant select,insert on commerce_ids to anon,authenticated;

insert into auth.users(id,email) values
('40000000-0000-0000-0000-00000000000a','commerce-student-a@example.invalid'),
('40000000-0000-0000-0000-00000000000b','commerce-student-b@example.invalid'),
('40000000-0000-0000-0000-00000000000c','commerce-teacher@example.invalid'),
('40000000-0000-0000-0000-00000000000d','commerce-admin@example.invalid');
update public.profiles set display_name=case user_id when '40000000-0000-0000-0000-00000000000a' then 'Buyer A' when '40000000-0000-0000-0000-00000000000b' then 'Buyer B' when '40000000-0000-0000-0000-00000000000c' then 'Seller Teacher' else 'Commerce Admin' end;
insert into public.user_roles(user_id,role) values
('40000000-0000-0000-0000-00000000000c','teacher'),('40000000-0000-0000-0000-00000000000d','admin');
insert into public.teacher_profiles(user_id,public_slug,bio,teaching_status,is_public,teaching_modes,trial_price_twd)
values('40000000-0000-0000-0000-00000000000c','commerce-teacher','Teacher','active',true,array['online']::public.teaching_mode[],500);
insert into public.products(product_type,status,public_slug,name,currency,base_price_amount,owner_type,is_public,is_purchasable,published_at)
values('lesson_package','active','platform-pack','Platform Package','TWD',3200,'platform',true,true,now()),
('recorded_course','draft','private-draft','Internal Draft','TWD',900,'platform',false,false,null);
insert into public.products(product_type,status,public_slug,name,currency,base_price_amount,owner_type,owner_teacher_user_id,is_public,is_purchasable,published_at)
values('lesson_package','active','teacher-pack','Teacher Package','TWD',2400,'teacher','40000000-0000-0000-0000-00000000000c',true,true,now());
insert into public.lesson_package_product_configs(product_id,lesson_count,validity_value,validity_unit,booking_mode_eligibility)
select id,4,5,'weeks','both' from public.products where public_slug in('platform-pack','teacher-pack');

set local role anon; select set_config('request.jwt.claim.sub','',true);
select is((select count(*) from public.product_public_catalog),2::bigint,'anonymous sees only active public products');
select throws_ok($$select metadata from public.products$$,'42501',null,'anonymous cannot read private product fields');
select is((select count(*) from public.product_public_catalog where public_slug='private-draft'),0::bigint,'draft product is not public');

reset role; set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select lives_ok($$insert into pg_temp.commerce_ids select 'a-order-1',public.create_checkout_order('platform-pack',2,'11111111-1111-4111-8111-111111111111')$$,'buyer creates checkout');
reset role;
select is((select subtotal_amount from public.orders where id=(select id from commerce_ids where name='a-order-1')),6400::bigint,'database uses authoritative product price');
select is((select unit_price_amount from public.order_items where order_id=(select id from commerce_ids where name='a-order-1')),3200::bigint,'order item snapshots unit price');
update public.products set base_price_amount=9999 where public_slug='platform-pack';
select is((select unit_price_amount from public.order_items where order_id=(select id from commerce_ids where name='a-order-1')),3200::bigint,'snapshot does not follow product price changes');

set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select is(public.create_checkout_order('platform-pack',2,'11111111-1111-4111-8111-111111111111'),(select id from commerce_ids where name='a-order-1'),'same checkout key returns same order');
reset role; select is((select count(*) from public.orders where buyer_user_id='40000000-0000-0000-0000-00000000000a'),1::bigint,'retry does not duplicate order');
set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000b',true);
select lives_ok($$insert into pg_temp.commerce_ids select 'b-order-1',public.create_checkout_order('platform-pack',1,'11111111-1111-4111-8111-111111111111')$$,'different buyer may reuse key');
select is((select count(*) from public.orders),1::bigint,'buyer B sees only own order');
select throws_ok($$update public.orders set status='paid'$$,'42501',null,'client cannot mark order paid');
select throws_ok($$insert into public.payments(order_id,provider,method,status,amount,currency,idempotency_key,paid_at) values((select id from pg_temp.commerce_ids limit 1),'manual_cash','cash','paid',1,'TWD','client-forged-payment',now())$$,'42501',null,'client cannot create paid payment');

reset role; update public.products set status='draft',is_public=false,is_purchasable=false where public_slug='platform-pack';
set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select throws_ok($$select public.create_checkout_order('platform-pack',1,'22222222-2222-4222-8222-222222222222')$$,'P0001',null,'inactive product cannot be purchased');
reset role; update public.profiles set account_status='suspended' where user_id='40000000-0000-0000-0000-00000000000c';
set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select throws_ok($$select public.create_checkout_order('teacher-pack',1,'33333333-3333-4333-8333-333333333333')$$,'P0001',null,'suspended teacher product cannot be purchased');
reset role; set local role anon; select is((select count(*) from public.product_public_catalog where public_slug='teacher-pack'),0::bigint,'suspended teacher product disappears from catalog');

reset role; set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000b',true);
select lives_ok($$select public.cancel_own_order((select id from pg_temp.commerce_ids where name='b-order-1'),'Changed mind')$$,'pending order can be cancelled');
reset role; select is((select status from public.orders where id=(select id from commerce_ids where name='b-order-1')),'cancelled'::public.commerce_order_status,'cancelled state persists');

update public.products set status='active',is_public=true,is_purchasable=true,published_at=now() where public_slug='platform-pack';
set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select lives_ok($$insert into pg_temp.commerce_ids select 'a-order-2',public.create_checkout_order('platform-pack',1,'44444444-4444-4444-8444-444444444444')$$,'buyer creates second order');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000b',true);
select throws_ok($$select public.submit_bank_transfer((select id from pg_temp.commerce_ids where name='a-order-2'),'Wrong Buyer','12345',null,'55555555-5555-4555-8555-555555555555')$$,'42501',null,'bank submission is buyer-owned');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select lives_ok($$insert into pg_temp.commerce_ids select 'a-payment',public.submit_bank_transfer((select id from pg_temp.commerce_ids where name='a-order-2'),'Buyer A','12345','Transfer sent','66666666-6666-4666-8666-666666666666')$$,'buyer submits bank transfer');
select is((select count(*) from public.get_own_payment_summaries((select id from pg_temp.commerce_ids where name='a-order-2'))),1::bigint,'buyer receives payment-safe DTO');
select throws_ok($$select * from public.payments$$,'42501',null,'buyer cannot select payments directly');

reset role; set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000c',true);
select throws_ok($$select * from public.payments$$,'42501',null,'teacher cannot read buyer payment details');
select throws_ok($$select public.admin_confirm_payment((select id from pg_temp.commerce_ids where name='a-order-2'),(select id from pg_temp.commerce_ids where name='a-payment'),null,'Not admin')$$,'42501',null,'non-admin cannot confirm payment');
reset role; set local role anon;
select throws_ok($$select public.submit_bank_transfer(gen_random_uuid(),'Anon','12345',null,'77777777-7777-4777-8777-777777777777')$$,'42501',null,'anonymous cannot execute payment submission');

reset role; set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000d',true);
select lives_ok($$select public.admin_confirm_payment((select id from pg_temp.commerce_ids where name='a-order-2'),(select id from pg_temp.commerce_ids where name='a-payment'),'manual-event-1','Bank evidence reviewed')$$,'admin reviews and confirms manual payment');
reset role; select is((select status from public.orders where id=(select id from commerce_ids where name='a-order-2')),'paid'::public.commerce_order_status,'payment atomically marks order paid');
select is((select status from public.payments where id=(select id from commerce_ids where name='a-payment')),'paid'::public.commerce_payment_status,'payment row is paid');
select is((select count(*) from public.order_fulfillment_events where order_id=(select id from commerce_ids where name='a-order-2')),1::bigint,'paid transition emits one fulfillment event');
set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000d',true);
select lives_ok($$select public.admin_confirm_payment((select id from pg_temp.commerce_ids where name='a-order-2'),(select id from pg_temp.commerce_ids where name='a-payment'),'manual-event-1','Retry')$$,'double confirmation is idempotent');
reset role; select is((select count(*) from public.order_fulfillment_events where order_id=(select id from commerce_ids where name='a-order-2')),1::bigint,'fulfillment event is not duplicated');
select is((select count(*) from public.audit_logs where target_id=(select id from commerce_ids where name='a-payment')),1::bigint,'payment confirmation creates one audit event');

set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select throws_ok($$select public.cancel_own_order((select id from pg_temp.commerce_ids where name='a-order-2'),'No')$$,'P0001',null,'paid order cannot use ordinary cancellation');
select throws_ok($$select * from public.audit_logs$$,'42501',null,'ordinary user cannot read audit logs');
reset role;

set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select lives_ok($$insert into pg_temp.commerce_ids select 'expiry-order',public.create_checkout_order('platform-pack',1,'88888888-8888-4888-8888-888888888888')$$,'expiry fixture order is created');
reset role; update public.orders set expires_at=now()-interval '1 second' where id=(select id from commerce_ids where name='expiry-order');
set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000d',true);
select lives_ok($$select public.admin_expire_order((select id from pg_temp.commerce_ids where name='expiry-order'),'Reached deadline')$$,'admin expiry succeeds after deadline');
reset role; select is((select status from public.orders where id=(select id from commerce_ids where name='expiry-order')),'expired'::public.commerce_order_status,'expired status persists');

set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select lives_ok($$insert into pg_temp.commerce_ids select 'mismatch-order',public.create_checkout_order('platform-pack',1,'99999999-9999-4999-8999-999999999999')$$,'mismatch fixture order is created');
reset role;
with inserted as (insert into public.payments(order_id,provider,method,status,amount,currency,idempotency_key)
  values((select id from commerce_ids where name='mismatch-order'),'other','other','pending',1,'TWD','mismatch-amount-key') returning id)
insert into commerce_ids select 'mismatch-amount-payment',id from inserted;
with inserted as (insert into public.payments(order_id,provider,method,status,amount,currency,idempotency_key)
  values((select id from commerce_ids where name='mismatch-order'),'stripe','credit_card','pending',9999,'USD','mismatch-currency-key') returning id)
insert into commerce_ids select 'mismatch-currency-payment',id from inserted;
set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000d',true);
select throws_ok($$select public.admin_confirm_payment((select id from pg_temp.commerce_ids where name='mismatch-order'),(select id from pg_temp.commerce_ids where name='mismatch-amount-payment'),'bad-amount-event','Mismatch test')$$,'P0001',null,'payment amount mismatch is rejected');
select throws_ok($$select public.admin_confirm_payment((select id from pg_temp.commerce_ids where name='mismatch-order'),(select id from pg_temp.commerce_ids where name='mismatch-currency-payment'),'bad-currency-event','Mismatch test')$$,'P0001',null,'payment currency mismatch is rejected');

reset role; set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select lives_ok($$insert into pg_temp.commerce_ids select 'reject-order',public.create_checkout_order('platform-pack',1,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$$,'rejection fixture order is created');
select lives_ok($$insert into pg_temp.commerce_ids select 'reject-payment',public.submit_bank_transfer((select id from pg_temp.commerce_ids where name='reject-order'),'Buyer A','54321',null,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')$$,'rejection fixture submission is created');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000d',true);
select lives_ok($$select public.admin_reject_payment_submission((select id from pg_temp.commerce_ids where name='reject-payment'),'Evidence mismatch')$$,'admin can reject bank submission');
reset role; select is((select status from public.payment_submissions where payment_id=(select id from commerce_ids where name='reject-payment')),'rejected'::public.payment_submission_status,'rejected submission persists');

set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000a',true);
select lives_ok($$insert into pg_temp.commerce_ids select 'cash-order',public.create_checkout_order('platform-pack',1,'cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'cash fixture order is created');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-00000000000d',true);
select lives_ok($$select public.admin_confirm_cash_payment((select id from pg_temp.commerce_ids where name='cash-order'),'dddddddd-dddd-4ddd-8ddd-dddddddddddd','Cash received')$$,'admin can atomically confirm cash');
reset role; select is((select status from public.orders where id=(select id from commerce_ids where name='cash-order')),'paid'::public.commerce_order_status,'cash confirmation marks order paid');

select throws_ok($$insert into public.products(product_type,status,public_slug,name,currency,base_price_amount,owner_type) values('event','draft','negative','Negative','TWD',-1,'platform')$$,'23514',null,'negative product amount violates constraint');
select throws_ok($$insert into public.order_items(order_id,product_id,product_type_snapshot,product_name_snapshot,unit_price_amount,quantity,line_subtotal_amount,line_total_amount,seller_type) select id,(select id from public.products limit 1),'event','Bad',1,0,0,0,'platform' from public.orders limit 1$$,'23514',null,'zero quantity violates monetary constraint');
select throws_ok($$insert into public.order_fulfillment_events(order_id,event_type,payload) values((select id from commerce_ids where name='a-order-2'),'order.paid','{}')$$,'23505',null,'duplicate fulfillment event is rejected');

select * from finish();
rollback;
