begin;

create or replace function private.reconcile_bookings_on_entitlement_revoke(
  p_entitlement_id uuid,
  p_actor_user_id uuid,
  p_reason text,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  affected_reservation_ids uuid[] := '{}'::uuid[];
  affected_booking_ids uuid[] := '{}'::uuid[];
  balance record;
  linked record;
  lesson_after public.lesson_status;
  reconciled_count integer := 0;
begin
  if p_entitlement_id is null or p_actor_user_id is null
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or char_length(coalesce(p_idempotency_key,'')) not between 16 and 160 then
    raise exception using errcode='22023',message='INVALID_REVOCATION_RECONCILIATION';
  end if;

  -- admin_revoke_entitlement owns the entitlement lock. Lock every affected
  -- value source before any Booking or Lesson, in stable UUID order.
  perform r.id
  from public.lesson_credit_reservations r
  where r.entitlement_id=p_entitlement_id and r.status='reserved'
  order by r.id
  for update;

  select coalesce(array_agg(r.id order by r.id),'{}'::uuid[])
  into affected_reservation_ids
  from public.lesson_credit_reservations r
  where r.entitlement_id=p_entitlement_id and r.status='reserved';

  perform b.id
  from public.bookings b
  where b.credit_reservation_id=any(affected_reservation_ids)
    and b.source in('flexible','fixed')
    and b.credit_reservation_id is not null
    and b.makeup_right_id is null
    and b.status in('confirmed','rescheduled')
  order by b.id
  for update;

  select coalesce(array_agg(b.id order by b.id),'{}'::uuid[])
  into affected_booking_ids
  from public.bookings b
  where b.credit_reservation_id=any(affected_reservation_ids)
    and b.source in('flexible','fixed')
    and b.credit_reservation_id is not null
    and b.makeup_right_id is null
    and b.status in('confirmed','rescheduled');

  perform l.id
  from public.lessons l
  join public.bookings b on b.lesson_id=l.id
  where b.id=any(affected_booking_ids)
  order by l.id
  for update of l;

  select * into balance from private.lesson_credit_balance(p_entitlement_id);

  if balance.available<>0 or balance.reserved<>0 then
    insert into public.lesson_credit_ledger(
      entitlement_id,beneficiary_user_id,entry_type,available_delta,reserved_delta,
      operation_key,reason_code,actor_user_id,metadata
    )
    select e.id,e.beneficiary_user_id,'revocation',-balance.available,-balance.reserved,
      'revoke:'||p_idempotency_key,'admin_revocation',p_actor_user_id,
      jsonb_build_object('reason',trim(p_reason))
    from public.entitlements e
    where e.id=p_entitlement_id;
  end if;

  update public.lesson_credit_reservations
  set status='released',released_at=now(),updated_at=now()
  where id=any(affected_reservation_ids) and status='reserved';

  for linked in
    select b.id as booking_id,b.source,b.status as booking_status,
      b.starts_at,b.ends_at,b.lesson_id,b.credit_reservation_id,
      l.status as lesson_status
    from public.bookings b
    left join public.lessons l on l.id=b.lesson_id
    where b.id=any(affected_booking_ids)
    order by b.id
  loop
    lesson_after:=linked.lesson_status;
    if linked.lesson_id is not null and linked.lesson_status='scheduled' then
      update public.lessons
      set status='admin_cancelled',updated_at=now()
      where id=linked.lesson_id and status='scheduled'
      returning status into lesson_after;
    end if;

    update public.bookings
    set status='cancelled',cancelled_at=now(),cancellation_reason=trim(p_reason),
      cancellation_credit_outcome='unchanged',earning_outcome='not_applicable',
      updated_at=now()
    where id=linked.booking_id and status in('confirmed','rescheduled');

    if found then
      reconciled_count:=reconciled_count+1;
      insert into public.audit_logs(
        actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
      ) values(
        p_actor_user_id,'entitlement_revoke.booking_reconciled','booking',linked.booking_id,
        jsonb_build_object(
          'entitlement_id',p_entitlement_id,
          'reservation_id',linked.credit_reservation_id,
          'reservation_status','reserved',
          'booking_id',linked.booking_id,
          'booking_status',linked.booking_status,
          'booking_source',linked.source,
          'lesson_id',linked.lesson_id,
          'lesson_status',linked.lesson_status,
          'starts_at',linked.starts_at,
          'ends_at',linked.ends_at
        ),
        jsonb_build_object(
          'entitlement_id',p_entitlement_id,
          'entitlement_status','revoked',
          'reservation_id',linked.credit_reservation_id,
          'reservation_status','released',
          'booking_id',linked.booking_id,
          'booking_status','cancelled',
          'booking_source',linked.source,
          'lesson_id',linked.lesson_id,
          'lesson_status',lesson_after,
          'credit_outcome','unchanged'
        ),
        trim(p_reason)
      );
    end if;
  end loop;

  return jsonb_build_object(
    'available',balance.available,
    'reserved',balance.reserved,
    'reconciled_booking_count',reconciled_count
  );
end;
$$;

create or replace function public.admin_revoke_entitlement(
  p_entitlement_id uuid,p_reason text,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  caller uuid:=auth.uid();
  ent public.entitlements%rowtype;
  reconciliation jsonb;
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

  select * into ent from public.entitlements
  where id=p_entitlement_id for update;
  if not found then
    raise exception using errcode='P0001',message='ENTITLEMENT_NOT_FOUND';
  end if;
  if ent.status='revoked' then
    return ent.id;
  end if;

  reconciliation:=private.reconcile_bookings_on_entitlement_revoke(
    ent.id,caller,trim(p_reason),p_idempotency_key
  );

  update public.entitlements
  set status='revoked',revoked_at=now(),revoked_by=caller,
    revoked_reason=trim(p_reason),updated_at=now()
  where id=ent.id;

  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(
    caller,'entitlement.revoked','entitlement',ent.id,
    jsonb_build_object(
      'status',ent.status,
      'available',reconciliation->'available',
      'reserved',reconciliation->'reserved'
    ),
    jsonb_build_object(
      'status','revoked','available',0,'reserved',0,
      'reconciled_booking_count',reconciliation->'reconciled_booking_count'
    ),
    trim(p_reason)
  );
  return ent.id;
end;
$$;

alter function private.reconcile_bookings_on_entitlement_revoke(uuid,uuid,text,text)
  owner to postgres;
alter function public.admin_revoke_entitlement(uuid,text,text) owner to postgres;

revoke all on function private.reconcile_bookings_on_entitlement_revoke(uuid,uuid,text,text)
  from public,anon,authenticated,service_role;

revoke all on function public.admin_revoke_entitlement(uuid,text,text)
  from public,anon,authenticated,service_role;
grant execute on function public.admin_revoke_entitlement(uuid,text,text)
  to authenticated;

comment on function private.reconcile_bookings_on_entitlement_revoke(uuid,uuid,text,text) is
  'Releases reserved ordinary value and reconciles linked active Bookings/Lessons during authoritative Entitlement revocation. Caller must hold the Entitlement row lock.';

commit;
