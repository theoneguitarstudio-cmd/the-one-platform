begin;

create table public.entitlement_revoke_operations(
  operation_key text primary key
    check(char_length(operation_key) between 16 and 160),
  entitlement_id uuid not null references public.entitlements(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  request_payload jsonb not null check(jsonb_typeof(request_payload)='object'),
  status text not null default 'pending' check(status in('pending','completed')),
  result_payload jsonb check(result_payload is null or jsonb_typeof(result_payload)='object'),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  check(
    (status='pending' and result_payload is null and completed_at is null)
    or (status='completed' and result_payload is not null and completed_at is not null)
  )
);
create index entitlement_revoke_operations_entitlement_idx
  on public.entitlement_revoke_operations(entitlement_id,created_at);
comment on table public.entitlement_revoke_operations is
  'Immutable request identity and canonical result for Admin Entitlement revocation. Domain mutations and operation completion commit atomically.';

create function private.protect_entitlement_revoke_operation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then
    raise exception using errcode='55000',message='REVOKE_OPERATION_IMMUTABLE';
  end if;
  if (new.operation_key,new.entitlement_id,new.actor_user_id,new.request_payload,new.created_at)
    is distinct from
     (old.operation_key,old.entitlement_id,old.actor_user_id,old.request_payload,old.created_at)
    or old.status='completed'
    or old.status<>'pending'
    or new.status<>'completed'
    or new.result_payload is null
    or new.completed_at is null then
    raise exception using errcode='55000',message='REVOKE_OPERATION_IMMUTABLE';
  end if;
  return new;
end;
$$;
create trigger entitlement_revoke_operation_immutable
before update or delete on public.entitlement_revoke_operations
for each row execute function private.protect_entitlement_revoke_operation();

create function private.claim_entitlement_revoke_operation(
  p_operation_key text,
  p_entitlement_id uuid,
  p_actor_user_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  operation_row public.entitlement_revoke_operations%rowtype;
  payload jsonb:=jsonb_build_object(
    'actor_user_id',p_actor_user_id,
    'entitlement_id',p_entitlement_id,
    'reason',trim(p_reason)
  );
begin
  insert into public.entitlement_revoke_operations(
    operation_key,entitlement_id,actor_user_id,request_payload
  ) values(p_operation_key,p_entitlement_id,p_actor_user_id,payload)
  on conflict(operation_key) do nothing
  returning * into operation_row;

  if not found then
    select * into operation_row
    from public.entitlement_revoke_operations
    where operation_key=p_operation_key
    for update;
  end if;
  if operation_row.entitlement_id is distinct from p_entitlement_id
    or operation_row.actor_user_id is distinct from p_actor_user_id
    or operation_row.request_payload is distinct from payload then
    raise exception using errcode='P0001',message='REVOKE_REQUEST_MISMATCH';
  end if;
  return jsonb_build_object(
    'status',operation_row.status,
    'entitlement_id',operation_row.entitlement_id,
    'result',operation_row.result_payload
  );
end;
$$;

create function private.complete_entitlement_revoke_operation(
  p_operation_key text,
  p_entitlement_id uuid,
  p_result jsonb
) returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if p_result is null or jsonb_typeof(p_result)<>'object' then
    raise exception using errcode='22023',message='INVALID_REVOKE_OPERATION_RESULT';
  end if;
  update public.entitlement_revoke_operations
  set status='completed',result_payload=p_result,completed_at=clock_timestamp(),updated_at=now()
  where operation_key=p_operation_key and entitlement_id=p_entitlement_id
    and status='pending';
  if not found then
    raise exception using errcode='55000',message='REVOKE_OPERATION_STATE_INVALID';
  end if;
end;
$$;

create or replace function public.admin_revoke_entitlement(
  p_entitlement_id uuid,p_reason text,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path='' as $$
declare
  caller uuid:=auth.uid();
  ent public.entitlements%rowtype;
  operation_claim jsonb;
  fixed_reconciliation jsonb;
  booking_reconciliation jsonb;
  operation_result jsonb;
begin
  if caller is null or not private.current_user_has_role(array[
    'admin'::public.app_role,'super_admin'::public.app_role
  ]) then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or char_length(coalesce(p_idempotency_key,'')) not between 16 and 160 then
    raise exception using errcode='22023',message='INVALID_REVOCATION';
  end if;

  -- Preserve the transaction order established by P1-6A/C. The operation row
  -- follows the Entitlement identity lock and precedes its private domain work;
  -- no other domain entry point takes an operation row lock.
  select * into ent from public.entitlements
  where id=p_entitlement_id for update;
  if not found then
    raise exception using errcode='P0001',message='ENTITLEMENT_NOT_FOUND';
  end if;
  operation_claim:=private.claim_entitlement_revoke_operation(
    p_idempotency_key,ent.id,caller,trim(p_reason)
  );
  if operation_claim->>'status'='completed' then
    return (operation_claim->>'entitlement_id')::uuid;
  end if;

  fixed_reconciliation:=private.reconcile_fixed_cycles_on_entitlement_revoke(
    ent.id,caller,trim(p_reason)
  );
  if ent.status='revoked' then
    operation_result:=jsonb_build_object(
      'entitlement_id',ent.id,'status','revoked','already_revoked',true,
      'invalidated_cycle_count',fixed_reconciliation->'invalidated_cycle_count',
      'cleared_preferred_pointer_count',fixed_reconciliation->'cleared_preferred_pointer_count'
    );
    perform private.complete_entitlement_revoke_operation(
      p_idempotency_key,ent.id,operation_result
    );
    return ent.id;
  end if;

  booking_reconciliation:=private.reconcile_bookings_on_entitlement_revoke(
    ent.id,caller,trim(p_reason),p_idempotency_key
  );
  update public.entitlements
  set status='revoked',revoked_at=now(),revoked_by=caller,
    revoked_reason=trim(p_reason),updated_at=now()
  where id=ent.id;

  operation_result:=jsonb_build_object(
    'entitlement_id',ent.id,'status','revoked','already_revoked',false,
    'reconciled_booking_count',booking_reconciliation->'reconciled_booking_count',
    'invalidated_cycle_count',fixed_reconciliation->'invalidated_cycle_count',
    'cleared_preferred_pointer_count',fixed_reconciliation->'cleared_preferred_pointer_count'
  );
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(
    caller,'entitlement.revoked','entitlement',ent.id,
    jsonb_build_object(
      'status',ent.status,
      'available',booking_reconciliation->'available',
      'reserved',booking_reconciliation->'reserved'
    ),
    jsonb_build_object(
      'status','revoked','available',0,'reserved',0,
      'operation_key',p_idempotency_key,
      'reconciled_booking_count',booking_reconciliation->'reconciled_booking_count',
      'invalidated_cycle_count',fixed_reconciliation->'invalidated_cycle_count',
      'cleared_preferred_pointer_count',fixed_reconciliation->'cleared_preferred_pointer_count'
    ),trim(p_reason)
  );
  perform private.complete_entitlement_revoke_operation(
    p_idempotency_key,ent.id,operation_result
  );
  return ent.id;
end;
$$;

alter table public.entitlement_revoke_operations enable row level security;
revoke all on table public.entitlement_revoke_operations
  from public,anon,authenticated,service_role;

alter function private.protect_entitlement_revoke_operation() owner to postgres;
alter function private.claim_entitlement_revoke_operation(text,uuid,uuid,text) owner to postgres;
alter function private.complete_entitlement_revoke_operation(text,uuid,jsonb) owner to postgres;
alter function public.admin_revoke_entitlement(uuid,text,text) owner to postgres;

revoke all on function private.protect_entitlement_revoke_operation(),
  private.claim_entitlement_revoke_operation(text,uuid,uuid,text),
  private.complete_entitlement_revoke_operation(text,uuid,jsonb)
from public,anon,authenticated,service_role;
revoke all on function public.admin_revoke_entitlement(uuid,text,text)
from public,anon,authenticated,service_role;
grant execute on function public.admin_revoke_entitlement(uuid,text,text)
to authenticated;

comment on function private.claim_entitlement_revoke_operation(text,uuid,uuid,text) is
  'Claims one immutable revoke request identity after the caller locks its Entitlement. Same-key payload mismatch raises REVOKE_REQUEST_MISMATCH.';

commit;
