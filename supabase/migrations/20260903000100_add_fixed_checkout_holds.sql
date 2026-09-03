begin;

-- Opt-in product policy; no implicit business TTL. Each claim snapshots it.
alter table public.lesson_package_product_configs add column fixed_checkout_hold_seconds integer
  check (fixed_checkout_hold_seconds > 0);

create type public.fixed_checkout_hold_status as enum ('active','expired','released','converted');
create table public.fixed_checkout_holds (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references auth.users(id),
  teacher_user_id uuid not null references auth.users(id),
  relationship_id uuid not null,
  product_id uuid not null references public.products(id),
  order_id uuid not null unique references public.orders(id),
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 140),
  weekday smallint not null check (weekday between 0 and 6),
  local_start_time time not null,
  timezone text not null,
  duration_minutes smallint not null check (duration_minutes between 1 and 480),
  effective_from date not null check (isfinite(effective_from)),
  effective_until date check (isfinite(effective_until) and effective_until>=effective_from),
  first_starts_at timestamptz not null,
  first_ends_at timestamptz not null,
  status public.fixed_checkout_hold_status not null default 'active',
  hold_seconds integer not null check (hold_seconds>0),
  created_at timestamptz not null,
  expires_at timestamptz not null,
  closed_at timestamptz,
  closed_by uuid references auth.users(id),
  close_reason text,
  series_id uuid unique references public.recurring_lesson_series(id),
  cycle_id uuid unique references public.fixed_entitlement_cycles(id),
  source_fulfillment_event_id uuid references public.order_fulfillment_events(id),
  unique(student_user_id,idempotency_key),
  foreign key(relationship_id,student_user_id,teacher_user_id)
    references public.student_teacher_relationships(id,student_user_id,teacher_user_id),
  check (expires_at>created_at and first_ends_at>first_starts_at),
  check ((status='active' and closed_at is null) or (status<>'active' and closed_at is not null)),
  check ((status='converted' and series_id is not null and cycle_id is not null and source_fulfillment_event_id is not null)
    or (status<>'converted' and series_id is null and cycle_id is null and source_fulfillment_event_id is null)),
  -- Backstop for identical first instances. Weekly/DST conflicts use the same
  -- participant locks and UTC resolver as Fixed ownership. The lease range
  -- allows an expired row to remain active without any cleanup job.
  exclude using gist (teacher_user_id with =,
    tstzrange(first_starts_at,first_ends_at,'[)') with &&,
    tstzrange(created_at,expires_at,'[)') with &&) where (status='active'),
  exclude using gist (student_user_id with =,
    tstzrange(first_starts_at,first_ends_at,'[)') with &&,
    tstzrange(created_at,expires_at,'[)') with &&) where (status='active')
);
create index fixed_checkout_holds_teacher_idx on public.fixed_checkout_holds(teacher_user_id,expires_at) where status='active';
create index fixed_checkout_holds_student_idx on public.fixed_checkout_holds(student_user_id,expires_at) where status='active';

create function public.set_fixed_checkout_hold_policy(p_product_id uuid,p_hold_seconds integer,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not private.current_user_has_role(array['admin','super_admin']::public.app_role[]) then
    raise exception using errcode='42501',message='UNAUTHORIZED_HOLD_ACTION';
  end if;
  if p_hold_seconds is null or p_hold_seconds<=0 or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_HOLD_POLICY';
  end if;
  update public.lesson_package_product_configs set fixed_checkout_hold_seconds=p_hold_seconds where product_id=p_product_id;
  if not found then raise exception using errcode='22023',message='INVALID_HOLD_PRODUCT'; end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(auth.uid(),'fixed_checkout_hold.policy_changed','product',p_product_id,
    jsonb_build_object('hold_seconds',p_hold_seconds),trim(p_reason));
end;
$$;

-- Target-interval check uses the P1-3 resolver, local date bounds and half-open
-- UTC intervals, including the preceding local date for midnight crossings.
create function private.fixed_checkout_hold_slot_clear(
  p_student_user_id uuid,p_teacher_user_id uuid,p_starts_at timestamptz,p_ends_at timestamptz
) returns boolean language plpgsql stable security definer set search_path='' as $$
declare h public.fixed_checkout_holds%rowtype; d date; instant timestamptz;
begin
  for h in select * from public.fixed_checkout_holds where status='active' and expires_at>clock_timestamp()
    and (student_user_id=p_student_user_id or teacher_user_id=p_teacher_user_id)
  loop
    for d in select day::date from generate_series(
      greatest(h.effective_from,(p_starts_at at time zone h.timezone)::date-1),
      least(coalesce(h.effective_until,'infinity'::date),(p_ends_at at time zone h.timezone)::date),interval '1 day') day
      where extract(dow from day)::smallint=h.weekday
    loop
      begin
        instant:=private.resolve_scheduling_local_datetime(d,h.local_start_time,h.timezone);
      exception when sqlstate 'P0001' then
        if sqlerrm in('AMBIGUOUS_LOCAL_TIME','NONEXISTENT_LOCAL_TIME') then continue; else raise; end if;
      end;
      if tstzrange(instant,instant+make_interval(mins=>h.duration_minutes),'[)')&&tstzrange(p_starts_at,p_ends_at,'[)') then return false; end if;
    end loop;
  end loop;
  return true;
end;
$$;

-- Preserve the previous implementations intact; all existing callers retain
-- their names and now also honor live checkout holds (including fresh expand).
alter function private.scheduling_instance_slot_clear(uuid,uuid,timestamptz,timestamptz,uuid,uuid)
  rename to scheduling_instance_without_checkout_hold_clear;
create function private.scheduling_instance_slot_clear(
  p_student_user_id uuid,p_teacher_user_id uuid,p_starts_at timestamptz,p_ends_at timestamptz,
  p_ignore_lesson_id uuid default null,p_ignore_occurrence_id uuid default null
) returns boolean language sql stable security definer set search_path='' as $$
  select private.scheduling_instance_without_checkout_hold_clear($1,$2,$3,$4,$5,$6)
    and private.fixed_checkout_hold_slot_clear($1,$2,$3,$4);
$$;

alter function private.recurring_ownership_clear(uuid,uuid,smallint,time,text,smallint,date,date)
  rename to recurring_series_ownership_clear;
create function private.recurring_ownership_clear(
  p_student_user_id uuid,p_teacher_user_id uuid,p_weekday smallint,p_local_start_time time,
  p_timezone text,p_duration_minutes smallint,p_effective_from date,p_effective_until date
) returns boolean language plpgsql stable security definer set search_path='' as $$
declare h record; lower_date date; upper_date date; d date; instant timestamptz;
begin
  if not private.recurring_series_ownership_clear($1,$2,$3,$4,$5,$6,$7,$8) then return false; end if;
  -- Same bounded 366-day effective intersection as P1-3C. Target-interval
  -- checks continue to protect later expansion and bookings as time advances.
  for h in select * from public.fixed_checkout_holds where status='active' and expires_at>clock_timestamp()
    and (student_user_id=p_student_user_id or teacher_user_id=p_teacher_user_id)
  loop
    lower_date:=greatest(p_effective_from,current_date,
      ((h.effective_from::timestamp at time zone h.timezone) at time zone p_timezone)::date-1);
    upper_date:=least(coalesce(p_effective_until,'infinity'::date),lower_date+366);
    if h.effective_until is not null then
      upper_date:=least(upper_date,(((h.effective_until+1)::timestamp at time zone h.timezone) at time zone p_timezone)::date);
    end if;
    for d in select lower_date+i from generate_series(0,upper_date-lower_date) i where extract(dow from lower_date+i)::smallint=p_weekday
    loop
      begin
        instant:=private.resolve_scheduling_local_datetime(d,p_local_start_time,p_timezone);
      exception when sqlstate 'P0001' then
        if sqlerrm in('AMBIGUOUS_LOCAL_TIME','NONEXISTENT_LOCAL_TIME') then continue; else raise; end if;
      end;
      if not private.fixed_checkout_hold_slot_clear(p_student_user_id,p_teacher_user_id,instant,
        instant+make_interval(mins=>p_duration_minutes)) then return false; end if;
    end loop;
  end loop;
  return true;
end;
$$;

-- Validate every purchasable occurrence inside the teacher's current horizon.
-- Slot timezone may differ from the teacher's availability timezone: compare
-- resolved UTC instants through the existing availability authority.
create function private.validate_fixed_checkout_slot(
  p_student uuid,p_teacher uuid,p_relationship uuid,p_weekday smallint,p_time time,p_timezone text,
  p_duration smallint,p_from date,p_until date
) returns timestamptz language plpgsql security definer set search_path='' as $$
declare settings public.teacher_scheduling_settings%rowtype; d date; first_instant timestamptz; instant timestamptz;
begin
  if not exists(select 1 from public.profiles where user_id=p_student and account_status='active')
    or not exists(select 1 from public.user_roles where user_id=p_student and role='student')
    or not private.teacher_owner_is_active(p_teacher)
    or not private.scheduling_relationship_is_active(p_relationship,p_student,p_teacher) then
    raise exception using errcode='42501',message='UNAUTHORIZED_HOLD_ACTION';
  end if;
  select * into settings from public.teacher_scheduling_settings where teacher_user_id=p_teacher;
  if not found or p_weekday is null or p_weekday not between 0 and 6 or p_time is null
    or p_duration is null or p_duration not between 1 and 480 or p_from is null or not isfinite(p_from)
    or p_from<current_date or (p_until is not null and (not isfinite(p_until) or p_until<p_from))
    or not exists(select 1 from pg_timezone_names where name=p_timezone)
    or p_time+make_interval(mins=>p_duration)<=p_time then
    raise exception using errcode='22023',message='INVALID_HOLD_SLOT';
  end if;
  if not private.recurring_ownership_clear(p_student,p_teacher,p_weekday,p_time,p_timezone,p_duration,p_from,p_until) then
    raise exception using errcode='P0001',message='FIXED_SLOT_UNAVAILABLE';
  end if;
  for d in select p_from+i from generate_series(0,least(coalesce(p_until,'infinity'::date),current_date+settings.booking_horizon_days)-p_from) i
    where extract(dow from p_from+i)::smallint=p_weekday
  loop
    instant:=private.resolve_scheduling_local_datetime(d,p_time,p_timezone);
    if instant>now()+make_interval(days=>settings.booking_horizon_days) then continue; end if;
    if not private.flexible_slot_is_available(p_student,p_teacher,instant,p_duration::integer) then
      raise exception using errcode='P0001',message='FIXED_SLOT_UNAVAILABLE';
    end if;
    first_instant:=coalesce(first_instant,instant);
  end loop;
  if first_instant is null then raise exception using errcode='P0001',message='FIXED_SLOT_OUTSIDE_HORIZON'; end if;
  return first_instant;
end;
$$;

create function public.claim_fixed_checkout_hold(
  p_teacher_user_id uuid,p_relationship_id uuid,p_product_slug text,p_weekday smallint,
  p_local_start_time time,p_timezone text,p_effective_from date,p_effective_until date,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); h public.fixed_checkout_holds%rowtype; product public.products%rowtype;
  config public.lesson_package_product_configs%rowtype; instant timestamptz; claimed_at timestamptz; order_uuid uuid; result_id uuid;
begin
  if caller is null or not private.current_user_has_role(array['student']::public.app_role[]) then
    raise exception using errcode='42501',message='UNAUTHORIZED_HOLD_ACTION';
  end if;
  if char_length(coalesce(p_idempotency_key,'')) not between 16 and 140 then
    raise exception using errcode='22023',message='INVALID_HOLD_KEY';
  end if;
  perform private.lock_lesson_schedule_resources(caller,p_teacher_user_id);
  select * into h from public.fixed_checkout_holds where student_user_id=caller and idempotency_key=p_idempotency_key for update;
  if found then
    if (h.teacher_user_id,h.relationship_id,h.weekday,h.local_start_time,h.timezone,h.effective_from,h.effective_until)
      is distinct from (p_teacher_user_id,p_relationship_id,p_weekday,p_local_start_time,p_timezone,p_effective_from,p_effective_until)
      or not exists(select 1 from public.products where id=h.product_id and public_slug=p_product_slug) then
      raise exception using errcode='22023',message='HOLD_PAYLOAD_MISMATCH';
    end if;
    return h.id; -- Stable result even after expiry; retries never extend a lease.
  end if;
  select * into product from public.products where public_slug=p_product_slug for share;
  if not found or product.product_type<>'lesson_package'
    or (product.owner_type='teacher' and product.owner_teacher_user_id is distinct from p_teacher_user_id) then
    raise exception using errcode='22023',message='INVALID_HOLD_PRODUCT';
  end if;
  select * into config from public.lesson_package_product_configs where product_id=product.id for share;
  if not found or config.fixed_checkout_hold_seconds is null or config.booking_mode_eligibility not in('fixed','both') then
    raise exception using errcode='22023',message='HOLD_POLICY_UNAVAILABLE';
  end if;
  instant:=private.validate_fixed_checkout_slot(caller,p_teacher_user_id,p_relationship_id,p_weekday,
    p_local_start_time,p_timezone,config.lesson_duration_minutes::smallint,p_effective_from,p_effective_until);
  order_uuid:=public.create_checkout_order(p_product_slug,1,'fixed-hold:'||p_idempotency_key);
  if not exists(select 1 from public.orders where id=order_uuid and buyer_user_id=caller and status='awaiting_payment'
    and payment_status='unpaid' and expires_at>clock_timestamp()) then
    raise exception using errcode='P0001',message='HOLD_CHECKOUT_UNAVAILABLE';
  end if;
  if not exists(select 1 from public.order_items i join public.order_item_fulfillment_snapshots s on s.order_item_id=i.id
    where i.order_id=order_uuid and i.product_id=product.id and i.quantity=1
      and s.lesson_duration_minutes=config.lesson_duration_minutes and s.booking_mode_eligibility in('fixed','both')
      and (s.teacher_scope_user_id is null or s.teacher_scope_user_id=p_teacher_user_id)) then
    raise exception using errcode='P0001',message='HOLD_CHECKOUT_UNAVAILABLE';
  end if;
  claimed_at:=clock_timestamp();
  insert into public.fixed_checkout_holds(student_user_id,teacher_user_id,relationship_id,product_id,order_id,idempotency_key,
    weekday,local_start_time,timezone,duration_minutes,effective_from,effective_until,first_starts_at,first_ends_at,
    hold_seconds,created_at,expires_at)
  values(caller,p_teacher_user_id,p_relationship_id,product.id,order_uuid,p_idempotency_key,p_weekday,p_local_start_time,
    p_timezone,config.lesson_duration_minutes,p_effective_from,p_effective_until,instant,
    instant+make_interval(mins=>config.lesson_duration_minutes),config.fixed_checkout_hold_seconds,
    claimed_at,claimed_at+make_interval(secs=>config.fixed_checkout_hold_seconds)) returning id into result_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
    select caller,'fixed_checkout_hold.claimed','fixed_checkout_hold',id,to_jsonb(held),'Student checkout'
    from public.fixed_checkout_holds held where id=result_id;
  return result_id;
exception when exclusion_violation then raise exception using errcode='P0001',message='FIXED_SLOT_UNAVAILABLE';
end;
$$;

create function public.release_fixed_checkout_hold(p_hold_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare h public.fixed_checkout_holds%rowtype; actor uuid:=auth.uid();
begin
  select * into h from public.fixed_checkout_holds where id=p_hold_id;
  if not found or (auth.role() is distinct from 'service_role' and
    (not private.current_user_is_active() or actor is null or (actor<>h.student_user_id
      and not private.current_user_has_role(array['admin','super_admin']::public.app_role[])))) then
    raise exception using errcode='42501',message='UNAUTHORIZED_HOLD_ACTION';
  end if;
  if auth.role()='service_role' then actor:=null; end if;
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_HOLD_REASON';
  end if;
  perform private.lock_lesson_schedule_resources(h.student_user_id,h.teacher_user_id);
  select * into h from public.fixed_checkout_holds where id=p_hold_id for update;
  if h.status<>'active' then return h.id; end if;
  update public.fixed_checkout_holds set status=case when expires_at<=clock_timestamp() then 'expired'::public.fixed_checkout_hold_status
    else 'released'::public.fixed_checkout_hold_status end,closed_at=clock_timestamp(),closed_by=actor,close_reason=trim(p_reason) where id=h.id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
    select actor,'fixed_checkout_hold.released','fixed_checkout_hold',id,to_jsonb(held)||jsonb_build_object(
      'actor_role',case when auth.role()='service_role' then 'service_role' else private.scheduling_actor_role(actor)::text end),trim(p_reason)
    from public.fixed_checkout_holds held where id=h.id;
  return h.id;
end;
$$;

-- Called by the fulfillment worker after the existing Epic5 event processor.
-- Business rejection is a durable result, not a raised error that loses audit.
-- This operation never confirms payment, fulfills an order or allocates credit.
create function public.convert_fixed_checkout_hold(p_hold_id uuid,p_entitlement_id uuid,p_fulfillment_event_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare h public.fixed_checkout_holds%rowtype; actor uuid:=auth.uid(); actor_role text;
  series_uuid uuid; cycle_uuid uuid; failure text;
begin
  if auth.role()='service_role' then actor:=null; actor_role:='service_role';
  elsif private.current_user_has_role(array['admin','super_admin']::public.app_role[]) then actor_role:=private.scheduling_actor_role(actor)::text;
  else raise exception using errcode='42501',message='UNAUTHORIZED_HOLD_ACTION'; end if;
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_HOLD_REASON';
  end if;
  select * into h from public.fixed_checkout_holds where id=p_hold_id;
  if not found then raise exception using errcode='22023',message='HOLD_NOT_FOUND'; end if;
  perform private.lock_lesson_schedule_resources(h.student_user_id,h.teacher_user_id);
  select * into h from public.fixed_checkout_holds where id=p_hold_id for update;
  if h.status='converted' then
    if h.source_fulfillment_event_id is distinct from p_fulfillment_event_id or not exists(
      select 1 from public.fixed_entitlement_cycles where id=h.cycle_id and entitlement_id=p_entitlement_id) then
      raise exception using errcode='22023',message='HOLD_PAYLOAD_MISMATCH';
    end if;
    return jsonb_build_object('status','converted','series_id',h.series_id,'cycle_id',h.cycle_id);
  end if;
  begin
    if h.status<>'active' or h.expires_at<=clock_timestamp() then
      raise exception using errcode='P0001',message='HOLD_NOT_ACTIVE';
    end if;
    -- Same event -> order -> entitlement lock order as Cycle 1 attachment.
    perform 1 from public.order_fulfillment_events where id=p_fulfillment_event_id and order_id=h.order_id
      and status='processed' and event_type='order.paid' for share;
    if not found then raise exception using errcode='P0001',message='HOLD_FULFILLMENT_REQUIRED'; end if;
    perform 1 from public.orders where id=h.order_id and buyer_user_id=h.student_user_id and status='paid' and payment_status='paid' for share;
    if not found then raise exception using errcode='P0001',message='HOLD_PAYMENT_REQUIRED'; end if;
    perform 1 from public.entitlements where id=p_entitlement_id and source_order_id=h.order_id
      and source_fulfillment_event_id=p_fulfillment_event_id and product_id=h.product_id
      and beneficiary_user_id=h.student_user_id and lesson_duration_minutes=h.duration_minutes for update;
    if not found then raise exception using errcode='P0001',message='HOLD_ENTITLEMENT_MISMATCH'; end if;
    -- Narrow exclusion of our own hold, inside a subtransaction. No caller GUC
    -- or public bypass flag. Any failed validation/attachment restores the row
    -- and rolls back the series, occurrences, cycle and their audits together.
    update public.fixed_checkout_holds set status='released',closed_at=clock_timestamp() where id=h.id;
    perform private.validate_fixed_checkout_slot(h.student_user_id,h.teacher_user_id,h.relationship_id,h.weekday,
      h.local_start_time,h.timezone,h.duration_minutes,h.effective_from,h.effective_until);
    -- Recheck expiry after potentially blocking payment/entitlement locks.
    if h.expires_at<=clock_timestamp() then raise exception using errcode='P0001',message='HOLD_NOT_ACTIVE'; end if;
    insert into public.recurring_lesson_series(student_user_id,teacher_user_id,relationship_id,preferred_entitlement_id,
      weekday,local_start_time,timezone,duration_minutes,effective_from,effective_until,created_by)
    values(h.student_user_id,h.teacher_user_id,h.relationship_id,p_entitlement_id,h.weekday,h.local_start_time,
      h.timezone,h.duration_minutes,h.effective_from,h.effective_until,coalesce(actor,h.student_user_id)) returning id into series_uuid;
    cycle_uuid:=private.attach_fixed_entitlement_cycle_core(series_uuid,p_entitlement_id,p_fulfillment_event_id,p_reason,actor,actor_role);
    -- Logical ownership is authoritative immediately; no future Lessons or
    -- speculative credit reservations are required for checkout conversion.
    update public.fixed_checkout_holds set status='converted',closed_at=clock_timestamp(),closed_by=actor,close_reason=trim(p_reason),
      series_id=series_uuid,cycle_id=cycle_uuid,source_fulfillment_event_id=p_fulfillment_event_id where id=h.id;
    insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
    values(actor,'recurring_series.created','recurring_lesson_series',series_uuid,
      jsonb_build_object('hold_id',h.id,'student_user_id',h.student_user_id,'teacher_user_id',h.teacher_user_id,'actor_role',actor_role),trim(p_reason));
    insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
      select actor,'fixed_checkout_hold.converted','fixed_checkout_hold',id,to_jsonb(held)||jsonb_build_object('actor_role',actor_role),trim(p_reason)
      from public.fixed_checkout_holds held where id=h.id;
    return jsonb_build_object('status','converted','series_id',series_uuid,'cycle_id',cycle_uuid);
  exception when sqlstate 'P0001' or sqlstate '42501' or sqlstate '22023' or exclusion_violation then
    failure:=sqlerrm;
  end;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(actor,'fixed_checkout_hold.conversion_failed','fixed_checkout_hold',h.id,to_jsonb(h)||jsonb_build_object(
    'requested_entitlement_id',p_entitlement_id,'requested_fulfillment_event_id',p_fulfillment_event_id,'error',failure,'actor_role',actor_role),trim(p_reason));
  return jsonb_build_object('status','rejected','error',failure,'hold_id',h.id);
end;
$$;

alter table public.fixed_checkout_holds enable row level security;
revoke all on public.fixed_checkout_holds from public,anon,authenticated,service_role;
grant select on public.fixed_checkout_holds to authenticated;
create policy fixed_checkout_holds_read on public.fixed_checkout_holds for select to authenticated using (
  private.current_user_is_active() and (student_user_id=auth.uid()
    or private.current_user_has_role(array['admin','super_admin']::public.app_role[]))
);

-- Explicit allowlists, including new wrapper functions after the renames.
do $$
declare f regprocedure;
begin
  for f in select oid::regprocedure from pg_proc where pronamespace='private'::regnamespace and proname in(
    'fixed_checkout_hold_slot_clear','scheduling_instance_slot_clear','recurring_ownership_clear','validate_fixed_checkout_slot',
    'scheduling_instance_without_checkout_hold_clear','recurring_series_ownership_clear')
  loop
    execute format('alter function %s owner to postgres',f);
    execute format('revoke all on function %s from public,anon,authenticated,service_role',f);
  end loop;
  for f in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname in(
    'set_fixed_checkout_hold_policy','claim_fixed_checkout_hold','release_fixed_checkout_hold','convert_fixed_checkout_hold')
  loop
    execute format('alter function %s owner to postgres',f);
    execute format('revoke all on function %s from public,anon,authenticated,service_role',f);
    execute format('grant execute on function %s to authenticated',f);
  end loop;
end;
$$;
grant execute on function public.release_fixed_checkout_hold(uuid,text),public.convert_fixed_checkout_hold(uuid,uuid,uuid,text) to service_role;

commit;
