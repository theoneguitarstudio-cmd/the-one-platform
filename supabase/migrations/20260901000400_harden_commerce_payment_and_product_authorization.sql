begin;

create unique index payments_one_paid_per_order_idx
  on public.payments (order_id)
  where status = 'paid';

comment on index public.payments_one_paid_per_order_idx is
  'An order may have many payment attempts but at most one paid payment.';

create or replace function private.teacher_owner_is_active(teacher_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles as profile
    join public.teacher_profiles as teacher on teacher.user_id = profile.user_id
    where profile.user_id = teacher_user_id
      and profile.account_status = 'active'
      and teacher.teaching_status = 'active'
      and teacher.is_public = true
      and exists (
        select 1 from public.user_roles as assignment
        where assignment.user_id = profile.user_id
          and assignment.role = 'teacher'
      )
  );
$$;

comment on function private.teacher_owner_is_active(uuid) is
  'Internal live eligibility check for Teacher-owned public products and checkout. Not client executable.';

create or replace function public.create_checkout_order(
  p_product_slug text, p_quantity integer, p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  product_row public.products%rowtype;
  existing_order public.orders%rowtype;
  created_order_id uuid;
  calculated_subtotal bigint;
begin
  if caller is null or not private.current_user_is_active() then
    raise exception using errcode = '42501', message = 'Not authorized';
  end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 100
    or char_length(coalesce(p_idempotency_key, '')) not between 16 and 160 then
    raise exception using errcode = '22023', message = 'Invalid checkout request';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(caller::text || ':' || p_idempotency_key, 0));
  select * into existing_order from public.orders
  where buyer_user_id = caller and idempotency_key = p_idempotency_key;
  if found then
    if not exists (
      select 1 from public.order_items as item
      join public.products as product on product.id = item.product_id
      where item.order_id = existing_order.id
        and product.public_slug = p_product_slug and item.quantity = p_quantity
    ) then
      raise exception using errcode = '22023', message = 'Idempotency key payload mismatch';
    end if;
    return existing_order.id;
  end if;
  select * into product_row from public.products
  where public_slug = p_product_slug for share;
  if not found or product_row.status <> 'active' or not product_row.is_public
    or not product_row.is_purchasable then
    raise exception using errcode = 'P0001', message = 'Product is unavailable';
  end if;
  if product_row.currency <> 'TWD' or product_row.base_price_amount <= 0 then
    raise exception using errcode = 'P0001', message = 'Product pricing is unavailable';
  end if;
  if product_row.owner_type = 'teacher'
    and not private.teacher_owner_is_active(product_row.owner_teacher_user_id) then
    raise exception using errcode = 'P0001', message = 'Product is unavailable';
  end if;
  calculated_subtotal := product_row.base_price_amount * p_quantity;
  insert into public.orders (
    order_number,buyer_user_id,status,currency,subtotal_amount,discount_amount,
    tax_amount,total_amount,payment_status,source,idempotency_key,expires_at
  ) values (
    'ONE-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),
    caller,'awaiting_payment',product_row.currency,calculated_subtotal,0,0,
    calculated_subtotal,'unpaid','web',p_idempotency_key,now()+interval '24 hours'
  ) returning id into created_order_id;
  insert into public.order_items (
    order_id,product_id,product_type_snapshot,product_name_snapshot,unit_price_amount,
    quantity,line_subtotal_amount,line_discount_amount,line_tax_amount,line_total_amount,
    seller_type,seller_teacher_user_id
  ) values (
    created_order_id,product_row.id,product_row.product_type,product_row.name,
    product_row.base_price_amount,p_quantity,calculated_subtotal,0,0,calculated_subtotal,
    product_row.owner_type,product_row.owner_teacher_user_id
  );
  return created_order_id;
exception when unique_violation then
  select id into created_order_id from public.orders
  where buyer_user_id = caller and idempotency_key = p_idempotency_key;
  if created_order_id is not null then return created_order_id; end if;
  raise;
end;
$$;

create or replace function private.confirm_payment_locked(
  requested_order_id uuid, requested_payment_id uuid, requested_event_id text,
  actor uuid, reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  order_row public.orders%rowtype;
  payment_row public.payments%rowtype;
  paid_payment_id uuid;
begin
  select * into order_row from public.orders
  where id = requested_order_id for update;
  select * into payment_row from public.payments
  where id = requested_payment_id for update;
  if order_row.id is null or payment_row.id is null
    or payment_row.order_id <> order_row.id then
    raise exception using errcode = 'P0001', message = 'INVALID_PAYMENT';
  end if;
  select id into paid_payment_id from public.payments
  where order_id = order_row.id and status = 'paid';
  if payment_row.status = 'paid' and order_row.status = 'paid' then
    if paid_payment_id is distinct from payment_row.id then
      raise exception using errcode = 'P0001', message = 'ORDER_PAYMENT_INCONSISTENT';
    end if;
    if payment_row.provider_event_id is distinct from requested_event_id then
      raise exception using errcode = 'P0001', message = 'PAYMENT_EVENT_MISMATCH';
    end if;
    return order_row.id;
  end if;
  if order_row.status = 'paid' or paid_payment_id is not null then
    raise exception using errcode = 'P0001', message = 'ORDER_ALREADY_PAID';
  end if;
  if order_row.status in ('cancelled','expired','refunded','partially_refunded') then
    raise exception using errcode = 'P0001', message = 'ORDER_TERMINAL';
  end if;
  if payment_row.status not in ('pending','unpaid')
    or payment_row.amount <> order_row.total_amount
    or payment_row.currency <> order_row.currency then
    raise exception using errcode = 'P0001', message = 'PAYMENT_DOES_NOT_MATCH_ORDER';
  end if;
  if requested_event_id is not null then
    perform pg_advisory_xact_lock(hashtextextended('payment-event:' || requested_event_id, 4));
    if exists (
      select 1 from public.payments
      where provider = payment_row.provider
        and provider_event_id = requested_event_id and id <> payment_row.id
    ) then
      raise exception using errcode = 'P0001', message = 'PROVIDER_EVENT_ALREADY_USED';
    end if;
  end if;
  if payment_row.provider_event_id is not null
    and payment_row.provider_event_id is distinct from requested_event_id then
    raise exception using errcode = 'P0001', message = 'PAYMENT_EVENT_MISMATCH';
  end if;
  update public.payments set status='paid',paid_at=coalesce(paid_at,now()),
    provider_event_id=coalesce(provider_event_id,requested_event_id)
  where id=payment_row.id;
  update public.orders set status='paid',payment_status='paid',paid_at=coalesce(paid_at,now())
  where id=order_row.id;
  update public.payment_submissions set status='approved',reviewed_at=now(),
    reviewed_by=actor,review_reason=reason where payment_id=payment_row.id;
  insert into public.order_fulfillment_events(order_id,event_type,payload)
  values(order_row.id,'order.paid',jsonb_build_object(
    'order_id',order_row.id,'buyer_user_id',order_row.buyer_user_id,
    'currency',order_row.currency,'total_amount',order_row.total_amount))
  on conflict(order_id,event_type) do nothing;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(actor,'payment.confirmed','payment',payment_row.id,
    jsonb_build_object('payment_status',payment_row.status,'order_status',order_row.status),
    jsonb_build_object('payment_status','paid','order_status','paid'),reason);
  return order_row.id;
end;
$$;

create or replace function public.cancel_own_order(p_order_id uuid,p_reason text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid:=auth.uid();
  order_row public.orders%rowtype;
  normalized_reason text:=nullif(trim(coalesce(p_reason,'')),'');
begin
  if caller is null or not private.current_user_is_active() then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  if char_length(coalesce(normalized_reason,''))>1000 then
    raise exception using errcode='22023',message='Reason is too long';
  end if;
  select * into order_row from public.orders where id=p_order_id for update;
  if order_row.id is null or order_row.buyer_user_id<>caller then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  if order_row.status='cancelled' then return order_row.id; end if;
  if order_row.status not in ('pending','awaiting_payment')
    or order_row.payment_status='paid' then
    raise exception using errcode='P0001',message='Order cannot be cancelled';
  end if;
  update public.payments set status='cancelled'
  where order_id=order_row.id and status in ('unpaid','pending');
  update public.orders set status='cancelled',payment_status='unpaid',cancelled_at=now()
  where id=order_row.id;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'buyer_cancel_order','order',order_row.id,
    jsonb_build_object('status',order_row.status,'payment_status',order_row.payment_status),
    jsonb_build_object('status','cancelled','payment_status','unpaid'),normalized_reason);
  return order_row.id;
end;
$$;

create or replace function public.archive_own_product(p_product_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare caller uuid:=auth.uid(); product_row public.products%rowtype;
begin
  if caller is null or not private.current_user_has_role(array['teacher'::public.app_role]) then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  select * into product_row from public.products where id=p_product_id for update;
  if product_row.id is null or product_row.owner_type<>'teacher'
    or product_row.owner_teacher_user_id<>caller
    or product_row.status not in ('draft','active') then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  update public.products set status='archived',is_public=false,is_purchasable=false,
    archived_at=now() where id=product_row.id;
  update public.product_publication_requests set status='cancelled'
  where product_id=product_row.id and status='pending';
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'teacher_archive_product','product',product_row.id,
    jsonb_build_object('status',product_row.status,'is_public',product_row.is_public,
      'is_purchasable',product_row.is_purchasable),
    jsonb_build_object('status','archived','is_public',false,'is_purchasable',false),null);
  return product_row.id;
end;
$$;

revoke select(product_id) on public.product_public_catalog from anon,authenticated;
revoke all on function private.teacher_owner_is_active(uuid) from public,anon,authenticated;
grant execute on function private.teacher_owner_is_active(uuid) to service_role;

alter function private.teacher_owner_is_active(uuid) owner to postgres;
alter function public.create_checkout_order(text,integer,text) owner to postgres;
alter function private.confirm_payment_locked(uuid,uuid,text,uuid,text) owner to postgres;
alter function public.cancel_own_order(uuid,text) owner to postgres;
alter function public.archive_own_product(uuid) owner to postgres;

comment on table public.product_public_catalog is
  'Public-safe projection. Visibility differs from purchasability: is_purchasable=false is a visible Coming Soon product. Technical product UUIDs and private metadata are not client-readable.';

commit;
