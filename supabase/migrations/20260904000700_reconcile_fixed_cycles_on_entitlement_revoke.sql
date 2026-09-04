alter type public.fixed_entitlement_cycle_status add value if not exists 'invalidated';

begin;

alter table public.fixed_entitlement_cycles
  drop constraint fixed_entitlement_cycles_check;
alter table public.fixed_entitlement_cycles
  add constraint fixed_entitlement_cycles_check check(
    (status='active' and completed_at is null and completed_by is null)
    or (status='completed' and completed_at>=attached_at and completed_by is not null)
    or (status='invalidated' and completed_at is null and completed_by is null)
  );

create or replace function private.protect_fixed_cycle_history()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then
    raise exception using errcode='55000',message='FIXED_CYCLE_HISTORY_IMMUTABLE';
  end if;
  if (new.id,new.series_id,new.entitlement_id,new.student_user_id,new.teacher_user_id,
      new.sequence_number,new.source_fulfillment_event_id,new.source_order_item_id,
      new.attached_at,new.attached_by,new.attachment_actor_role,new.attachment_reason,new.created_at)
    is distinct from
     (old.id,old.series_id,old.entitlement_id,old.student_user_id,old.teacher_user_id,
      old.sequence_number,old.source_fulfillment_event_id,old.source_order_item_id,
      old.attached_at,old.attached_by,old.attachment_actor_role,old.attachment_reason,old.created_at)
    or old.status in('completed','invalidated') then
    raise exception using errcode='55000',message='FIXED_CYCLE_HISTORY_IMMUTABLE';
  end if;
  if new.status not in('completed','invalidated') then
    raise exception using errcode='55000',message='INVALID_FIXED_CYCLE_TRANSITION';
  end if;
  return new;
end;
$$;

create or replace function private.reconcile_fixed_cycles_on_entitlement_revoke(
  p_entitlement_id uuid,
  p_actor_user_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  cycle_row public.fixed_entitlement_cycles%rowtype;
  series_row public.recurring_lesson_series%rowtype;
  invalidated_count integer:=0;
  cleared_pointer_count integer:=0;
begin
  if p_entitlement_id is null
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_FIXED_CYCLE_RECONCILIATION';
  end if;

  -- The caller owns the Entitlement lock. Preserve the global order:
  -- Entitlement -> Fixed Cycle -> Series -> Reservation -> Booking -> Lesson.
  perform c.id
  from public.fixed_entitlement_cycles c
  where c.entitlement_id=p_entitlement_id
  order by c.id
  for update;

  perform s.id
  from public.recurring_lesson_series s
  where s.preferred_entitlement_id=p_entitlement_id
    or exists(
      select 1 from public.fixed_entitlement_cycles c
      where c.series_id=s.id and c.entitlement_id=p_entitlement_id
    )
  order by s.id
  for update;

  for cycle_row in
    select * from public.fixed_entitlement_cycles
    where entitlement_id=p_entitlement_id and status='active'
    order by id
  loop
    update public.fixed_entitlement_cycles
    set status='invalidated',updated_at=now()
    where id=cycle_row.id and status='active';
    if found then
      invalidated_count:=invalidated_count+1;
      insert into public.audit_logs(
        actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
      ) values(
        p_actor_user_id,'fixed_cycle.invalidated','fixed_entitlement_cycle',cycle_row.id,
        jsonb_build_object(
          'status',cycle_row.status,'cycle_id',cycle_row.id,'series_id',cycle_row.series_id,
          'entitlement_id',cycle_row.entitlement_id,'sequence_number',cycle_row.sequence_number
        ),
        jsonb_build_object(
          'status','invalidated','cycle_id',cycle_row.id,'series_id',cycle_row.series_id,
          'entitlement_id',cycle_row.entitlement_id,'sequence_number',cycle_row.sequence_number,
          'actor_user_id',p_actor_user_id
        ),trim(p_reason)
      );
    end if;
  end loop;

  for series_row in
    select * from public.recurring_lesson_series
    where preferred_entitlement_id=p_entitlement_id
    order by id
  loop
    update public.recurring_lesson_series
    set preferred_entitlement_id=null,updated_at=now()
    where id=series_row.id and preferred_entitlement_id=p_entitlement_id;
    if found then
      cleared_pointer_count:=cleared_pointer_count+1;
      insert into public.audit_logs(
        actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
      ) values(
        p_actor_user_id,'recurring_series.preferred_entitlement_cleared',
        'recurring_lesson_series',series_row.id,
        jsonb_build_object(
          'series_id',series_row.id,'preferred_entitlement_id',p_entitlement_id,
          'status',series_row.status
        ),
        jsonb_build_object(
          'series_id',series_row.id,'preferred_entitlement_id',null,
          'status',series_row.status,'actor_user_id',p_actor_user_id
        ),trim(p_reason)
      );
    end if;
  end loop;

  return jsonb_build_object(
    'invalidated_cycle_count',invalidated_count,
    'cleared_preferred_pointer_count',cleared_pointer_count
  );
end;
$$;

create or replace function public.complete_fixed_entitlement_cycle(
  p_cycle_id uuid,p_reason text
) returns uuid language plpgsql security definer set search_path='' as $$
declare
  c public.fixed_entitlement_cycles%rowtype;
  s public.recurring_lesson_series%rowtype;
  e public.entitlements%rowtype;
  balance record;
  completed_lessons bigint;
  caller uuid:=auth.uid();
  actor_role public.app_role;
begin
  select * into c from public.fixed_entitlement_cycles where id=p_cycle_id;
  if not found then
    raise exception using errcode='P0001',message='FIXED_CYCLE_NOT_FOUND';
  end if;
  select * into s from public.recurring_lesson_series where id=c.series_id;
  actor_role:=private.scheduling_actor_role(caller);
  if caller is null or actor_role not in('teacher','admin','super_admin')
    or not private.scheduling_teacher_authorized(s.teacher_user_id) then
    raise exception using errcode='42501',message='UNAUTHORIZED_FIXED_CYCLE_ACTION';
  end if;
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_FIXED_CYCLE_REQUEST';
  end if;

  perform private.lock_lesson_schedule_resources(s.student_user_id,s.teacher_user_id);
  select * into e from public.entitlements where id=c.entitlement_id for update;
  select * into c from public.fixed_entitlement_cycles where id=p_cycle_id for update;
  perform 1 from public.recurring_lesson_series where id=c.series_id for update;
  if c.status='completed' then return c.id; end if;
  if c.status<>'active' then
    raise exception using errcode='P0001',message='FIXED_CYCLE_NOT_ACTIVE';
  end if;

  select * into balance from private.lesson_credit_balance(e.id);
  if e.status not in('active','exhausted') or balance.available<>0 or balance.reserved<>0
    or balance.consumed<=0 or balance.total<>balance.consumed then
    raise exception using errcode='P0001',message='FIXED_CYCLE_VALUE_INCOMPLETE';
  end if;
  select count(*) into completed_lessons from public.lesson_credit_reservations r
  join public.bookings b on b.credit_reservation_id=r.id
  join public.lessons l on l.id=b.lesson_id
  where r.entitlement_id=e.id and r.status='consumed' and b.recurring_series_id=c.series_id
    and b.status='completed' and l.status='completed' and r.lesson_id=l.id;
  if completed_lessons<>balance.consumed then
    raise exception using errcode='P0001',message='FIXED_CYCLE_LESSONS_INCOMPLETE';
  end if;
  update public.fixed_entitlement_cycles
  set status='completed',completed_at=now(),completed_by=caller,updated_at=now()
  where id=c.id;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(
    caller,'fixed_cycle.completed','fixed_entitlement_cycle',c.id,
    jsonb_build_object('status',c.status),
    jsonb_build_object(
      'status','completed','cycle_id',c.id,'series_id',c.series_id,
      'entitlement_id',c.entitlement_id,
      'source_fulfillment_event_id',c.source_fulfillment_event_id,
      'actor_role',actor_role
    ),trim(p_reason)
  );
  return c.id;
end;
$$;

create or replace function public.admin_revoke_entitlement(
  p_entitlement_id uuid,p_reason text,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path='' as $$
declare
  caller uuid:=auth.uid();
  ent public.entitlements%rowtype;
  fixed_reconciliation jsonb;
  booking_reconciliation jsonb;
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

  fixed_reconciliation:=private.reconcile_fixed_cycles_on_entitlement_revoke(
    ent.id,caller,trim(p_reason)
  );
  if ent.status='revoked' then return ent.id; end if;

  booking_reconciliation:=private.reconcile_bookings_on_entitlement_revoke(
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
      'available',booking_reconciliation->'available',
      'reserved',booking_reconciliation->'reserved'
    ),
    jsonb_build_object(
      'status','revoked','available',0,'reserved',0,
      'reconciled_booking_count',booking_reconciliation->'reconciled_booking_count',
      'invalidated_cycle_count',fixed_reconciliation->'invalidated_cycle_count',
      'cleared_preferred_pointer_count',fixed_reconciliation->'cleared_preferred_pointer_count'
    ),trim(p_reason)
  );
  return ent.id;
end;
$$;

alter function private.protect_fixed_cycle_history() owner to postgres;
alter function private.reconcile_fixed_cycles_on_entitlement_revoke(uuid,uuid,text)
  owner to postgres;
alter function public.complete_fixed_entitlement_cycle(uuid,text) owner to postgres;
alter function public.admin_revoke_entitlement(uuid,text,text) owner to postgres;

revoke all on function private.protect_fixed_cycle_history(),
  private.reconcile_fixed_cycles_on_entitlement_revoke(uuid,uuid,text)
from public,anon,authenticated,service_role;
revoke all on function public.complete_fixed_entitlement_cycle(uuid,text),
  public.admin_revoke_entitlement(uuid,text,text)
from public,anon,authenticated,service_role;
grant execute on function public.complete_fixed_entitlement_cycle(uuid,text) to authenticated;
grant execute on function public.admin_revoke_entitlement(uuid,text,text) to authenticated;

comment on function private.reconcile_fixed_cycles_on_entitlement_revoke(uuid,uuid,text) is
  'Invalidates active Fixed Cycles and clears only matching preferred Entitlement pointers during authoritative revocation. Caller must hold the Entitlement row lock.';

do $$
declare ent record;
begin
  for ent in
    select id,revoked_by,revoked_reason
    from public.entitlements
    where status='revoked'
    order by id
    for update
  loop
    perform private.reconcile_fixed_cycles_on_entitlement_revoke(
      ent.id,ent.revoked_by,
      coalesce(nullif(trim(ent.revoked_reason),''),'Reconcile pre-existing revoked Entitlement')
    );
  end loop;
end;
$$;

commit;
