begin;

create type public.entitlement_type as enum (
  'lesson_package', 'membership_access', 'learning_content_access',
  'premium_resource_access', 'training_access', 'coaching_access',
  'review_quota', 'assessment_access', 'certification_attempt'
);
create type public.entitlement_status as enum (
  'pending', 'active', 'exhausted', 'expired', 'revoked', 'cancelled'
);
create type public.lesson_booking_mode_eligibility as enum ('fixed', 'flexible', 'both');
create type public.entitlement_activation_rule as enum (
  'on_fulfillment', 'on_first_booking', 'scheduled', 'admin_specified'
);
create type public.entitlement_validity_unit as enum ('days', 'weeks', 'months');
create type public.lesson_credit_entry_type as enum (
  'allocation', 'reservation', 'release', 'consumption', 'reversal',
  'adjustment', 'expiration', 'refund_reversal', 'revocation'
);
create type public.lesson_credit_reservation_status as enum ('reserved', 'released', 'consumed');

create table public.lesson_package_product_configs (
  product_id uuid primary key references public.products(id) on delete restrict,
  lesson_count integer not null check (lesson_count > 0 and lesson_count <= 1000),
  validity_value integer not null check (validity_value > 0 and validity_value <= 1200),
  validity_unit public.entitlement_validity_unit not null,
  activation_rule public.entitlement_activation_rule not null default 'on_fulfillment',
  lesson_duration_minutes integer not null default 50
    check (lesson_duration_minutes > 0 and lesson_duration_minutes <= 480),
  booking_mode_eligibility public.lesson_booking_mode_eligibility not null default 'both',
  config_metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(config_metadata) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_item_fulfillment_snapshots (
  order_item_id uuid primary key references public.order_items(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  product_name text not null check (char_length(product_name) between 1 and 160),
  entitlement_type public.entitlement_type not null,
  lesson_count_per_unit integer not null check (lesson_count_per_unit > 0),
  validity_value integer not null check (validity_value > 0),
  validity_unit public.entitlement_validity_unit not null,
  activation_rule public.entitlement_activation_rule not null,
  lesson_duration_minutes integer not null check (lesson_duration_minutes > 0),
  booking_mode_eligibility public.lesson_booking_mode_eligibility not null,
  teacher_scope_user_id uuid references auth.users(id) on delete restrict,
  config_snapshot jsonb not null check (jsonb_typeof(config_snapshot) = 'object'),
  created_at timestamptz not null default now()
);

create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  beneficiary_user_id uuid not null references auth.users(id) on delete restrict,
  entitlement_type public.entitlement_type not null,
  status public.entitlement_status not null default 'pending',
  starts_at timestamptz not null,
  expires_at timestamptz,
  source_order_id uuid references public.orders(id) on delete restrict,
  source_order_item_id uuid references public.order_items(id) on delete restrict,
  source_fulfillment_event_id uuid references public.order_fulfillment_events(id) on delete restrict,
  product_id uuid references public.products(id) on delete restrict,
  product_name_snapshot text not null check (char_length(product_name_snapshot) between 1 and 160),
  teacher_scope_user_id uuid references auth.users(id) on delete restrict,
  booking_mode_eligibility public.lesson_booking_mode_eligibility,
  lesson_duration_minutes integer check (lesson_duration_minutes is null or lesson_duration_minutes > 0),
  config_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(config_snapshot) = 'object'),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete restrict,
  revoked_reason text check (revoked_reason is null or char_length(revoked_reason) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint entitlements_time_order check (expires_at is null or expires_at > starts_at),
  constraint entitlements_revoke_consistency check (
    (status = 'revoked' and revoked_at is not null and revoked_reason is not null)
    or status <> 'revoked'
  ),
  constraint entitlements_lesson_package_shape check (
    entitlement_type <> 'lesson_package'
    or (booking_mode_eligibility is not null and lesson_duration_minutes is not null)
  ),
  unique (source_fulfillment_event_id, source_order_item_id, entitlement_type)
);
alter table public.entitlements add constraint entitlements_id_beneficiary_unique
unique(id,beneficiary_user_id);

create table public.lesson_credit_reservations (
  id uuid primary key default gen_random_uuid(),
  entitlement_id uuid not null references public.entitlements(id) on delete restrict,
  beneficiary_user_id uuid not null references auth.users(id) on delete restrict,
  reservation_key text not null check (char_length(reservation_key) between 16 and 160),
  lesson_id uuid references public.lessons(id) on delete restrict,
  booking_reference text check (booking_reference is null or char_length(booking_reference) between 1 and 160),
  status public.lesson_credit_reservation_status not null default 'reserved',
  released_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lesson_credit_reservation_reference check (lesson_id is not null or booking_reference is not null),
  constraint lesson_credit_reservation_terminal check (
    (status = 'reserved' and released_at is null and consumed_at is null)
    or (status = 'released' and released_at is not null and consumed_at is null)
    or (status = 'consumed' and consumed_at is not null and released_at is null)
  ),
  foreign key(entitlement_id,beneficiary_user_id)
    references public.entitlements(id,beneficiary_user_id) on delete restrict,
  unique (beneficiary_user_id, reservation_key)
);
create unique index lesson_credit_reservations_one_per_lesson_idx
on public.lesson_credit_reservations(beneficiary_user_id,lesson_id)
where lesson_id is not null;
create unique index lesson_credit_reservations_one_per_booking_idx
on public.lesson_credit_reservations(beneficiary_user_id,booking_reference)
where booking_reference is not null;

create table public.lesson_credit_ledger (
  id uuid primary key default gen_random_uuid(),
  entitlement_id uuid not null references public.entitlements(id) on delete restrict,
  beneficiary_user_id uuid not null references auth.users(id) on delete restrict,
  entry_type public.lesson_credit_entry_type not null,
  available_delta integer not null default 0,
  reserved_delta integer not null default 0,
  consumed_delta integer not null default 0,
  reservation_id uuid references public.lesson_credit_reservations(id) on delete restrict,
  lesson_id uuid references public.lessons(id) on delete restrict,
  operation_key text not null check (char_length(operation_key) between 16 and 200),
  reason_code text not null check (char_length(reason_code) between 1 and 100),
  actor_user_id uuid references auth.users(id) on delete restrict,
  source_fulfillment_event_id uuid references public.order_fulfillment_events(id) on delete restrict,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  constraint lesson_credit_ledger_nonzero check (
    available_delta <> 0 or reserved_delta <> 0 or consumed_delta <> 0
  ),
  constraint lesson_credit_ledger_transfer_shape check (
    (entry_type = 'allocation' and available_delta > 0 and reserved_delta = 0 and consumed_delta = 0)
    or (entry_type = 'reservation' and available_delta = -1 and reserved_delta = 1 and consumed_delta = 0)
    or (entry_type = 'release' and available_delta = 1 and reserved_delta = -1 and consumed_delta = 0)
    or (entry_type = 'consumption' and available_delta = 0 and reserved_delta = -1 and consumed_delta = 1)
    or entry_type in ('reversal','adjustment','expiration','refund_reversal','revocation')
  ),
  foreign key(entitlement_id,beneficiary_user_id)
    references public.entitlements(id,beneficiary_user_id) on delete restrict,
  unique (entitlement_id, operation_key)
);

create table public.entitlement_expiry_history (
  id uuid primary key default gen_random_uuid(),
  entitlement_id uuid not null references public.entitlements(id) on delete restrict,
  old_expires_at timestamptz,
  new_expires_at timestamptz not null,
  reason text not null check (char_length(reason) between 3 and 1000),
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  actor_role public.app_role not null,
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 160),
  created_at timestamptz not null default now(),
  unique (entitlement_id, idempotency_key)
);

create table public.fulfillment_manual_retry_attempts (
  id uuid primary key default gen_random_uuid(),
  fulfillment_event_id uuid not null references public.order_fulfillment_events(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  actor_role public.app_role not null check (actor_role in ('admin','super_admin')),
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 160),
  reason text not null check (char_length(reason) between 3 and 1000),
  result public.fulfillment_event_status not null,
  safe_error_code text check (safe_error_code is null or char_length(safe_error_code) between 1 and 100),
  created_at timestamptz not null default now(),
  unique (idempotency_key)
);

create index entitlements_beneficiary_status_idx on public.entitlements(beneficiary_user_id, status, expires_at);
create index entitlements_teacher_scope_idx on public.entitlements(teacher_scope_user_id, beneficiary_user_id);
create index lesson_credit_ledger_entitlement_idx on public.lesson_credit_ledger(entitlement_id, created_at);
create index lesson_credit_reservations_entitlement_idx on public.lesson_credit_reservations(entitlement_id, status);
create index fulfillment_manual_retry_event_idx
on public.fulfillment_manual_retry_attempts(fulfillment_event_id,created_at);

comment on table public.entitlements is 'Commercial access rights. Commerce, entitlement, and learning achievement remain separate domains.';
comment on table public.lesson_credit_ledger is 'Immutable source of truth for lesson-credit available/reserved/consumed movements.';
comment on table public.order_item_fulfillment_snapshots is 'Purchase-time authoritative entitlement configuration; later Product edits do not alter purchased rights.';
comment on table public.fulfillment_manual_retry_attempts is 'Immutable actor-aware audit for idempotent Admin fulfillment retry attempts.';

create or replace function private.reject_epic5_append_only_mutation()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  raise exception using errcode='55000',message='APPEND_ONLY_HISTORY';
end; $$;

create or replace function private.protect_entitlement_authority_fields()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.beneficiary_user_id is distinct from old.beneficiary_user_id
    or new.entitlement_type is distinct from old.entitlement_type
    or new.source_order_id is distinct from old.source_order_id
    or new.source_order_item_id is distinct from old.source_order_item_id
    or new.source_fulfillment_event_id is distinct from old.source_fulfillment_event_id
    or new.product_id is distinct from old.product_id
    or new.product_name_snapshot is distinct from old.product_name_snapshot
    or new.teacher_scope_user_id is distinct from old.teacher_scope_user_id
    or new.booking_mode_eligibility is distinct from old.booking_mode_eligibility
    or new.lesson_duration_minutes is distinct from old.lesson_duration_minutes
    or new.config_snapshot is distinct from old.config_snapshot
    or new.created_at is distinct from old.created_at
  then
    raise exception using errcode='55000',message='ENTITLEMENT_AUTHORITY_FIELDS_IMMUTABLE';
  end if;
  return new;
end; $$;

create trigger order_item_fulfillment_snapshots_append_only
before update or delete on public.order_item_fulfillment_snapshots
for each row execute function private.reject_epic5_append_only_mutation();
create trigger lesson_credit_ledger_append_only
before update or delete on public.lesson_credit_ledger
for each row execute function private.reject_epic5_append_only_mutation();
create trigger entitlement_expiry_history_append_only
before update or delete on public.entitlement_expiry_history
for each row execute function private.reject_epic5_append_only_mutation();
create trigger fulfillment_manual_retry_attempts_append_only
before update or delete on public.fulfillment_manual_retry_attempts
for each row execute function private.reject_epic5_append_only_mutation();
create trigger entitlements_prevent_delete
before delete on public.entitlements
for each row execute function private.reject_epic5_append_only_mutation();
create trigger entitlements_protect_authority_fields
before update on public.entitlements
for each row execute function private.protect_entitlement_authority_fields();

create or replace function private.snapshot_order_item_fulfillment()
returns trigger language plpgsql security definer set search_path = '' as $$
declare cfg public.lesson_package_product_configs%rowtype;
begin
  if new.product_type_snapshot <> 'lesson_package' then return new; end if;
  select * into cfg from public.lesson_package_product_configs where product_id = new.product_id for share;
  if not found then raise exception using errcode='P0001',message='LESSON_PACKAGE_CONFIG_MISSING'; end if;
  if cfg.activation_rule <> 'on_fulfillment' then raise exception using errcode='P0001',message='UNSUPPORTED_ACTIVATION_RULE'; end if;
  insert into public.order_item_fulfillment_snapshots(
    order_item_id,product_id,product_name,entitlement_type,lesson_count_per_unit,
    validity_value,validity_unit,activation_rule,lesson_duration_minutes,
    booking_mode_eligibility,teacher_scope_user_id,config_snapshot
  ) values (
    new.id,new.product_id,new.product_name_snapshot,'lesson_package',cfg.lesson_count,
    cfg.validity_value,cfg.validity_unit,cfg.activation_rule,cfg.lesson_duration_minutes,
    cfg.booking_mode_eligibility,new.seller_teacher_user_id,
    jsonb_build_object('lesson_count',cfg.lesson_count,'validity_value',cfg.validity_value,
      'validity_unit',cfg.validity_unit,'activation_rule',cfg.activation_rule,
      'lesson_duration_minutes',cfg.lesson_duration_minutes,
      'booking_mode_eligibility',cfg.booking_mode_eligibility)
  );
  return new;
end; $$;

create trigger snapshot_order_item_fulfillment_after_insert
after insert on public.order_items for each row execute function private.snapshot_order_item_fulfillment();

create or replace function private.lesson_credit_balance(p_entitlement_id uuid)
returns table(available integer,reserved integer,consumed integer,total integer)
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(l.available_delta),0)::integer,
    coalesce(sum(l.reserved_delta),0)::integer,
    coalesce(sum(l.consumed_delta),0)::integer,
    coalesce(sum(l.available_delta+l.reserved_delta+l.consumed_delta),0)::integer
  from public.lesson_credit_ledger l where l.entitlement_id=p_entitlement_id;
$$;

create or replace function private.fulfill_order_paid_event(p_event_id uuid,p_actor uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare evt public.order_fulfillment_events%rowtype; ord public.orders%rowtype;
  item public.order_items%rowtype; snap public.order_item_fulfillment_snapshots%rowtype;
  entitlement_id uuid; entitlement_start timestamptz; entitlement_expiry timestamptz;
  allocation integer; inserted_count integer;
begin
  select * into evt from public.order_fulfillment_events where id=p_event_id for update;
  if not found or evt.event_type <> 'order.paid' then raise exception using errcode='P0001',message='FULFILLMENT_EVENT_NOT_FOUND'; end if;
  if evt.status='processed' then return evt.id; end if;
  update public.order_fulfillment_events set status='processing',attempt_count=attempt_count+1,last_error=null where id=evt.id;
  begin
    select * into ord from public.orders where id=evt.order_id for share;
    if not found or ord.status <> 'paid' or ord.payment_status <> 'paid' then raise exception using errcode='P0001',message='ORDER_NOT_PAID'; end if;
    for item in select * from public.order_items where order_id=ord.id order by id loop
      if item.product_type_snapshot <> 'lesson_package' then raise exception using errcode='P0001',message='UNSUPPORTED_FULFILLMENT_HANDLER'; end if;
      select * into snap from public.order_item_fulfillment_snapshots where order_item_id=item.id;
      if not found then raise exception using errcode='P0001',message='FULFILLMENT_SNAPSHOT_NOT_FOUND'; end if;
      entitlement_start:=transaction_timestamp();
      entitlement_expiry:=case snap.validity_unit
        when 'days' then entitlement_start+make_interval(days=>snap.validity_value)
        when 'weeks' then entitlement_start+make_interval(days=>snap.validity_value*7)
        when 'months' then entitlement_start+make_interval(months=>snap.validity_value) end;
      allocation:=snap.lesson_count_per_unit*item.quantity;
      insert into public.entitlements(
        beneficiary_user_id,entitlement_type,status,starts_at,expires_at,source_order_id,
        source_order_item_id,source_fulfillment_event_id,product_id,product_name_snapshot,
        teacher_scope_user_id,booking_mode_eligibility,lesson_duration_minutes,config_snapshot
      ) values (
        ord.buyer_user_id,'lesson_package','active',entitlement_start,entitlement_expiry,ord.id,
        item.id,evt.id,item.product_id,item.product_name_snapshot,snap.teacher_scope_user_id,
        snap.booking_mode_eligibility,snap.lesson_duration_minutes,
        snap.config_snapshot||jsonb_build_object('order_item_quantity',item.quantity,'allocated_credits',allocation)
      ) on conflict(source_fulfillment_event_id,source_order_item_id,entitlement_type) do nothing
      returning id into entitlement_id;
      get diagnostics inserted_count=row_count;
      if inserted_count=0 then
        select id into entitlement_id from public.entitlements
        where source_fulfillment_event_id=evt.id and source_order_item_id=item.id and entitlement_type='lesson_package';
      else
        insert into public.lesson_credit_ledger(
          entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,
          reason_code,actor_user_id,source_fulfillment_event_id,metadata
        ) values(entitlement_id,ord.buyer_user_id,'allocation',allocation,
          'fulfillment:'||evt.id::text||':'||item.id::text,'purchase_fulfillment',p_actor,evt.id,
          jsonb_build_object('order_id',ord.id,'order_item_id',item.id));
        insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
        values(p_actor,'entitlement.granted','entitlement',entitlement_id,
          jsonb_build_object('type','lesson_package','beneficiary_user_id',ord.buyer_user_id,
            'allocated_credits',allocation,'expires_at',entitlement_expiry),'order.paid fulfillment');
      end if;
    end loop;
    update public.order_fulfillment_events set status='processed',processed_at=now(),last_error=null where id=evt.id;
  exception when others then
    update public.order_fulfillment_events set status='failed',processed_at=null,
      last_error=case when sqlstate='P0001' then sqlerrm else 'FULFILLMENT_FAILED' end where id=evt.id;
  end;
  return evt.id;
end; $$;

create or replace function public.process_order_fulfillment_event(p_event_id uuid)
returns public.fulfillment_event_status language plpgsql security definer set search_path = '' as $$
declare result_event_id uuid; result_status public.fulfillment_event_status;
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception using errcode='42501',message='Not authorized'; end if;
  result_event_id:=private.fulfill_order_paid_event(p_event_id,auth.uid());
  select status into result_status from public.order_fulfillment_events where id=result_event_id;
  return result_status;
end; $$;

create or replace function public.admin_retry_order_fulfillment_event(
  p_event_id uuid,p_reason text,p_idempotency_key text
) returns public.fulfillment_event_status
language plpgsql security definer set search_path = '' as $$
declare caller uuid:=auth.uid(); actor_role public.app_role;
  existing_attempt public.fulfillment_manual_retry_attempts%rowtype;
  evt public.order_fulfillment_events%rowtype; result_event_id uuid;
  result_status public.fulfillment_event_status; result_error text;
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    then raise exception using errcode='42501',message='Not authorized'; end if;
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or char_length(coalesce(p_idempotency_key,'')) not between 16 and 160
    then raise exception using errcode='22023',message='INVALID_FULFILLMENT_RETRY'; end if;
  select role into actor_role from public.user_roles where user_id=caller
    and role in('super_admin','admin')
    order by case role when 'super_admin' then 1 else 2 end limit 1;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'the-one:v1:manual-fulfillment-retry:'||p_idempotency_key,5));
  select * into existing_attempt from public.fulfillment_manual_retry_attempts
  where idempotency_key=p_idempotency_key;
  if found then
    if existing_attempt.actor_user_id is distinct from caller
      or existing_attempt.fulfillment_event_id is distinct from p_event_id
      or existing_attempt.reason is distinct from trim(p_reason)
      then raise exception using errcode='P0001',message='FULFILLMENT_RETRY_PAYLOAD_MISMATCH'; end if;
    return existing_attempt.result;
  end if;
  select * into evt from public.order_fulfillment_events where id=p_event_id;
  if not found or evt.event_type<>'order.paid'
    then raise exception using errcode='P0001',message='FULFILLMENT_EVENT_NOT_FOUND'; end if;
  result_event_id:=private.fulfill_order_paid_event(p_event_id,caller);
  select status,last_error into result_status,result_error
  from public.order_fulfillment_events where id=result_event_id;
  insert into public.fulfillment_manual_retry_attempts(
    fulfillment_event_id,order_id,actor_user_id,actor_role,idempotency_key,
    reason,result,safe_error_code
  ) values(evt.id,evt.order_id,caller,actor_role,p_idempotency_key,trim(p_reason),
    result_status,case when result_status='failed' then coalesce(result_error,'FULFILLMENT_FAILED') end);
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,after_snapshot,reason
  ) values(caller,'fulfillment.manual_retry','order_fulfillment_event',evt.id,
    jsonb_build_object('actor_role',actor_role,'order_id',evt.order_id,
      'result',result_status,'safe_error_code',case when result_status='failed'
        then coalesce(result_error,'FULFILLMENT_FAILED') end,
      'idempotency_key',p_idempotency_key),trim(p_reason));
  return result_status;
end; $$;

create or replace function public.reserve_lesson_credit(
  p_entitlement_id uuid,p_reservation_key text,p_lesson_id uuid default null,p_booking_reference text default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare caller uuid:=auth.uid(); ent public.entitlements%rowtype;
  existing public.lesson_credit_reservations%rowtype; balance record; result_id uuid;
begin
  if caller is null or not private.current_user_is_active() then raise exception using errcode='42501',message='Not authorized'; end if;
  if char_length(coalesce(p_reservation_key,'')) not between 16 and 160
    or (p_lesson_id is null and nullif(trim(coalesce(p_booking_reference,'')),'') is null)
    then raise exception using errcode='22023',message='INVALID_CREDIT_RESERVATION'; end if;
  select * into ent from public.entitlements where id=p_entitlement_id for update;
  if not found or ent.beneficiary_user_id<>caller or ent.entitlement_type<>'lesson_package'
    then raise exception using errcode='42501',message='Not authorized'; end if;
  select * into existing from public.lesson_credit_reservations
  where beneficiary_user_id=caller and reservation_key=p_reservation_key for update;
  if found then
    if existing.entitlement_id is distinct from ent.id
      or existing.lesson_id is distinct from p_lesson_id
      or existing.booking_reference is distinct from nullif(trim(coalesce(p_booking_reference,'')),'')
      then raise exception using errcode='P0001',message='CREDIT_RESERVATION_PAYLOAD_MISMATCH'; end if;
    if existing.status='reserved' then return existing.id; end if;
    raise exception using errcode='P0001',message=case when existing.status='consumed'
      then 'CREDIT_ALREADY_CONSUMED' else 'CREDIT_ALREADY_RELEASED' end;
  end if;
  if ent.status<>'active' then raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ACTIVE'; end if;
  if ent.starts_at>now() then raise exception using errcode='P0001',message='ENTITLEMENT_NOT_STARTED'; end if;
  if ent.expires_at is not null and ent.expires_at<=now() then raise exception using errcode='P0001',message='ENTITLEMENT_EXPIRED'; end if;
  if p_lesson_id is not null and not exists(
    select 1 from public.lessons where id=p_lesson_id and student_user_id=caller
  ) then raise exception using errcode='42501',message='Not authorized'; end if;
  select * into balance from private.lesson_credit_balance(ent.id);
  if balance.available<1 then raise exception using errcode='P0001',message='INSUFFICIENT_LESSON_CREDITS'; end if;
  insert into public.lesson_credit_reservations(
    entitlement_id,beneficiary_user_id,reservation_key,lesson_id,booking_reference
  ) values(ent.id,caller,p_reservation_key,p_lesson_id,nullif(trim(coalesce(p_booking_reference,'')),''))
  on conflict do nothing
  returning id into result_id;
  if result_id is null then
    raise exception using errcode='P0001',message='CREDIT_ALREADY_RESERVED';
  end if;
  insert into public.lesson_credit_ledger(
    entitlement_id,beneficiary_user_id,entry_type,available_delta,reserved_delta,
    reservation_id,lesson_id,operation_key,reason_code,actor_user_id
  ) values(ent.id,caller,'reservation',-1,1,result_id,p_lesson_id,
    'reserve:'||p_reservation_key,'booking_reservation',caller);
  return result_id;
end; $$;

create or replace function public.release_lesson_credit(
  p_reservation_id uuid,p_reason text default 'booking_release'
) returns uuid language plpgsql security definer set search_path = '' as $$
declare caller uuid:=auth.uid(); ent public.entitlements%rowtype;
  res public.lesson_credit_reservations%rowtype;
begin
  if caller is null or not private.current_user_is_active()
    then raise exception using errcode='42501',message='Not authorized'; end if;
  select e.* into ent from public.entitlements e
  join public.lesson_credit_reservations r on r.entitlement_id=e.id
  where r.id=p_reservation_id for update of e;
  if not found or (ent.beneficiary_user_id<>caller and not private.current_user_has_role(
    array['admin'::public.app_role,'super_admin'::public.app_role]))
    then raise exception using errcode='42501',message='Not authorized'; end if;
  select * into res from public.lesson_credit_reservations where id=p_reservation_id for update;
  if res.status='released' then return res.id; end if;
  if res.status='consumed' then raise exception using errcode='P0001',message='CREDIT_ALREADY_CONSUMED'; end if;
  update public.lesson_credit_reservations set status='released',released_at=now(),updated_at=now() where id=res.id;
  insert into public.lesson_credit_ledger(
    entitlement_id,beneficiary_user_id,entry_type,available_delta,reserved_delta,
    reservation_id,lesson_id,operation_key,reason_code,actor_user_id
  ) values(ent.id,ent.beneficiary_user_id,'release',1,-1,res.id,res.lesson_id,
    'release:'||res.id::text,left(coalesce(nullif(trim(p_reason),''),'booking_release'),100),caller);
  if ent.status='exhausted' and (ent.expires_at is null or ent.expires_at>now())
    then update public.entitlements set status='active',updated_at=now() where id=ent.id; end if;
  return res.id;
end; $$;

create or replace function public.consume_lesson_credit(p_reservation_id uuid,p_lesson_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare caller uuid:=auth.uid(); ent public.entitlements%rowtype;
  res public.lesson_credit_reservations%rowtype; balance record;
begin
  if caller is null or not private.current_user_is_active()
    then raise exception using errcode='42501',message='Not authorized'; end if;
  select e.* into ent from public.entitlements e
  join public.lesson_credit_reservations r on r.entitlement_id=e.id
  where r.id=p_reservation_id for update of e;
  if not found then raise exception using errcode='P0001',message='CREDIT_RESERVATION_NOT_FOUND'; end if;
  select * into res from public.lesson_credit_reservations where id=p_reservation_id for update;
  if res.lesson_id is distinct from p_lesson_id
    then raise exception using errcode='P0001',message='CREDIT_RESERVATION_PAYLOAD_MISMATCH'; end if;
  if not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    and not exists(
      select 1 from public.lessons l join public.teacher_profiles tp on tp.user_id=l.teacher_user_id
      where l.id=p_lesson_id and l.teacher_user_id=caller
        and l.student_user_id=ent.beneficiary_user_id and l.status='completed'
      and tp.teaching_status='active'
    ) then raise exception using errcode='42501',message='Not authorized'; end if;
  if res.status='consumed' then return res.id; end if;
  if res.status='released' then raise exception using errcode='P0001',message='CREDIT_ALREADY_RELEASED'; end if;
  update public.lesson_credit_reservations
  set status='consumed',consumed_at=now(),updated_at=now() where id=res.id;
  insert into public.lesson_credit_ledger(
    entitlement_id,beneficiary_user_id,entry_type,reserved_delta,consumed_delta,
    reservation_id,lesson_id,operation_key,reason_code,actor_user_id
  ) values(ent.id,ent.beneficiary_user_id,'consumption',-1,1,res.id,p_lesson_id,
    'consume:'||res.id::text,'lesson_completed',caller);
  select * into balance from private.lesson_credit_balance(ent.id);
  if balance.available=0 and balance.reserved=0 then
    update public.entitlements set status='exhausted',updated_at=now()
    where id=ent.id and status='active';
  end if;
  return res.id;
end; $$;

create or replace function public.extend_lesson_package_entitlement(
  p_entitlement_id uuid,p_new_expires_at timestamptz,p_reason text,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare caller uuid:=auth.uid(); ent public.entitlements%rowtype;
  actor_role public.app_role; balance record; existing_history public.entitlement_expiry_history%rowtype;
begin
  if caller is null or not private.current_user_is_active()
    then raise exception using errcode='42501',message='Not authorized'; end if;
  if p_new_expires_at is null or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or char_length(coalesce(p_idempotency_key,'')) not between 16 and 160
    then raise exception using errcode='22023',message='INVALID_ENTITLEMENT_EXTENSION'; end if;
  select * into ent from public.entitlements where id=p_entitlement_id for update;
  if not found or ent.entitlement_type<>'lesson_package'
    then raise exception using errcode='P0001',message='ENTITLEMENT_NOT_FOUND'; end if;
  if private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role]) then
    select role into actor_role from public.user_roles where user_id=caller
      and role in('super_admin','admin') order by case role when 'super_admin' then 1 else 2 end limit 1;
  elsif private.current_user_has_role(array['teacher'::public.app_role]) and exists(
    select 1 from public.teacher_profiles tp
    join public.student_teacher_relationships r on r.teacher_user_id=tp.user_id
    where tp.user_id=caller and tp.teaching_status='active'
      and r.student_user_id=ent.beneficiary_user_id
      and r.relationship_status in('active','paused')
      and (ent.teacher_scope_user_id is null or ent.teacher_scope_user_id=caller)
  ) then actor_role:='teacher';
  else raise exception using errcode='42501',message='UNAUTHORIZED_ENTITLEMENT_EXTENSION'; end if;
  select * into existing_history from public.entitlement_expiry_history
  where entitlement_id=ent.id and idempotency_key=p_idempotency_key;
  if found then
    if existing_history.new_expires_at is distinct from p_new_expires_at
      or existing_history.reason is distinct from trim(p_reason)
      then raise exception using errcode='P0001',message='ENTITLEMENT_EXTENSION_PAYLOAD_MISMATCH'; end if;
    return ent.id;
  end if;
  if p_new_expires_at<=coalesce(ent.expires_at,ent.starts_at)
    or p_new_expires_at>now()+interval '10 years'
    then raise exception using errcode='22023',message='INVALID_ENTITLEMENT_EXTENSION'; end if;
  insert into public.entitlement_expiry_history(
    entitlement_id,old_expires_at,new_expires_at,reason,actor_user_id,actor_role,idempotency_key
  ) values(ent.id,ent.expires_at,p_new_expires_at,trim(p_reason),caller,actor_role,p_idempotency_key);
  select * into balance from private.lesson_credit_balance(ent.id);
  update public.entitlements set expires_at=p_new_expires_at,
    status=case when status='expired' and balance.available>0 then 'active' else status end,
    updated_at=now() where id=ent.id;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(caller,'entitlement.expiry_extended','entitlement',ent.id,
    jsonb_build_object('expires_at',ent.expires_at),jsonb_build_object('expires_at',p_new_expires_at),trim(p_reason));
  return ent.id;
end; $$;

create or replace function public.admin_adjust_lesson_credits(
  p_entitlement_id uuid,p_quantity_delta integer,p_reason text,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare caller uuid:=auth.uid(); ent public.entitlements%rowtype; balance record;
  existing_adjustment public.lesson_credit_ledger%rowtype;
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    then raise exception using errcode='42501',message='Not authorized'; end if;
  if p_quantity_delta=0 or p_quantity_delta is null or abs(p_quantity_delta)>1000
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or char_length(coalesce(p_idempotency_key,'')) not between 16 and 160
    then raise exception using errcode='22023',message='INVALID_CREDIT_ADJUSTMENT'; end if;
  select * into ent from public.entitlements where id=p_entitlement_id for update;
  if not found or ent.entitlement_type<>'lesson_package' or ent.status in('revoked','cancelled')
    then raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ADJUSTABLE'; end if;
  select * into existing_adjustment from public.lesson_credit_ledger
  where entitlement_id=ent.id and operation_key='adjust:'||p_idempotency_key;
  if found then
    if existing_adjustment.available_delta is distinct from p_quantity_delta
      or existing_adjustment.metadata->>'reason' is distinct from trim(p_reason)
      then raise exception using errcode='P0001',message='CREDIT_ADJUSTMENT_PAYLOAD_MISMATCH'; end if;
    return ent.id;
  end if;
  select * into balance from private.lesson_credit_balance(ent.id);
  if balance.available+p_quantity_delta<0
    then raise exception using errcode='P0001',message='INSUFFICIENT_LESSON_CREDITS'; end if;
  insert into public.lesson_credit_ledger(
    entitlement_id,beneficiary_user_id,entry_type,available_delta,operation_key,
    reason_code,actor_user_id,metadata
  ) values(ent.id,ent.beneficiary_user_id,'adjustment',p_quantity_delta,
    'adjust:'||p_idempotency_key,'admin_adjustment',caller,jsonb_build_object('reason',trim(p_reason)));
  update public.entitlements set
    status=case when balance.available+p_quantity_delta=0 and balance.reserved=0
      then 'exhausted'::public.entitlement_status else 'active'::public.entitlement_status end,
    updated_at=now() where id=ent.id;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(caller,'entitlement.credit_adjusted','entitlement',ent.id,
    jsonb_build_object('available',balance.available),
    jsonb_build_object('available',balance.available+p_quantity_delta,'delta',p_quantity_delta),trim(p_reason));
  return ent.id;
end; $$;

create or replace function public.admin_revoke_entitlement(
  p_entitlement_id uuid,p_reason text,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare caller uuid:=auth.uid(); ent public.entitlements%rowtype; balance record;
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    then raise exception using errcode='42501',message='Not authorized'; end if;
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or char_length(coalesce(p_idempotency_key,'')) not between 16 and 160
    then raise exception using errcode='22023',message='INVALID_REVOCATION'; end if;
  select * into ent from public.entitlements where id=p_entitlement_id for update;
  if not found then raise exception using errcode='P0001',message='ENTITLEMENT_NOT_FOUND'; end if;
  if ent.status='revoked' then return ent.id; end if;
  select * into balance from private.lesson_credit_balance(ent.id);
  if balance.available<>0 or balance.reserved<>0 then
    insert into public.lesson_credit_ledger(
      entitlement_id,beneficiary_user_id,entry_type,available_delta,reserved_delta,
      operation_key,reason_code,actor_user_id,metadata
    ) values(ent.id,ent.beneficiary_user_id,'revocation',-balance.available,-balance.reserved,
      'revoke:'||p_idempotency_key,'admin_revocation',caller,jsonb_build_object('reason',trim(p_reason)));
  end if;
  update public.lesson_credit_reservations set status='released',released_at=now(),updated_at=now()
  where entitlement_id=ent.id and status='reserved';
  update public.entitlements set status='revoked',revoked_at=now(),revoked_by=caller,
    revoked_reason=trim(p_reason),updated_at=now() where id=ent.id;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(caller,'entitlement.revoked','entitlement',ent.id,
    jsonb_build_object('status',ent.status,'available',balance.available,'reserved',balance.reserved),
    jsonb_build_object('status','revoked','available',0,'reserved',0),trim(p_reason));
  return ent.id;
end; $$;

create or replace function public.admin_set_lesson_package_product_config(
  p_product_id uuid,p_lesson_count integer,p_validity_value integer,
  p_validity_unit public.entitlement_validity_unit,
  p_lesson_duration_minutes integer,p_booking_mode public.lesson_booking_mode_eligibility,
  p_reason text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare caller uuid:=auth.uid(); product_row public.products%rowtype;
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    then raise exception using errcode='42501',message='Not authorized'; end if;
  if p_lesson_count is null or p_lesson_count not between 1 and 1000
    or p_validity_value is null or p_validity_value not between 1 and 1200
    or p_lesson_duration_minutes is null or p_lesson_duration_minutes not between 1 and 480
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    then raise exception using errcode='22023',message='INVALID_LESSON_PACKAGE_CONFIG'; end if;
  select * into product_row from public.products where id=p_product_id for update;
  if not found or product_row.product_type<>'lesson_package'
    then raise exception using errcode='P0001',message='LESSON_PACKAGE_PRODUCT_NOT_FOUND'; end if;
  insert into public.lesson_package_product_configs(
    product_id,lesson_count,validity_value,validity_unit,activation_rule,
    lesson_duration_minutes,booking_mode_eligibility
  ) values(p_product_id,p_lesson_count,p_validity_value,p_validity_unit,'on_fulfillment',
    p_lesson_duration_minutes,p_booking_mode)
  on conflict(product_id) do update set lesson_count=excluded.lesson_count,
    validity_value=excluded.validity_value,validity_unit=excluded.validity_unit,
    lesson_duration_minutes=excluded.lesson_duration_minutes,
    booking_mode_eligibility=excluded.booking_mode_eligibility,updated_at=now();
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(caller,'lesson_package.configured','product',p_product_id,
    jsonb_build_object('lesson_count',p_lesson_count,'validity_value',p_validity_value,
      'validity_unit',p_validity_unit,'lesson_duration_minutes',p_lesson_duration_minutes,
      'booking_mode_eligibility',p_booking_mode),trim(p_reason));
  return p_product_id;
end; $$;

create or replace function public.get_own_lesson_entitlement_summaries()
returns table(
  id uuid,package_name text,credits_total integer,credits_available integer,
  credits_reserved integer,credits_consumed integer,starts_at timestamptz,
  expires_at timestamptz,status public.entitlement_status,
  booking_mode_eligibility public.lesson_booking_mode_eligibility,
  lesson_duration_minutes integer
) language sql stable security definer set search_path = '' as $$
  select e.id,e.product_name_snapshot,b.total,b.available,b.reserved,b.consumed,
    e.starts_at,e.expires_at,
    case when e.status='active' and e.expires_at is not null and e.expires_at<=now()
      then 'expired'::public.entitlement_status else e.status end,
    e.booking_mode_eligibility,e.lesson_duration_minutes
  from public.entitlements e cross join lateral private.lesson_credit_balance(e.id) b
  where e.beneficiary_user_id=(select auth.uid())
    and e.entitlement_type='lesson_package' and private.current_user_is_active()
  order by e.expires_at nulls last,e.created_at;
$$;

create or replace function public.get_teacher_student_lesson_entitlement_summaries(p_student_user_id uuid)
returns table(
  id uuid,package_name text,credits_available integer,credits_reserved integer,
  expires_at timestamptz,status public.entitlement_status,
  booking_mode_eligibility public.lesson_booking_mode_eligibility
) language plpgsql stable security definer set search_path = '' as $$
declare caller uuid:=auth.uid();
begin
  if caller is null or not private.current_user_has_role(array['teacher'::public.app_role])
    or not exists(
      select 1 from public.teacher_profiles tp
      join public.student_teacher_relationships r on r.teacher_user_id=tp.user_id
      where tp.user_id=caller and tp.teaching_status='active'
        and r.student_user_id=p_student_user_id and r.relationship_status in('active','paused')
    ) then raise exception using errcode='42501',message='Not authorized'; end if;
  return query select e.id,e.product_name_snapshot,b.available,b.reserved,e.expires_at,
    case when e.status='active' and e.expires_at is not null and e.expires_at<=now()
      then 'expired'::public.entitlement_status else e.status end,e.booking_mode_eligibility
  from public.entitlements e cross join lateral private.lesson_credit_balance(e.id) b
  where e.beneficiary_user_id=p_student_user_id and e.entitlement_type='lesson_package'
    and (e.teacher_scope_user_id is null or e.teacher_scope_user_id=caller)
  order by e.expires_at nulls last,e.created_at;
end; $$;

create or replace function public.get_admin_lesson_entitlement_summaries()
returns table(
  id uuid,beneficiary_user_id uuid,beneficiary_name text,package_name text,
  credits_total integer,credits_available integer,credits_reserved integer,
  credits_consumed integer,starts_at timestamptz,expires_at timestamptz,
  status public.entitlement_status,
  booking_mode_eligibility public.lesson_booking_mode_eligibility
) language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    then raise exception using errcode='42501',message='Not authorized'; end if;
  return query select e.id,e.beneficiary_user_id,p.display_name,e.product_name_snapshot,
    b.total,b.available,b.reserved,b.consumed,e.starts_at,e.expires_at,
    case when e.status='active' and e.expires_at is not null and e.expires_at<=now()
      then 'expired'::public.entitlement_status else e.status end,e.booking_mode_eligibility
  from public.entitlements e join public.profiles p on p.user_id=e.beneficiary_user_id
  cross join lateral private.lesson_credit_balance(e.id) b
  where e.entitlement_type='lesson_package' order by e.created_at desc;
end; $$;

alter table public.lesson_package_product_configs enable row level security;
alter table public.order_item_fulfillment_snapshots enable row level security;
alter table public.entitlements enable row level security;
alter table public.lesson_credit_reservations enable row level security;
alter table public.lesson_credit_ledger enable row level security;
alter table public.entitlement_expiry_history enable row level security;
alter table public.fulfillment_manual_retry_attempts enable row level security;

create policy entitlements_select_own on public.entitlements for select to authenticated
using (beneficiary_user_id=(select auth.uid()) and (select private.current_user_is_active()));

revoke all on table public.lesson_package_product_configs,
  public.order_item_fulfillment_snapshots,public.entitlements,
  public.lesson_credit_reservations,public.lesson_credit_ledger,
  public.entitlement_expiry_history,public.fulfillment_manual_retry_attempts
from public,anon,authenticated,service_role;
grant select(id,entitlement_type,status,starts_at,expires_at,product_name_snapshot,
  booking_mode_eligibility,lesson_duration_minutes,created_at,updated_at)
on public.entitlements to authenticated;

alter function private.reject_epic5_append_only_mutation() owner to postgres;
alter function private.protect_entitlement_authority_fields() owner to postgres;
alter function private.snapshot_order_item_fulfillment() owner to postgres;
alter function private.lesson_credit_balance(uuid) owner to postgres;
alter function private.fulfill_order_paid_event(uuid,uuid) owner to postgres;
alter function public.process_order_fulfillment_event(uuid) owner to postgres;
alter function public.admin_retry_order_fulfillment_event(uuid,text,text) owner to postgres;
alter function public.reserve_lesson_credit(uuid,text,uuid,text) owner to postgres;
alter function public.release_lesson_credit(uuid,text) owner to postgres;
alter function public.consume_lesson_credit(uuid,uuid) owner to postgres;
alter function public.extend_lesson_package_entitlement(uuid,timestamptz,text,text) owner to postgres;
alter function public.admin_adjust_lesson_credits(uuid,integer,text,text) owner to postgres;
alter function public.admin_revoke_entitlement(uuid,text,text) owner to postgres;
alter function public.admin_set_lesson_package_product_config(uuid,integer,integer,public.entitlement_validity_unit,integer,public.lesson_booking_mode_eligibility,text) owner to postgres;
alter function public.get_own_lesson_entitlement_summaries() owner to postgres;
alter function public.get_teacher_student_lesson_entitlement_summaries(uuid) owner to postgres;
alter function public.get_admin_lesson_entitlement_summaries() owner to postgres;

revoke all on function private.reject_epic5_append_only_mutation(),
  private.protect_entitlement_authority_fields(),private.snapshot_order_item_fulfillment(),
  private.lesson_credit_balance(uuid),private.fulfill_order_paid_event(uuid,uuid)
from public,anon,authenticated,service_role;
revoke all on function public.process_order_fulfillment_event(uuid),
  public.admin_retry_order_fulfillment_event(uuid,text,text),
  public.reserve_lesson_credit(uuid,text,uuid,text),public.release_lesson_credit(uuid,text),
  public.consume_lesson_credit(uuid,uuid),
  public.extend_lesson_package_entitlement(uuid,timestamptz,text,text),
  public.admin_adjust_lesson_credits(uuid,integer,text,text),
  public.admin_revoke_entitlement(uuid,text,text),
  public.admin_set_lesson_package_product_config(uuid,integer,integer,public.entitlement_validity_unit,integer,public.lesson_booking_mode_eligibility,text),
  public.get_own_lesson_entitlement_summaries(),public.get_teacher_student_lesson_entitlement_summaries(uuid),
  public.get_admin_lesson_entitlement_summaries()
from public,anon,authenticated,service_role;

grant execute on function public.process_order_fulfillment_event(uuid) to service_role;
grant execute on function public.reserve_lesson_credit(uuid,text,uuid,text),
  public.admin_retry_order_fulfillment_event(uuid,text,text),
  public.release_lesson_credit(uuid,text),public.consume_lesson_credit(uuid,uuid),
  public.extend_lesson_package_entitlement(uuid,timestamptz,text,text),
  public.admin_adjust_lesson_credits(uuid,integer,text,text),
  public.admin_revoke_entitlement(uuid,text,text),
  public.admin_set_lesson_package_product_config(uuid,integer,integer,public.entitlement_validity_unit,integer,public.lesson_booking_mode_eligibility,text),
  public.get_own_lesson_entitlement_summaries(),public.get_teacher_student_lesson_entitlement_summaries(uuid),
  public.get_admin_lesson_entitlement_summaries()
to authenticated;

commit;
