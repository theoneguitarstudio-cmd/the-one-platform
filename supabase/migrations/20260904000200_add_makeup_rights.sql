begin;

create type public.makeup_right_status as enum (
  'available','reserved','used','expired','revoked'
);
create type public.makeup_right_source as enum (
  'teacher_cancellation','admin_compensation','teacher_absence','manual_correction'
);
create type public.makeup_right_operation_type as enum (
  'create','reserve','restore','consume','expire','revoke'
);

create table public.makeup_rights (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references auth.users(id) on delete restrict,
  origin_lesson_id uuid not null references public.lessons(id) on delete restrict,
  origin_teacher_user_id uuid not null references auth.users(id) on delete restrict,
  current_teacher_user_id uuid not null references auth.users(id) on delete restrict,
  origin_entitlement_id uuid references public.entitlements(id) on delete restrict,
  origin_reservation_id uuid references public.lesson_credit_reservations(id) on delete restrict,
  source public.makeup_right_source not null,
  source_operation_key text not null unique
    check(char_length(source_operation_key) between 16 and 160),
  status public.makeup_right_status not null default 'available',
  valid_until timestamptz not null,
  reason text not null check(char_length(reason) between 3 and 1000),
  created_by uuid not null references auth.users(id) on delete restrict,
  reserved_at timestamptz,
  reserved_by uuid references auth.users(id) on delete restrict,
  used_at timestamptz,
  used_by uuid references auth.users(id) on delete restrict,
  expired_at timestamptz,
  expired_by uuid references auth.users(id) on delete restrict,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete restrict,
  revoked_reason text check(revoked_reason is null or char_length(revoked_reason) between 3 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint makeup_rights_origin_source_unique unique(origin_lesson_id,source),
  constraint makeup_rights_distinct_parties check(student_user_id<>origin_teacher_user_id),
  constraint makeup_rights_validity check(valid_until>created_at),
  constraint makeup_rights_status_shape check(
    (status='available' and reserved_at is null and reserved_by is null
      and used_at is null and used_by is null and expired_at is null and expired_by is null
      and revoked_at is null and revoked_by is null and revoked_reason is null)
    or (status='reserved' and reserved_at is not null and reserved_by is not null
      and used_at is null and used_by is null and expired_at is null and expired_by is null
      and revoked_at is null and revoked_by is null and revoked_reason is null)
    or (status='used' and reserved_at is not null and reserved_by is not null
      and used_at is not null and used_by is not null and expired_at is null and expired_by is null
      and revoked_at is null and revoked_by is null and revoked_reason is null)
    or (status='expired' and used_at is null and used_by is null
      and expired_at is not null and expired_by is not null
      and revoked_at is null and revoked_by is null and revoked_reason is null)
    or (status='revoked' and used_at is null and used_by is null
      and expired_at is null and expired_by is null
      and revoked_at is not null and revoked_by is not null and revoked_reason is not null)
  )
);

create table public.makeup_right_operations (
  id uuid primary key default gen_random_uuid(),
  makeup_right_id uuid not null references public.makeup_rights(id) on delete restrict,
  operation_type public.makeup_right_operation_type not null,
  operation_key text not null check(char_length(operation_key) between 16 and 160),
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  reason text not null check(char_length(reason) between 3 and 1000),
  from_status public.makeup_right_status,
  to_status public.makeup_right_status not null,
  before_snapshot jsonb not null default '{}'::jsonb check(jsonb_typeof(before_snapshot)='object'),
  after_snapshot jsonb not null check(jsonb_typeof(after_snapshot)='object'),
  audit_log_id uuid not null unique references public.audit_logs(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique(makeup_right_id,operation_key)
);

create index makeup_rights_student_status_idx
  on public.makeup_rights(student_user_id,status,valid_until);
create index makeup_rights_current_teacher_idx
  on public.makeup_rights(current_teacher_user_id,status,valid_until);
create index makeup_rights_origin_teacher_idx
  on public.makeup_rights(origin_teacher_user_id,created_at);
create index makeup_right_operations_right_created_idx
  on public.makeup_right_operations(makeup_right_id,created_at);

comment on table public.makeup_rights is
  'First-class single-lesson compensation value. It is independent from ordinary entitlement credit balances.';
comment on table public.makeup_right_operations is
  'Append-only idempotency and audit linkage for Makeup Right lifecycle mutations.';

create or replace function private.protect_makeup_right_identity()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if new.student_user_id is distinct from old.student_user_id
    or new.origin_lesson_id is distinct from old.origin_lesson_id
    or new.origin_teacher_user_id is distinct from old.origin_teacher_user_id
    or new.current_teacher_user_id is distinct from old.current_teacher_user_id
    or new.origin_entitlement_id is distinct from old.origin_entitlement_id
    or new.origin_reservation_id is distinct from old.origin_reservation_id
    or new.source is distinct from old.source
    or new.source_operation_key is distinct from old.source_operation_key
    or new.valid_until is distinct from old.valid_until
    or new.reason is distinct from old.reason
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at then
    raise exception using errcode='55000',message='MAKEUP_RIGHT_IDENTITY_IMMUTABLE';
  end if;
  return new;
end;
$$;

create or replace function private.reject_makeup_right_operation_mutation()
returns trigger language plpgsql security definer set search_path=''
as $$ begin
  raise exception using errcode='55000',message='APPEND_ONLY_HISTORY';
end; $$;

create trigger protect_makeup_right_identity_before_update
before update on public.makeup_rights for each row
execute function private.protect_makeup_right_identity();
create trigger reject_makeup_right_operation_update
before update or delete on public.makeup_right_operations for each row
execute function private.reject_makeup_right_operation_mutation();

create or replace function private.record_makeup_right_operation(
  p_right public.makeup_rights,p_operation_type public.makeup_right_operation_type,
  p_operation_key text,p_actor_user_id uuid,p_reason text,
  p_from_status public.makeup_right_status,p_before_snapshot jsonb
) returns uuid language plpgsql security definer set search_path=''
as $$
declare audit_id uuid; operation_id uuid;
begin
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(
    p_actor_user_id,'makeup_right.'||p_operation_type::text,'makeup_right',p_right.id,
    coalesce(p_before_snapshot,'{}'::jsonb),to_jsonb(p_right),trim(p_reason)
  ) returning id into audit_id;
  insert into public.makeup_right_operations(
    makeup_right_id,operation_type,operation_key,actor_user_id,reason,
    from_status,to_status,before_snapshot,after_snapshot,audit_log_id
  ) values(
    p_right.id,p_operation_type,p_operation_key,p_actor_user_id,trim(p_reason),
    p_from_status,p_right.status,coalesce(p_before_snapshot,'{}'::jsonb),to_jsonb(p_right),audit_id
  ) returning id into operation_id;
  return operation_id;
end;
$$;

create or replace function private.create_makeup_right_core(
  p_student_user_id uuid,p_origin_lesson_id uuid,p_origin_teacher_user_id uuid,
  p_current_teacher_user_id uuid,p_valid_until timestamptz,p_source public.makeup_right_source,
  p_operation_key text,p_reason text,p_actor_user_id uuid,
  p_origin_entitlement_id uuid default null,p_origin_reservation_id uuid default null
) returns uuid language plpgsql security definer set search_path=''
as $$
declare lesson public.lessons%rowtype; existing public.makeup_rights%rowtype;
  created public.makeup_rights%rowtype; scoped_teacher uuid:=coalesce(p_current_teacher_user_id,p_origin_teacher_user_id);
begin
  if p_actor_user_id is null or char_length(coalesce(p_operation_key,'')) not between 16 and 160
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or p_valid_until<=now() then
    raise exception using errcode='22023',message='INVALID_MAKEUP_RIGHT';
  end if;
  select * into lesson from public.lessons where id=p_origin_lesson_id;
  if not found or lesson.student_user_id<>p_student_user_id
    or lesson.teacher_user_id<>p_origin_teacher_user_id then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_ORIGIN_MISMATCH';
  end if;
  if p_actor_user_id<>p_origin_teacher_user_id
    and not exists(select 1 from public.user_roles r join public.profiles p on p.user_id=r.user_id
      where r.user_id=p_actor_user_id and r.role in('admin','super_admin') and p.account_status='active') then
    raise exception using errcode='42501',message='UNAUTHORIZED_MAKEUP_ACTION';
  end if;
  if p_actor_user_id=p_origin_teacher_user_id
    and not private.scheduling_teacher_authorized(p_origin_teacher_user_id) then
    raise exception using errcode='42501',message='UNAUTHORIZED_MAKEUP_ACTION';
  end if;
  if not exists(select 1 from public.teacher_profiles t join public.user_roles r on r.user_id=t.user_id
    where t.user_id=scoped_teacher and t.teaching_status='active' and r.role='teacher') then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_TEACHER_SCOPE_INVALID';
  end if;
  if p_origin_entitlement_id is not null and not exists(select 1 from public.entitlements e
    where e.id=p_origin_entitlement_id and e.beneficiary_user_id=p_student_user_id) then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_ORIGIN_MISMATCH';
  end if;
  if p_origin_reservation_id is not null and not exists(
    select 1 from public.lesson_credit_reservations r
    where r.id=p_origin_reservation_id and r.beneficiary_user_id=p_student_user_id
      and r.lesson_id=p_origin_lesson_id
      and (p_origin_entitlement_id is null or r.entitlement_id=p_origin_entitlement_id)
  ) then raise exception using errcode='P0001',message='MAKEUP_RIGHT_ORIGIN_MISMATCH'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'the-one:v1:makeup:create:'||p_origin_lesson_id::text||':'||p_source::text,7));
  select * into existing from public.makeup_rights
    where origin_lesson_id=p_origin_lesson_id and source=p_source;
  if found then
    if existing.source_operation_key=p_operation_key
      and existing.student_user_id=p_student_user_id
      and existing.origin_teacher_user_id=p_origin_teacher_user_id
      and existing.current_teacher_user_id=scoped_teacher
      and existing.valid_until=p_valid_until
      and existing.reason=trim(p_reason)
      and existing.origin_entitlement_id is not distinct from p_origin_entitlement_id
      and existing.origin_reservation_id is not distinct from p_origin_reservation_id then
      return existing.id;
    end if;
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_ALREADY_EXISTS';
  end if;
  insert into public.makeup_rights(
    student_user_id,origin_lesson_id,origin_teacher_user_id,current_teacher_user_id,
    origin_entitlement_id,origin_reservation_id,source,source_operation_key,
    valid_until,reason,created_by
  ) values(
    p_student_user_id,p_origin_lesson_id,p_origin_teacher_user_id,scoped_teacher,
    p_origin_entitlement_id,p_origin_reservation_id,p_source,p_operation_key,
    p_valid_until,trim(p_reason),p_actor_user_id
  ) returning * into created;
  perform private.record_makeup_right_operation(created,'create',p_operation_key,
    p_actor_user_id,p_reason,null,'{}'::jsonb);
  return created.id;
end;
$$;

create or replace function private.makeup_status_transition_allowed(
  p_from public.makeup_right_status,p_to public.makeup_right_status
) returns boolean language sql immutable security definer set search_path=''
as $$
  select case
    when p_from='available' and p_to in('reserved','expired','revoked') then true
    when p_from='reserved' and p_to in('available','used','expired','revoked') then true
    else false
  end;
$$;

create or replace function private.makeup_actor_can_manage(
  p_right public.makeup_rights,p_actor_user_id uuid,p_allow_student boolean
) returns boolean language sql stable security definer set search_path=''
as $$
  select p_actor_user_id is not null and private.current_user_is_active()
    and (private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
      or (p_allow_student and p_actor_user_id=p_right.student_user_id)
      or (p_actor_user_id=p_right.current_teacher_user_id
        and private.scheduling_teacher_authorized(p_right.current_teacher_user_id)));
$$;

create or replace function public.reserve_makeup_right(
  p_makeup_right_id uuid,p_student_user_id uuid,p_teacher_user_id uuid,
  p_operation_key text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); before_right public.makeup_rights%rowtype;
  changed public.makeup_rights%rowtype; prior public.makeup_right_operations%rowtype;
begin
  if char_length(coalesce(p_operation_key,'')) not between 16 and 160
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_MAKEUP_OPERATION';
  end if;
  select * into before_right from public.makeup_rights where id=p_makeup_right_id for update;
  if not found or not private.makeup_actor_can_manage(before_right,caller,true)
    or before_right.student_user_id<>p_student_user_id
    or before_right.current_teacher_user_id<>p_teacher_user_id then
    raise exception using errcode='42501',message='UNAUTHORIZED_MAKEUP_ACTION';
  end if;
  select * into prior from public.makeup_right_operations
    where makeup_right_id=p_makeup_right_id and operation_key=p_operation_key;
  if found then
    if prior.operation_type='reserve' then return p_makeup_right_id; end if;
    raise exception using errcode='P0001',message='MAKEUP_OPERATION_KEY_CONFLICT';
  end if;
  if before_right.valid_until<=now() or before_right.status='expired' then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_EXPIRED';
  end if;
  if not private.makeup_status_transition_allowed(before_right.status,'reserved') then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_AVAILABLE';
  end if;
  update public.makeup_rights set status='reserved',reserved_at=now(),reserved_by=caller,updated_at=now()
    where id=p_makeup_right_id returning * into changed;
  perform private.record_makeup_right_operation(changed,'reserve',p_operation_key,caller,p_reason,
    before_right.status,to_jsonb(before_right));
  return changed.id;
end;
$$;

create or replace function public.restore_makeup_right(
  p_makeup_right_id uuid,p_operation_key text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); before_right public.makeup_rights%rowtype;
  changed public.makeup_rights%rowtype; prior public.makeup_right_operations%rowtype;
begin
  if char_length(coalesce(p_operation_key,'')) not between 16 and 160
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_MAKEUP_OPERATION'; end if;
  select * into before_right from public.makeup_rights where id=p_makeup_right_id for update;
  if not found or not private.makeup_actor_can_manage(before_right,caller,true) then
    raise exception using errcode='42501',message='UNAUTHORIZED_MAKEUP_ACTION'; end if;
  select * into prior from public.makeup_right_operations
    where makeup_right_id=p_makeup_right_id and operation_key=p_operation_key;
  if found then
    if prior.operation_type='restore' then return p_makeup_right_id; end if;
    raise exception using errcode='P0001',message='MAKEUP_OPERATION_KEY_CONFLICT'; end if;
  if before_right.status<>'reserved' then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_RESERVED'; end if;
  if before_right.valid_until<=now() then
    if not private.makeup_status_transition_allowed(before_right.status,'expired') then
      raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_RESERVED'; end if;
    update public.makeup_rights set status='expired',reserved_at=null,reserved_by=null,
      expired_at=now(),expired_by=caller,updated_at=now()
      where id=p_makeup_right_id returning * into changed;
  else
    if not private.makeup_status_transition_allowed(before_right.status,'available') then
      raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_RESERVED'; end if;
    update public.makeup_rights set status='available',reserved_at=null,reserved_by=null,updated_at=now()
      where id=p_makeup_right_id returning * into changed;
  end if;
  perform private.record_makeup_right_operation(changed,'restore',p_operation_key,caller,p_reason,
    before_right.status,to_jsonb(before_right));
  return changed.id;
end;
$$;

create or replace function public.consume_makeup_right(
  p_makeup_right_id uuid,p_operation_key text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); before_right public.makeup_rights%rowtype;
  changed public.makeup_rights%rowtype; prior public.makeup_right_operations%rowtype;
begin
  if char_length(coalesce(p_operation_key,'')) not between 16 and 160
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_MAKEUP_OPERATION'; end if;
  select * into before_right from public.makeup_rights where id=p_makeup_right_id for update;
  if not found or not private.makeup_actor_can_manage(before_right,caller,false) then
    raise exception using errcode='42501',message='UNAUTHORIZED_MAKEUP_ACTION'; end if;
  select * into prior from public.makeup_right_operations
    where makeup_right_id=p_makeup_right_id and operation_key=p_operation_key;
  if found then
    if prior.operation_type='consume' then return p_makeup_right_id; end if;
    raise exception using errcode='P0001',message='MAKEUP_OPERATION_KEY_CONFLICT'; end if;
  if before_right.valid_until<=now() or before_right.status='expired' then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_EXPIRED'; end if;
  if not private.makeup_status_transition_allowed(before_right.status,'used') then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_RESERVED'; end if;
  update public.makeup_rights set status='used',used_at=now(),used_by=caller,updated_at=now()
    where id=p_makeup_right_id returning * into changed;
  perform private.record_makeup_right_operation(changed,'consume',p_operation_key,caller,p_reason,
    before_right.status,to_jsonb(before_right));
  return changed.id;
end;
$$;

create or replace function public.expire_makeup_right(
  p_makeup_right_id uuid,p_operation_key text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); before_right public.makeup_rights%rowtype;
  changed public.makeup_rights%rowtype; prior public.makeup_right_operations%rowtype;
begin
  if char_length(coalesce(p_operation_key,'')) not between 16 and 160
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_MAKEUP_OPERATION'; end if;
  select * into before_right from public.makeup_rights where id=p_makeup_right_id for update;
  if not found or not private.makeup_actor_can_manage(before_right,caller,true) then
    raise exception using errcode='42501',message='UNAUTHORIZED_MAKEUP_ACTION'; end if;
  select * into prior from public.makeup_right_operations
    where makeup_right_id=p_makeup_right_id and operation_key=p_operation_key;
  if found then
    if prior.operation_type='expire' then return p_makeup_right_id; end if;
    raise exception using errcode='P0001',message='MAKEUP_OPERATION_KEY_CONFLICT'; end if;
  if before_right.status='expired' then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_ALREADY_EXPIRED'; end if;
  if before_right.valid_until>now() then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_EXPIRED'; end if;
  if not private.makeup_status_transition_allowed(before_right.status,'expired') then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_TERMINAL'; end if;
  update public.makeup_rights set status='expired',reserved_at=null,reserved_by=null,
    expired_at=now(),expired_by=caller,updated_at=now()
    where id=p_makeup_right_id returning * into changed;
  perform private.record_makeup_right_operation(changed,'expire',p_operation_key,caller,p_reason,
    before_right.status,to_jsonb(before_right));
  return changed.id;
end;
$$;

create or replace function public.revoke_makeup_right(
  p_makeup_right_id uuid,p_operation_key text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); before_right public.makeup_rights%rowtype;
  changed public.makeup_rights%rowtype; prior public.makeup_right_operations%rowtype;
begin
  if caller is null or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role]) then
    raise exception using errcode='42501',message='UNAUTHORIZED_MAKEUP_ACTION'; end if;
  if char_length(coalesce(p_operation_key,'')) not between 16 and 160
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_MAKEUP_OPERATION'; end if;
  select * into before_right from public.makeup_rights where id=p_makeup_right_id for update;
  if not found then raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_FOUND'; end if;
  select * into prior from public.makeup_right_operations
    where makeup_right_id=p_makeup_right_id and operation_key=p_operation_key;
  if found then
    if prior.operation_type='revoke' then return p_makeup_right_id; end if;
    raise exception using errcode='P0001',message='MAKEUP_OPERATION_KEY_CONFLICT'; end if;
  if before_right.status='revoked' then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_ALREADY_REVOKED'; end if;
  if not private.makeup_status_transition_allowed(before_right.status,'revoked') then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_TERMINAL'; end if;
  update public.makeup_rights set status='revoked',reserved_at=null,reserved_by=null,
    revoked_at=now(),revoked_by=caller,revoked_reason=trim(p_reason),updated_at=now()
    where id=p_makeup_right_id returning * into changed;
  perform private.record_makeup_right_operation(changed,'revoke',p_operation_key,caller,p_reason,
    before_right.status,to_jsonb(before_right));
  return changed.id;
end;
$$;

alter table public.makeup_rights enable row level security;
alter table public.makeup_right_operations enable row level security;

create policy makeup_rights_participant_select on public.makeup_rights
for select to authenticated using(
  private.current_user_is_active() and (
    student_user_id=auth.uid()
    or current_teacher_user_id=auth.uid()
    or origin_teacher_user_id=auth.uid()
    or private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
  )
);

revoke all on public.makeup_rights,public.makeup_right_operations from anon,authenticated,service_role;
grant select on public.makeup_rights to authenticated;

revoke all on function private.protect_makeup_right_identity() from public,anon,authenticated,service_role;
revoke all on function private.reject_makeup_right_operation_mutation() from public,anon,authenticated,service_role;
revoke all on function private.record_makeup_right_operation(
  public.makeup_rights,public.makeup_right_operation_type,text,uuid,text,
  public.makeup_right_status,jsonb
) from public,anon,authenticated,service_role;
revoke all on function private.create_makeup_right_core(
  uuid,uuid,uuid,uuid,timestamptz,public.makeup_right_source,text,text,uuid,uuid,uuid
) from public,anon,authenticated,service_role;
revoke all on function private.makeup_status_transition_allowed(
  public.makeup_right_status,public.makeup_right_status
) from public,anon,authenticated,service_role;
revoke all on function private.makeup_actor_can_manage(public.makeup_rights,uuid,boolean)
  from public,anon,authenticated,service_role;

revoke all on function public.reserve_makeup_right(uuid,uuid,uuid,text,text) from public,anon,service_role;
revoke all on function public.restore_makeup_right(uuid,text,text) from public,anon,service_role;
revoke all on function public.consume_makeup_right(uuid,text,text) from public,anon,service_role;
revoke all on function public.expire_makeup_right(uuid,text,text) from public,anon,service_role;
revoke all on function public.revoke_makeup_right(uuid,text,text) from public,anon,service_role;
grant execute on function public.reserve_makeup_right(uuid,uuid,uuid,text,text) to authenticated;
grant execute on function public.restore_makeup_right(uuid,text,text) to authenticated;
grant execute on function public.consume_makeup_right(uuid,text,text) to authenticated;
grant execute on function public.expire_makeup_right(uuid,text,text) to authenticated;
grant execute on function public.revoke_makeup_right(uuid,text,text) to authenticated;

alter function private.protect_makeup_right_identity() owner to postgres;
alter function private.reject_makeup_right_operation_mutation() owner to postgres;
alter function private.record_makeup_right_operation(
  public.makeup_rights,public.makeup_right_operation_type,text,uuid,text,
  public.makeup_right_status,jsonb
) owner to postgres;
alter function private.create_makeup_right_core(
  uuid,uuid,uuid,uuid,timestamptz,public.makeup_right_source,text,text,uuid,uuid,uuid
) owner to postgres;
alter function private.makeup_status_transition_allowed(
  public.makeup_right_status,public.makeup_right_status
) owner to postgres;
alter function private.makeup_actor_can_manage(public.makeup_rights,uuid,boolean) owner to postgres;
alter function public.reserve_makeup_right(uuid,uuid,uuid,text,text) owner to postgres;
alter function public.restore_makeup_right(uuid,text,text) owner to postgres;
alter function public.consume_makeup_right(uuid,text,text) owner to postgres;
alter function public.expire_makeup_right(uuid,text,text) owner to postgres;
alter function public.revoke_makeup_right(uuid,text,text) owner to postgres;

commit;
