begin;
select no_plan();

-- Every high-risk commerce / fulfillment table denies generic service_role
-- mutation at both table and column privilege levels.  SELECT is deliberately
-- outside this contract.
select ok(
  not has_table_privilege('service_role',format('public.%I',table_name),'INSERT')
  and not has_any_column_privilege('service_role',format('public.%I',table_name),'INSERT'),
  format('service_role cannot raw INSERT %I',table_name)
)
from unnest(array[
  'products','product_public_catalog','product_publication_requests','orders',
  'order_items','payments','payment_submissions','order_fulfillment_events',
  'refunds','lesson_package_product_configs','order_item_fulfillment_snapshots',
  'fulfillment_manual_retry_attempts'
]) table_name;

select ok(
  not has_table_privilege('service_role',format('public.%I',table_name),'UPDATE')
  and not has_any_column_privilege('service_role',format('public.%I',table_name),'UPDATE'),
  format('service_role cannot raw UPDATE %I',table_name)
)
from unnest(array[
  'products','product_public_catalog','product_publication_requests','orders',
  'order_items','payments','payment_submissions','order_fulfillment_events',
  'refunds','lesson_package_product_configs','order_item_fulfillment_snapshots',
  'fulfillment_manual_retry_attempts'
]) table_name;

select ok(
  not has_table_privilege('service_role',format('public.%I',table_name),'DELETE'),
  format('service_role cannot raw DELETE %I',table_name)
)
from unnest(array[
  'products','product_public_catalog','product_publication_requests','orders',
  'order_items','payments','payment_submissions','order_fulfillment_events',
  'refunds','lesson_package_product_configs','order_item_fulfillment_snapshots',
  'fulfillment_manual_retry_attempts'
]) table_name;

select ok(
  not has_table_privilege('service_role',format('public.%I',table_name),'TRUNCATE'),
  format('service_role cannot raw TRUNCATE %I',table_name)
)
from unnest(array[
  'products','product_public_catalog','product_publication_requests','orders',
  'order_items','payments','payment_submissions','order_fulfillment_events',
  'refunds','lesson_package_product_configs','order_item_fulfillment_snapshots',
  'fulfillment_manual_retry_attempts'
]) table_name;

select is(
  has_function_privilege(
    'service_role','private.confirm_payment_locked(uuid,uuid,text,uuid,text)','EXECUTE'
  ),false,
  'service_role cannot execute the private payment mutation core directly'
);
select is(
  has_function_privilege(
    'service_role','private.sync_product_public_catalog_row(uuid)','EXECUTE'
  ),false,
  'service_role cannot execute the private catalog mutation core directly'
);
select is(
  has_function_privilege('service_role','public.process_order_fulfillment_event(uuid)','EXECUTE'),
  true,'service_role retains the formal fulfillment RPC'
);

create temporary table authority_ids(name text primary key,id uuid not null) on commit drop;
grant select,insert on authority_ids to authenticated;
grant select on authority_ids to service_role;

insert into auth.users(id,email) values
  ('7c000000-0000-0000-0000-000000000001','commerce-authority-buyer@example.invalid'),
  ('7c000000-0000-0000-0000-000000000002','commerce-authority-admin@example.invalid');
insert into public.user_roles(user_id,role)
values('7c000000-0000-0000-0000-000000000002','admin');
insert into public.products(
  id,product_type,status,public_slug,name,currency,base_price_amount,owner_type,
  is_public,is_purchasable,published_at
) values(
  '7c000000-0000-0000-0000-000000000010','lesson_package','active',
  'commerce-authority-pack','Authority Pack','TWD',1200,'platform',true,true,now()
);
insert into public.lesson_package_product_configs(
  product_id,lesson_count,validity_value,validity_unit,lesson_duration_minutes,
  booking_mode_eligibility
) values('7c000000-0000-0000-0000-000000000010',2,30,'days',50,'both');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000001',true);
select lives_ok($$
  insert into pg_temp.authority_ids
  select 'order',public.create_checkout_order(
    'commerce-authority-pack',1,'commerce-authority-checkout-0001'
  )
$$,'formal checkout RPC still works');
select lives_ok($$
  insert into pg_temp.authority_ids
  select 'payment',public.submit_bank_transfer(
    (select id from pg_temp.authority_ids where name='order'),
    'Authority Buyer','81234','Security regression fixture',
    'commerce-authority-payment-0001'
  )
$$,'formal payment-submission RPC still works');

select set_config('request.jwt.claim.sub','7c000000-0000-0000-0000-000000000002',true);
select lives_ok($$
  select public.admin_confirm_payment(
    (select id from pg_temp.authority_ids where name='order'),
    (select id from pg_temp.authority_ids where name='payment'),
    'commerce-authority-provider-0001','Security regression confirmation'
  )
$$,'formal manual payment confirmation still works');
reset role;

insert into authority_ids
select 'event',id from public.order_fulfillment_events
where order_id=(select id from authority_ids where name='order');

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok($$
  select public.process_order_fulfillment_event(
    (select id from pg_temp.authority_ids where name='event')
  )
$$,'formal fulfillment RPC still works without raw table mutation grants');
reset role;

select is(
  (select status::text from public.orders where id=(select id from authority_ids where name='order')),
  'paid','formal fulfillment preserves the authoritative paid order state'
);
select is(
  (select count(*) from public.entitlements
   where source_fulfillment_event_id=(select id from authority_ids where name='event')),
  1::bigint,'formal fulfillment creates exactly one entitlement'
);

select * from finish();
rollback;
