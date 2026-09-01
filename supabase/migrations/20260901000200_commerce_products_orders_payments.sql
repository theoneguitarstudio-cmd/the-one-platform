begin;

create type public.product_type as enum ('trial', 'lesson_package', 'recorded_course', 'event', 'subscription', 'marketplace_item');
create type public.product_status as enum ('draft', 'active', 'archived');
create type public.product_owner_type as enum ('platform', 'teacher');
create type public.tax_behavior as enum ('unspecified', 'inclusive', 'exclusive', 'exempt');
create type public.commerce_order_status as enum ('pending', 'awaiting_payment', 'paid', 'cancelled', 'expired', 'refunded', 'partially_refunded');
create type public.commerce_payment_status as enum ('unpaid', 'pending', 'paid', 'failed', 'cancelled', 'partially_refunded', 'refunded');
create type public.commerce_order_source as enum ('web', 'admin', 'trial_legacy', 'migration', 'other');
create type public.payment_provider as enum ('manual_bank_transfer', 'manual_cash', 'line_pay', 'credit_card', 'stripe', 'tap_pay', 'ecpay', 'newebpay', 'other');
create type public.payment_method as enum ('bank_transfer', 'cash', 'credit_card', 'line_pay', 'other');
create type public.payment_submission_status as enum ('pending_review', 'approved', 'rejected');
create type public.fulfillment_event_status as enum ('pending', 'processing', 'processed', 'failed');
create type public.refund_status as enum ('pending', 'succeeded', 'failed', 'cancelled');

create table public.products (
  id uuid primary key default gen_random_uuid(),
  product_type public.product_type not null,
  status public.product_status not null default 'draft',
  public_slug text not null unique check (public_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' and char_length(public_slug) <= 100),
  name text not null check (char_length(name) between 1 and 160),
  short_description text check (short_description is null or char_length(short_description) <= 320),
  description text check (description is null or char_length(description) <= 10000),
  currency text not null default 'TWD' check (currency ~ '^[A-Z]{3}$'),
  base_price_amount bigint not null check (base_price_amount >= 0),
  owner_type public.product_owner_type not null,
  owner_teacher_user_id uuid references auth.users(id) on delete restrict,
  tax_behavior public.tax_behavior not null default 'unspecified',
  tax_metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(tax_metadata) = 'object'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  is_public boolean not null default false,
  is_purchasable boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  archived_at timestamptz,
  constraint products_owner_consistency check (
    (owner_type = 'platform' and owner_teacher_user_id is null)
    or (owner_type = 'teacher' and owner_teacher_user_id is not null)
  ),
  constraint products_status_timestamps check (
    (status <> 'active' or published_at is not null)
    and (status <> 'archived' or archived_at is not null)
  )
);

create table public.product_public_catalog (
  product_id uuid primary key references public.products(id) on delete cascade,
  product_type public.product_type not null,
  public_slug text not null unique,
  name text not null,
  short_description text,
  description text,
  currency text not null,
  base_price_amount bigint not null,
  owner_type public.product_owner_type not null,
  seller_display_name text not null,
  seller_public_slug text,
  is_purchasable boolean not null,
  published_at timestamptz not null,
  updated_at timestamptz not null
);
create table public.product_publication_requests (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete restrict,
  teacher_user_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'pending' check(status in('pending','approved','rejected','cancelled')),
  note text check(note is null or char_length(note)<=1000), reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz, review_reason text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index product_publication_one_pending_idx on public.product_publication_requests(product_id) where status='pending';

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique check (order_number ~ '^ONE-[0-9]{8}-[A-Z0-9]{10}$'),
  buyer_user_id uuid not null references auth.users(id) on delete restrict,
  status public.commerce_order_status not null default 'pending',
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  subtotal_amount bigint not null check (subtotal_amount >= 0),
  discount_amount bigint not null default 0 check (discount_amount >= 0),
  tax_amount bigint not null default 0 check (tax_amount >= 0),
  total_amount bigint not null check (total_amount >= 0 and total_amount = subtotal_amount - discount_amount + tax_amount),
  payment_status public.commerce_payment_status not null default 'unpaid',
  source public.commerce_order_source not null default 'web',
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 160),
  expires_at timestamptz,
  paid_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  unique (buyer_user_id, idempotency_key),
  constraint orders_paid_consistency check ((status = 'paid' and payment_status = 'paid' and paid_at is not null) or status <> 'paid'),
  constraint orders_cancelled_consistency check ((status = 'cancelled' and cancelled_at is not null) or status <> 'cancelled')
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  product_type_snapshot public.product_type not null,
  product_name_snapshot text not null,
  unit_price_amount bigint not null check (unit_price_amount >= 0),
  quantity integer not null check (quantity > 0 and quantity <= 100),
  line_subtotal_amount bigint not null check (line_subtotal_amount >= 0 and line_subtotal_amount = unit_price_amount * quantity),
  line_discount_amount bigint not null default 0 check (line_discount_amount >= 0),
  line_tax_amount bigint not null default 0 check (line_tax_amount >= 0),
  line_total_amount bigint not null check (line_total_amount >= 0 and line_total_amount = line_subtotal_amount - line_discount_amount + line_tax_amount),
  seller_type public.product_owner_type not null,
  seller_teacher_user_id uuid references auth.users(id) on delete restrict,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  constraint order_items_seller_consistency check (
    (seller_type = 'platform' and seller_teacher_user_id is null)
    or (seller_type = 'teacher' and seller_teacher_user_id is not null)
  )
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  provider public.payment_provider not null,
  provider_payment_id text,
  provider_event_id text,
  method public.payment_method not null,
  status public.commerce_payment_status not null default 'pending',
  amount bigint not null check (amount > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 160),
  provider_reference text,
  paid_at timestamptz,
  failed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  unique (provider, order_id, idempotency_key),
  unique (provider, provider_payment_id),
  unique (provider, provider_event_id),
  constraint payments_paid_consistency check ((status = 'paid' and paid_at is not null) or status <> 'paid')
);

create table public.payment_submissions (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null unique references public.payments(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  buyer_user_id uuid not null references auth.users(id) on delete restrict,
  payer_name text not null check (char_length(payer_name) between 1 and 100),
  transfer_last5 text not null check (transfer_last5 ~ '^[0-9]{5}$'),
  payment_note text check (payment_note is null or char_length(payment_note) <= 500),
  status public.payment_submission_status not null default 'pending_review',
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete restrict,
  review_reason text check (review_reason is null or char_length(review_reason) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_fulfillment_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  event_type text not null check (event_type = 'order.paid'),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  status public.fulfillment_event_status not null default 'pending',
  attempt_count integer not null default 0 check (attempt_count >= 0),
  available_at timestamptz not null default now(),
  processed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  unique (order_id, event_type)
);

create table public.refunds (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete restrict,
  payment_id uuid not null references public.payments(id) on delete restrict,
  status public.refund_status not null default 'pending', amount bigint not null check (amount > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'), provider_refund_id text,
  idempotency_key text not null, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (payment_id, idempotency_key)
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(), actor_user_id uuid references auth.users(id) on delete set null,
  action text not null, target_type text not null, target_id uuid not null,
  before_snapshot jsonb not null default '{}'::jsonb, after_snapshot jsonb not null default '{}'::jsonb,
  reason text, created_at timestamptz not null default now()
);

comment on table public.trial_orders is 'Epic 3 legacy Trial source of truth. Epic 4 does not dual-write this table.';
comment on table public.order_fulfillment_events is 'Transactional outbox. order.paid means payment committed, not entitlement fulfilled.';
comment on table public.product_public_catalog is 'Public-safe product projection; excludes owner UUIDs and all internal metadata.';

create index products_owner_idx on public.products(owner_teacher_user_id);
create index orders_buyer_created_idx on public.orders(buyer_user_id, created_at desc);
create index order_items_order_idx on public.order_items(order_id);
create index payments_order_idx on public.payments(order_id);
create index fulfillment_pending_idx on public.order_fulfillment_events(status, available_at);

create or replace function private.current_user_has_role(required_roles public.app_role[])
returns boolean language sql stable security definer set search_path = '' as $$
  select (select private.current_user_is_active()) and exists (
    select 1 from public.user_roles where user_id = (select auth.uid()) and role = any(required_roles)
  );
$$;
create or replace function private.teacher_owner_is_active(teacher_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p join public.user_roles r on r.user_id = p.user_id
    where p.user_id = teacher_user_id and p.account_status = 'active' and r.role = 'teacher');
$$;
create or replace function private.product_is_publicly_visible(requested_product_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.products p where p.id=requested_product_id and p.status='active' and p.is_public
    and (p.owner_type='platform' or private.teacher_owner_is_active(p.owner_teacher_user_id)));
$$;
create or replace function private.sync_product_public_catalog_row(requested_product_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare source_product public.products%rowtype; seller_name text; seller_slug text;
begin
  select * into source_product from public.products where id = requested_product_id;
  delete from public.product_public_catalog where product_id = requested_product_id;
  if source_product.id is null or source_product.status <> 'active' or not source_product.is_public then return; end if;
  if source_product.owner_type = 'teacher' then
    if not private.teacher_owner_is_active(source_product.owner_teacher_user_id) then return; end if;
    select p.display_name, tp.public_slug into seller_name, seller_slug
    from public.profiles p join public.teacher_profiles tp on tp.user_id = p.user_id
    where p.user_id = source_product.owner_teacher_user_id and tp.is_public and tp.teaching_status = 'active';
    if seller_name is null then return; end if;
  else seller_name := 'The One 樂玩吉他'; seller_slug := null; end if;
  insert into public.product_public_catalog(product_id, product_type, public_slug, name, short_description, description,
    currency, base_price_amount, owner_type, seller_display_name, seller_public_slug, is_purchasable, published_at, updated_at)
  values(source_product.id, source_product.product_type, source_product.public_slug, source_product.name,
    source_product.short_description, source_product.description, source_product.currency, source_product.base_price_amount,
    source_product.owner_type, seller_name, seller_slug, source_product.is_purchasable, source_product.published_at, source_product.updated_at);
end; $$;

create or replace function public.admin_confirm_payment(p_order_id uuid,p_payment_id uuid,p_provider_event_id text,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    then raise exception using errcode='42501',message='Not authorized'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 or char_length(p_reason)>1000 then raise exception 'Reason is required'; end if;
  return private.confirm_payment_locked(p_order_id,p_payment_id,nullif(trim(coalesce(p_provider_event_id,'')),''),caller,trim(p_reason));
end; $$;

create or replace function public.admin_confirm_cash_payment(p_order_id uuid,p_idempotency_key text,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); order_row public.orders%rowtype; payment_id uuid;
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    then raise exception using errcode='42501',message='Not authorized'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 or char_length(coalesce(p_idempotency_key,'')) not between 16 and 160 then raise exception 'Invalid request'; end if;
  select * into order_row from public.orders where id=p_order_id for update;
  if order_row.id is null then raise exception 'Order not found'; end if;
  select id into payment_id from public.payments where provider='manual_cash' and order_id=p_order_id and idempotency_key=p_idempotency_key;
  if payment_id is null then
    insert into public.payments(order_id,provider,method,status,amount,currency,idempotency_key)
    values(order_row.id,'manual_cash','cash','pending',order_row.total_amount,order_row.currency,p_idempotency_key)
    returning id into payment_id;
  elsif not exists(select 1 from public.payments where id=payment_id and order_id=p_order_id) then
    raise exception 'Idempotency key payload mismatch';
  end if;
  perform private.confirm_payment_locked(order_row.id,payment_id,'cash:'||p_idempotency_key,caller,trim(p_reason));
  return payment_id;
end; $$;

create or replace function public.admin_reject_payment_submission(p_payment_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); payment_row public.payments%rowtype; order_row public.orders%rowtype; requested_order_id uuid;
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    then raise exception using errcode='42501',message='Not authorized'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Reason is required'; end if;
  select order_id into requested_order_id from public.payments where id=p_payment_id;
  select * into order_row from public.orders where id=requested_order_id for update;
  select * into payment_row from public.payments where id=p_payment_id for update;
  if payment_row.id is null or payment_row.order_id<>order_row.id or payment_row.status<>'pending' then raise exception 'Payment cannot be rejected'; end if;
  update public.payments set status='failed',failed_at=now() where id=payment_row.id;
  update public.payment_submissions set status='rejected',reviewed_at=now(),reviewed_by=caller,review_reason=trim(p_reason) where payment_id=payment_row.id;
  if not exists(select 1 from public.payments where order_id=order_row.id and status='pending' and id<>payment_row.id)
    then update public.orders set payment_status='failed' where id=order_row.id; end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'payment_submission.rejected','payment',payment_row.id,jsonb_build_object('status',payment_row.status),jsonb_build_object('status','failed'),trim(p_reason));
  return payment_row.id;
end; $$;

create or replace function public.cancel_own_order(p_order_id uuid,p_reason text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); order_row public.orders%rowtype;
begin
  if caller is null or not private.current_user_is_active() then raise exception using errcode='42501',message='Not authorized'; end if;
  select * into order_row from public.orders where id=p_order_id for update;
  if order_row.id is null or order_row.buyer_user_id<>caller then raise exception using errcode='42501',message='Not authorized'; end if;
  if order_row.status='cancelled' then return order_row.id; end if;
  if order_row.status not in ('pending','awaiting_payment') or order_row.payment_status='paid' then raise exception 'Order cannot be cancelled'; end if;
  update public.payments set status='cancelled' where order_id=order_row.id and status in ('unpaid','pending');
  update public.orders set status='cancelled',payment_status=case when payment_status='paid' then payment_status else 'unpaid' end,cancelled_at=now() where id=order_row.id;
  return order_row.id;
end; $$;

create or replace function public.admin_cancel_order(p_order_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); order_row public.orders%rowtype;
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role]) then raise exception using errcode='42501',message='Not authorized'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Reason is required'; end if;
  select * into order_row from public.orders where id=p_order_id for update;
  if order_row.status='cancelled' then return order_row.id; end if;
  if order_row.status not in ('pending','awaiting_payment') or order_row.payment_status='paid' then raise exception 'Order cannot be cancelled'; end if;
  update public.payments set status='cancelled' where order_id=order_row.id and status in ('unpaid','pending');
  update public.orders set status='cancelled',payment_status='unpaid',cancelled_at=now() where id=order_row.id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'order.cancelled','order',order_row.id,jsonb_build_object('status',order_row.status),jsonb_build_object('status','cancelled'),trim(p_reason));
  return order_row.id;
end; $$;

create or replace function public.admin_expire_order(p_order_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); order_row public.orders%rowtype;
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role]) then raise exception using errcode='42501',message='Not authorized'; end if;
  select * into order_row from public.orders where id=p_order_id for update;
  if order_row.status='expired' then return order_row.id; end if;
  if order_row.status not in ('pending','awaiting_payment') or order_row.payment_status='paid' or order_row.expires_at is null or order_row.expires_at>now() then raise exception 'Order cannot be expired'; end if;
  update public.payments set status='cancelled' where order_id=order_row.id and status in ('unpaid','pending');
  update public.orders set status='expired',payment_status='unpaid' where id=order_row.id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'order.expired','order',order_row.id,jsonb_build_object('status',order_row.status),jsonb_build_object('status','expired'),trim(coalesce(p_reason,'Expired by operator')));
  return order_row.id;
end; $$;

create or replace function private.sync_product_public_catalog_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
begin perform private.sync_product_public_catalog_row(coalesce(new.id, old.id)); return coalesce(new, old); end; $$;
create or replace function private.sync_teacher_products_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
declare product_row record;
begin for product_row in select id from public.products where owner_teacher_user_id = coalesce(new.user_id, old.user_id)
loop perform private.sync_product_public_catalog_row(product_row.id); end loop; return coalesce(new, old); end; $$;

create trigger products_set_updated_at before update on public.products for each row execute function private.set_updated_at();
create trigger orders_set_updated_at before update on public.orders for each row execute function private.set_updated_at();
create trigger payments_set_updated_at before update on public.payments for each row execute function private.set_updated_at();
create trigger payment_submissions_set_updated_at before update on public.payment_submissions for each row execute function private.set_updated_at();
create trigger refunds_set_updated_at before update on public.refunds for each row execute function private.set_updated_at();
create trigger product_publication_requests_set_updated_at before update on public.product_publication_requests for each row execute function private.set_updated_at();
create trigger products_sync_catalog after insert or update or delete on public.products for each row execute function private.sync_product_public_catalog_trigger();
create trigger profiles_sync_product_catalog after update of display_name, account_status on public.profiles for each row execute function private.sync_teacher_products_trigger();
create trigger teacher_profiles_sync_product_catalog after update of public_slug, teaching_status, is_public on public.teacher_profiles for each row execute function private.sync_teacher_products_trigger();
create trigger user_roles_sync_product_catalog after insert or update or delete on public.user_roles for each row execute function private.sync_teacher_products_trigger();

alter table public.products enable row level security;
alter table public.product_public_catalog enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.payment_submissions enable row level security;
alter table public.order_fulfillment_events enable row level security;
alter table public.refunds enable row level security;
alter table public.audit_logs enable row level security;
alter table public.product_publication_requests enable row level security;

revoke all on public.products, public.product_public_catalog, public.orders, public.order_items, public.payments,
  public.payment_submissions, public.order_fulfillment_events, public.refunds, public.audit_logs, public.product_publication_requests from anon, authenticated;
grant select(product_id, product_type, public_slug, name, short_description, description, currency, base_price_amount,
  owner_type, seller_display_name, seller_public_slug, is_purchasable, published_at, updated_at)
  on public.product_public_catalog to anon, authenticated;
grant select(id, order_number, buyer_user_id, status, currency, subtotal_amount, discount_amount, tax_amount, total_amount,
  payment_status, source, expires_at, paid_at, cancelled_at, created_at, updated_at) on public.orders to authenticated;
grant select(id, order_id, product_id, product_type_snapshot, product_name_snapshot, unit_price_amount, quantity,
  line_subtotal_amount, line_discount_amount, line_tax_amount, line_total_amount, seller_type, created_at)
  on public.order_items to authenticated;
grant select(id, product_type, status, public_slug, name, short_description, description, currency, base_price_amount,
  owner_type, owner_teacher_user_id, tax_behavior, is_public, is_purchasable, created_at, updated_at, published_at, archived_at)
  on public.products to authenticated;
grant all on public.products, public.product_public_catalog, public.orders, public.order_items, public.payments,
  public.payment_submissions, public.order_fulfillment_events, public.refunds, public.audit_logs, public.product_publication_requests to service_role;

create policy product_catalog_public_read on public.product_public_catalog for select to anon, authenticated using (
  private.product_is_publicly_visible(product_id));
create policy products_teacher_read_own on public.products for select to authenticated using (
  (select private.current_user_has_role(array['teacher'::public.app_role])) and owner_type = 'teacher'
  and owner_teacher_user_id = (select auth.uid()));
create policy orders_buyer_read_own on public.orders for select to authenticated using (
  buyer_user_id = (select auth.uid()) and (select private.current_user_is_active()));
create policy order_items_buyer_read_own on public.order_items for select to authenticated using (
  exists (select 1 from public.orders o where o.id = order_id and o.buyer_user_id = (select auth.uid()))
  and (select private.current_user_is_active()));

create or replace function public.create_checkout_order(
  p_product_slug text, p_quantity integer, p_idempotency_key text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare caller uuid := auth.uid(); product_row public.products%rowtype; existing_order public.orders%rowtype;
  created_order_id uuid; calculated_subtotal bigint;
begin
  if caller is null or not private.current_user_is_active() then raise exception using errcode='42501', message='Not authorized'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 100 or char_length(coalesce(p_idempotency_key,'')) not between 16 and 160
    then raise exception using errcode='22023', message='Invalid checkout request'; end if;
  perform pg_advisory_xact_lock(hashtextextended(caller::text || ':' || p_idempotency_key, 0));
  select * into existing_order from public.orders where buyer_user_id=caller and idempotency_key=p_idempotency_key;
  if found then
    if not exists(select 1 from public.order_items i join public.products p on p.id=i.product_id
      where i.order_id=existing_order.id and p.public_slug=p_product_slug and i.quantity=p_quantity)
      then raise exception using errcode='22023', message='Idempotency key payload mismatch'; end if;
    return existing_order.id;
  end if;
  select * into product_row from public.products where public_slug=p_product_slug for share;
  if not found or product_row.status <> 'active' or not product_row.is_public or not product_row.is_purchasable
    then raise exception using errcode='P0001', message='Product is unavailable'; end if;
  if product_row.currency <> 'TWD' or product_row.base_price_amount <= 0
    then raise exception using errcode='P0001', message='Product pricing is unavailable'; end if;
  if product_row.owner_type='teacher' and not private.teacher_owner_is_active(product_row.owner_teacher_user_id)
    then raise exception using errcode='P0001', message='Product is unavailable'; end if;
  calculated_subtotal := product_row.base_price_amount * p_quantity;
  insert into public.orders(order_number,buyer_user_id,status,currency,subtotal_amount,discount_amount,tax_amount,
    total_amount,payment_status,source,idempotency_key,expires_at)
  values('ONE-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),
    caller,'awaiting_payment',product_row.currency,calculated_subtotal,0,0,calculated_subtotal,'unpaid','web',
    p_idempotency_key,now()+interval '24 hours') returning id into created_order_id;
  insert into public.order_items(order_id,product_id,product_type_snapshot,product_name_snapshot,unit_price_amount,
    quantity,line_subtotal_amount,line_discount_amount,line_tax_amount,line_total_amount,seller_type,seller_teacher_user_id)
  values(created_order_id,product_row.id,product_row.product_type,product_row.name,product_row.base_price_amount,p_quantity,
    calculated_subtotal,0,0,calculated_subtotal,product_row.owner_type,product_row.owner_teacher_user_id);
  return created_order_id;
exception when unique_violation then
  select id into created_order_id from public.orders where buyer_user_id=caller and idempotency_key=p_idempotency_key;
  if created_order_id is not null then return created_order_id; end if; raise;
end; $$;

create or replace function public.submit_bank_transfer(
  p_order_id uuid, p_payer_name text, p_transfer_last5 text, p_payment_note text, p_idempotency_key text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare caller uuid:=auth.uid(); order_row public.orders%rowtype; payment_id uuid;
begin
  if caller is null or not private.current_user_is_active() then raise exception using errcode='42501',message='Not authorized'; end if;
  if char_length(trim(coalesce(p_payer_name,''))) not between 1 and 100 or coalesce(p_transfer_last5,'') !~ '^[0-9]{5}$'
    or char_length(coalesce(p_payment_note,''))>500 or char_length(coalesce(p_idempotency_key,'')) not between 16 and 160
    then raise exception using errcode='22023',message='Invalid payment submission'; end if;
  perform pg_advisory_xact_lock(hashtextextended(caller::text||':'||p_idempotency_key,1));
  select * into order_row from public.orders where id=p_order_id for update;
  if not found or order_row.buyer_user_id<>caller then raise exception using errcode='42501',message='Not authorized'; end if;
  if order_row.status not in ('pending','awaiting_payment') or order_row.payment_status='paid' or order_row.expires_at<=now()
    then raise exception using errcode='P0001',message='Order cannot accept payment'; end if;
  select id into payment_id from public.payments where provider='manual_bank_transfer' and order_id=p_order_id and idempotency_key=p_idempotency_key;
  if payment_id is not null then
    if not exists(select 1 from public.payments where id=payment_id and order_id=p_order_id) then
      raise exception using errcode='22023',message='Idempotency key payload mismatch'; end if;
    return payment_id;
  end if;
  insert into public.payments(order_id,provider,method,status,amount,currency,idempotency_key)
  values(p_order_id,'manual_bank_transfer','bank_transfer','pending',order_row.total_amount,order_row.currency,p_idempotency_key)
  returning id into payment_id;
  insert into public.payment_submissions(payment_id,order_id,buyer_user_id,payer_name,transfer_last5,payment_note)
  values(payment_id,p_order_id,caller,trim(p_payer_name),p_transfer_last5,nullif(trim(coalesce(p_payment_note,'')),''));
  update public.orders set status='awaiting_payment',payment_status='pending' where id=p_order_id;
  return payment_id;
end; $$;

create or replace function private.confirm_payment_locked(
  requested_order_id uuid, requested_payment_id uuid, requested_event_id text, actor uuid, reason text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare order_row public.orders%rowtype; payment_row public.payments%rowtype;
begin
  select * into order_row from public.orders where id=requested_order_id for update;
  select * into payment_row from public.payments where id=requested_payment_id for update;
  if order_row.id is null or payment_row.id is null or payment_row.order_id<>order_row.id then raise exception 'Invalid payment'; end if;
  if payment_row.status='paid' and order_row.status='paid' then return order_row.id; end if;
  if order_row.status in ('cancelled','expired','refunded','partially_refunded') then raise exception 'Order is terminal'; end if;
  if payment_row.status not in ('pending','unpaid') or payment_row.amount<>order_row.total_amount or payment_row.currency<>order_row.currency
    then raise exception 'Payment does not match order'; end if;
  update public.payments set status='paid',paid_at=coalesce(paid_at,now()),provider_event_id=coalesce(provider_event_id,requested_event_id) where id=payment_row.id;
  update public.orders set status='paid',payment_status='paid',paid_at=coalesce(paid_at,now()) where id=order_row.id;
  update public.payment_submissions set status='approved',reviewed_at=now(),reviewed_by=actor,review_reason=reason where payment_id=payment_row.id;
  insert into public.order_fulfillment_events(order_id,event_type,payload) values(order_row.id,'order.paid',
    jsonb_build_object('order_id',order_row.id,'buyer_user_id',order_row.buyer_user_id,'currency',order_row.currency,'total_amount',order_row.total_amount))
    on conflict(order_id,event_type) do nothing;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(actor,'payment.confirmed','payment',payment_row.id,
    jsonb_build_object('payment_status',payment_row.status,'order_status',order_row.status),
    jsonb_build_object('payment_status','paid','order_status','paid'),reason)
  on conflict do nothing;
  return order_row.id;
end; $$;

create or replace function public.get_own_payment_summaries(p_order_id uuid)
returns table(id uuid,method public.payment_method,status public.commerce_payment_status,amount bigint,currency text,paid_at timestamptz,submission_status public.payment_submission_status)
language sql stable security definer set search_path='' as $$
  select p.id,p.method,p.status,p.amount,p.currency,p.paid_at,s.status
  from public.payments p join public.orders o on o.id=p.order_id
  left join public.payment_submissions s on s.payment_id=p.id
  where o.id=p_order_id and o.buyer_user_id=(select auth.uid()) and private.current_user_is_active();
$$;

create or replace function public.create_own_draft_product(p_product_type public.product_type,p_public_slug text,p_name text,
  p_short_description text,p_description text,p_currency text,p_base_price_amount bigint)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); created_id uuid;
begin
  if caller is null or not private.current_user_has_role(array['teacher'::public.app_role]) then raise exception using errcode='42501',message='Not authorized'; end if;
  if p_product_type not in ('lesson_package','recorded_course','event') then raise exception 'Unsupported teacher product type'; end if;
  if p_currency<>'TWD' or p_base_price_amount<0 then raise exception 'Invalid draft price'; end if;
  insert into public.products(product_type,status,public_slug,name,short_description,description,currency,base_price_amount,
    owner_type,owner_teacher_user_id,is_public,is_purchasable)
  values(p_product_type,'draft',p_public_slug,trim(p_name),nullif(trim(coalesce(p_short_description,'')),''),
    nullif(trim(coalesce(p_description,'')),''),p_currency,p_base_price_amount,'teacher',caller,false,false)
  returning id into created_id; return created_id;
end; $$;

create or replace function public.update_own_draft_product(p_product_id uuid,p_name text,p_short_description text,p_description text)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();
begin
  if caller is null or not private.current_user_has_role(array['teacher'::public.app_role]) then raise exception using errcode='42501',message='Not authorized'; end if;
  update public.products set name=trim(p_name),short_description=nullif(trim(coalesce(p_short_description,'')),''),
    description=nullif(trim(coalesce(p_description,'')),'') where id=p_product_id and owner_type='teacher'
    and owner_teacher_user_id=caller and status='draft';
  if not found then raise exception using errcode='42501',message='Not authorized'; end if; return p_product_id;
end; $$;

create or replace function public.archive_own_product(p_product_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();
begin
  if caller is null or not private.current_user_has_role(array['teacher'::public.app_role]) then raise exception using errcode='42501',message='Not authorized'; end if;
  update public.products set status='archived',is_public=false,is_purchasable=false,archived_at=now()
  where id=p_product_id and owner_type='teacher' and owner_teacher_user_id=caller and status in ('draft','active');
  if not found then raise exception using errcode='42501',message='Not authorized'; end if;
  update public.product_publication_requests set status='cancelled' where product_id=p_product_id and status='pending';
  return p_product_id;
end; $$;

create or replace function public.request_own_product_publication(p_product_id uuid,p_note text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); request_id uuid;
begin
  if caller is null or not private.current_user_has_role(array['teacher'::public.app_role]) then raise exception using errcode='42501',message='Not authorized'; end if;
  if char_length(coalesce(p_note,''))>1000 then raise exception 'Note is too long'; end if;
  if not exists(select 1 from public.products where id=p_product_id and owner_type='teacher' and owner_teacher_user_id=caller and status='draft')
    then raise exception using errcode='42501',message='Not authorized'; end if;
  insert into public.product_publication_requests(product_id,teacher_user_id,note)
  values(p_product_id,caller,nullif(trim(coalesce(p_note,'')),''))
  on conflict(product_id) where status='pending' do update set note=excluded.note,updated_at=now()
  returning id into request_id; return request_id;
end; $$;

create or replace function public.admin_set_product_status(p_product_id uuid,p_status public.product_status,p_is_public boolean,p_is_purchasable boolean,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); product_row public.products%rowtype;
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role]) then raise exception using errcode='42501',message='Not authorized'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Reason is required'; end if;
  select * into product_row from public.products where id=p_product_id for update;
  if product_row.id is null then raise exception 'Product not found'; end if;
  if p_status='active' and product_row.owner_type='teacher' and not private.teacher_owner_is_active(product_row.owner_teacher_user_id) then raise exception 'Teacher is inactive'; end if;
  update public.products set status=p_status,is_public=case when p_status='active' then p_is_public else false end,
    is_purchasable=case when p_status='active' then p_is_purchasable else false end,
    published_at=case when p_status='active' then coalesce(published_at,now()) else published_at end,
    archived_at=case when p_status='archived' then coalesce(archived_at,now()) else null end where id=p_product_id;
  if p_status in ('active','archived') then
    update public.product_publication_requests set status=case when p_status='active' then 'approved' else 'rejected' end,
      reviewed_by=caller,reviewed_at=now(),review_reason=trim(p_reason)
    where product_id=p_product_id and status='pending';
  end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'product.status_changed','product',p_product_id,
    jsonb_build_object('status',product_row.status,'is_public',product_row.is_public,'is_purchasable',product_row.is_purchasable),
    jsonb_build_object('status',p_status,'is_public',p_is_public,'is_purchasable',p_is_purchasable),trim(p_reason));
  return p_product_id;
end; $$;

alter function private.current_user_has_role(public.app_role[]) owner to postgres;
alter function private.teacher_owner_is_active(uuid) owner to postgres;
alter function private.product_is_publicly_visible(uuid) owner to postgres;
alter function private.sync_product_public_catalog_row(uuid) owner to postgres;
alter function private.sync_product_public_catalog_trigger() owner to postgres;
alter function private.sync_teacher_products_trigger() owner to postgres;
alter function private.confirm_payment_locked(uuid,uuid,text,uuid,text) owner to postgres;
alter function public.create_checkout_order(text,integer,text) owner to postgres;
alter function public.submit_bank_transfer(uuid,text,text,text,text) owner to postgres;
alter function public.admin_confirm_payment(uuid,uuid,text,text) owner to postgres;
alter function public.admin_confirm_cash_payment(uuid,text,text) owner to postgres;
alter function public.admin_reject_payment_submission(uuid,text) owner to postgres;
alter function public.cancel_own_order(uuid,text) owner to postgres;
alter function public.admin_cancel_order(uuid,text) owner to postgres;
alter function public.admin_expire_order(uuid,text) owner to postgres;
alter function public.get_own_payment_summaries(uuid) owner to postgres;
alter function public.create_own_draft_product(public.product_type,text,text,text,text,text,bigint) owner to postgres;
alter function public.update_own_draft_product(uuid,text,text,text) owner to postgres;
alter function public.archive_own_product(uuid) owner to postgres;
alter function public.request_own_product_publication(uuid,text) owner to postgres;
alter function public.admin_set_product_status(uuid,public.product_status,boolean,boolean,text) owner to postgres;

revoke all on function private.current_user_has_role(public.app_role[]), private.teacher_owner_is_active(uuid), private.product_is_publicly_visible(uuid),
  private.sync_product_public_catalog_row(uuid), private.sync_product_public_catalog_trigger(), private.sync_teacher_products_trigger(),
  private.confirm_payment_locked(uuid,uuid,text,uuid,text) from public,anon,authenticated;
revoke all on function public.create_checkout_order(text,integer,text), public.submit_bank_transfer(uuid,text,text,text,text),
  public.admin_confirm_payment(uuid,uuid,text,text), public.admin_confirm_cash_payment(uuid,text,text),
  public.admin_reject_payment_submission(uuid,text), public.cancel_own_order(uuid,text), public.admin_cancel_order(uuid,text),
  public.admin_expire_order(uuid,text), public.get_own_payment_summaries(uuid),
  public.create_own_draft_product(public.product_type,text,text,text,text,text,bigint),
  public.update_own_draft_product(uuid,text,text,text),public.archive_own_product(uuid),
  public.request_own_product_publication(uuid,text),
  public.admin_set_product_status(uuid,public.product_status,boolean,boolean,text) from public,anon,authenticated;
grant execute on function private.current_user_has_role(public.app_role[]),private.teacher_owner_is_active(uuid) to authenticated,service_role;
grant execute on function private.product_is_publicly_visible(uuid) to anon,authenticated,service_role;
grant execute on function private.sync_product_public_catalog_row(uuid),private.sync_product_public_catalog_trigger(),
  private.sync_teacher_products_trigger(),private.confirm_payment_locked(uuid,uuid,text,uuid,text) to service_role;
grant execute on function public.create_checkout_order(text,integer,text),public.submit_bank_transfer(uuid,text,text,text,text),
  public.admin_confirm_payment(uuid,uuid,text,text),public.admin_confirm_cash_payment(uuid,text,text),
  public.admin_reject_payment_submission(uuid,text),public.cancel_own_order(uuid,text),public.admin_cancel_order(uuid,text),
  public.admin_expire_order(uuid,text),public.get_own_payment_summaries(uuid),
  public.create_own_draft_product(public.product_type,text,text,text,text,text,bigint),
  public.update_own_draft_product(uuid,text,text,text),public.archive_own_product(uuid),
  public.request_own_product_publication(uuid,text),
  public.admin_set_product_status(uuid,public.product_status,boolean,boolean,text) to authenticated;
grant execute on all functions in schema public to service_role;

commit;
