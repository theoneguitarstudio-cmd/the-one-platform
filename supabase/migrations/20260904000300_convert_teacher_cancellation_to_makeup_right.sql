begin;

create table public.makeup_right_policies (
  source public.makeup_right_source primary key,
  validity_seconds integer not null check(validity_seconds between 1 and 315360000),
  updated_by uuid not null references auth.users(id) on delete restrict,
  updated_at timestamptz not null default now()
);

alter table public.lesson_credit_reservations
  add column converted_makeup_right_id uuid unique
    references public.makeup_rights(id) on delete restrict,
  add column converted_at timestamptz,
  add column converted_by uuid references auth.users(id) on delete restrict,
  add constraint lesson_credit_reservation_makeup_conversion check(
    (converted_makeup_right_id is null and converted_at is null and converted_by is null)
    or (converted_makeup_right_id is not null and converted_at is not null
      and converted_by is not null and status='released')
  );

create or replace function public.set_makeup_right_policy(
  p_source public.makeup_right_source,p_validity_seconds integer,p_reason text
) returns public.makeup_right_source language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); old_policy public.makeup_right_policies%rowtype;
  changed public.makeup_right_policies%rowtype;
begin
  if caller is null or not private.current_user_has_role(
    array['admin'::public.app_role,'super_admin'::public.app_role]) then
    raise exception using errcode='42501',message='UNAUTHORIZED_MAKEUP_ACTION';
  end if;
  if p_source is null or p_validity_seconds not between 1 and 315360000
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_MAKEUP_POLICY';
  end if;
  select * into old_policy from public.makeup_right_policies where source=p_source;
  insert into public.makeup_right_policies(source,validity_seconds,updated_by)
  values(p_source,p_validity_seconds,caller)
  on conflict(source) do update set validity_seconds=excluded.validity_seconds,
    updated_by=excluded.updated_by,updated_at=now()
  returning * into changed;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(caller,'makeup_right.policy_changed','makeup_right_policy',caller,
    case when old_policy.source is null then '{}'::jsonb else to_jsonb(old_policy) end,
    to_jsonb(changed),trim(p_reason));
  return changed.source;
end;
$$;

create or replace function private.convert_lesson_credit_reservation_to_makeup_core(
  p_reservation_id uuid,p_cancellation_id uuid,p_lesson_id uuid,
  p_actor_user_id uuid,p_reason text,p_validity_seconds integer
) returns uuid language plpgsql security definer set search_path=''
as $$
declare reservation public.lesson_credit_reservations%rowtype;
  entitlement public.entitlements%rowtype; lesson public.lessons%rowtype;
  makeup_right_id uuid; balance record;
begin
  if p_validity_seconds not between 1 and 315360000
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_MAKEUP_TRANSFER';
  end if;
  select e.* into entitlement from public.entitlements e
  join public.lesson_credit_reservations r on r.entitlement_id=e.id
  where r.id=p_reservation_id for update of e;
  if not found then raise exception using errcode='P0001',message='CREDIT_RESERVATION_NOT_FOUND'; end if;
  select * into reservation from public.lesson_credit_reservations
    where id=p_reservation_id for update;
  select * into lesson from public.lessons where id=p_lesson_id for update;
  if reservation.id is null or lesson.id is null
    or reservation.lesson_id is distinct from p_lesson_id
    or reservation.entitlement_id<>entitlement.id
    or reservation.beneficiary_user_id<>lesson.student_user_id then
    raise exception using errcode='P0001',message='MAKEUP_TRANSFER_ORIGIN_MISMATCH';
  end if;
  if reservation.converted_makeup_right_id is not null then
    return reservation.converted_makeup_right_id;
  end if;
  if reservation.status<>'reserved' then
    raise exception using errcode='P0001',message='CREDIT_RESERVATION_NOT_RESERVED';
  end if;
  makeup_right_id:=private.create_makeup_right_core(
    lesson.student_user_id,lesson.id,lesson.teacher_user_id,lesson.teacher_user_id,
    now()+make_interval(secs=>p_validity_seconds),'teacher_cancellation',
    'teacher-cancellation:'||p_cancellation_id::text,trim(p_reason),p_actor_user_id,
    entitlement.id,reservation.id
  );
  update public.lesson_credit_reservations set status='released',released_at=now(),
    converted_makeup_right_id=makeup_right_id,converted_at=now(),converted_by=p_actor_user_id,
    updated_at=now() where id=reservation.id;
  insert into public.lesson_credit_ledger(
    entitlement_id,beneficiary_user_id,entry_type,available_delta,reserved_delta,consumed_delta,
    reservation_id,lesson_id,operation_key,reason_code,actor_user_id,metadata
  ) values(
    entitlement.id,entitlement.beneficiary_user_id,'adjustment',0,-1,0,
    reservation.id,lesson.id,'makeup-transfer:'||reservation.id::text,
    'teacher_cancellation_makeup_transfer',p_actor_user_id,
    jsonb_build_object('cancellation_id',p_cancellation_id,'makeup_right_id',makeup_right_id,
      'reason',trim(p_reason))
  );
  select * into balance from private.lesson_credit_balance(entitlement.id);
  if balance.available=0 and balance.reserved=0 and entitlement.status='active' then
    update public.entitlements set status='exhausted',updated_at=now()
      where id=entitlement.id and status='active';
  end if;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(
    p_actor_user_id,'lesson_credit.converted_to_makeup','lesson_credit_reservation',reservation.id,
    jsonb_build_object('status',reservation.status,'entitlement_id',entitlement.id,
      'lesson_id',lesson.id,'cancellation_id',p_cancellation_id),
    jsonb_build_object('status','released','ordinary_available_delta',0,
      'ordinary_reserved_delta',-1,'ordinary_consumed_delta',0,
      'makeup_right_id',makeup_right_id),trim(p_reason)
  );
  return makeup_right_id;
end;
$$;

create or replace function public.cancel_lesson_booking(
  p_booking_id uuid,p_credit_outcome public.booking_credit_outcome,p_reason text,
  p_earning_outcome text default 'not_applicable'
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; b public.bookings%rowtype;
  ent public.entitlements%rowtype; reservation public.lesson_credit_reservations%rowtype;
  lesson public.lessons%rowtype; occurrence_id uuid; teacher_caused boolean;
  effective_credit_outcome public.booking_credit_outcome; makeup_right_id uuid;
  makeup_validity_seconds integer;
begin
  if caller is null or not private.current_user_is_active()
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or char_length(coalesce(p_earning_outcome,'')) not between 1 and 100 then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  select * into b from public.bookings where id=p_booking_id;
  if not found then raise exception using errcode='P0001',message='BOOKING_NOT_CANCELLABLE'; end if;
  actor_role:=private.scheduling_actor_role(caller);
  if not (caller=b.student_user_id
    or (caller=b.teacher_user_id and private.scheduling_teacher_authorized(b.teacher_user_id))
    or actor_role in('admin','super_admin')) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  teacher_caused:=caller=b.teacher_user_id
    or (actor_role in('admin','super_admin') and p_earning_outcome='teacher_caused');
  if teacher_caused and p_credit_outcome not in('released','unchanged') then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if not teacher_caused and p_credit_outcome='consumed'
    and actor_role not in('admin','super_admin') then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if not teacher_caused and actor_role not in('admin','super_admin')
    and p_credit_outcome<>'released' then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  perform private.lock_lesson_schedule_resources(b.student_user_id,b.teacher_user_id);
  select e.* into ent from public.entitlements e
  join public.lesson_credit_reservations credit on credit.entitlement_id=e.id
  where credit.id=b.credit_reservation_id for update of e;
  select * into reservation from public.lesson_credit_reservations
    where id=b.credit_reservation_id for update;
  select * into b from public.bookings where id=p_booking_id for update;
  select id into occurrence_id from public.recurring_lesson_occurrences
    where booking_id=b.id for update;
  select * into lesson from public.lessons where id=b.lesson_id for update;
  if b.status='cancelled' then return b.id; end if;
  if b.status not in('confirmed','rescheduled') then
    raise exception using errcode='P0001',message='BOOKING_NOT_CANCELLABLE';
  end if;
  effective_credit_outcome:=p_credit_outcome;
  if teacher_caused then
    select validity_seconds into makeup_validity_seconds
      from public.makeup_right_policies where source='teacher_cancellation';
    if makeup_validity_seconds is null then
      raise exception using errcode='P0001',message='MAKEUP_POLICY_MISSING';
    end if;
    makeup_right_id:=private.convert_lesson_credit_reservation_to_makeup_core(
      reservation.id,b.id,lesson.id,caller,p_reason,makeup_validity_seconds);
    effective_credit_outcome:='unchanged';
  elsif p_credit_outcome='released' then
    perform private.release_lesson_credit_core(
      reservation.id,'booking_cancellation',caller,
      jsonb_build_object('booking_id',b.id,'reason',trim(p_reason)),true);
  elsif p_credit_outcome='consumed' then
    perform private.consume_lesson_credit_core(
      reservation.id,lesson.id,'admin_cancellation_consumed',caller,
      jsonb_build_object('booking_id',b.id,'reason',trim(p_reason)));
  end if;
  update public.lessons set status=case
      when teacher_caused then 'teacher_cancelled'::public.lesson_status
      when actor_role in('admin','super_admin') then 'admin_cancelled'::public.lesson_status
      else 'student_cancelled'::public.lesson_status
    end,updated_at=now()
    where id=lesson.id and status='scheduled';
  update public.bookings set status='cancelled',cancelled_at=now(),
    cancellation_reason=trim(p_reason),cancellation_credit_outcome=effective_credit_outcome,
    earning_outcome=p_earning_outcome,updated_at=now() where id=b.id;
  if occurrence_id is not null then
    update public.recurring_lesson_occurrences set status=case
      when teacher_caused or effective_credit_outcome='released'
        then 'released'::public.recurring_occurrence_status else status end,
      updated_at=now() where id=occurrence_id;
  end if;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(caller,'booking.cancelled','booking',b.id,
    jsonb_build_object('status',b.status,'starts_at',b.starts_at,'ends_at',b.ends_at,
      'credit_reservation_id',reservation.id),
    jsonb_build_object('status','cancelled','credit_outcome',effective_credit_outcome,
      'earning_outcome',p_earning_outcome,'lesson_id',b.lesson_id,
      'teacher_caused',teacher_caused,'makeup_right_id',makeup_right_id),trim(p_reason));
  return b.id;
end;
$$;

alter table public.makeup_right_policies enable row level security;
revoke all on public.makeup_right_policies from public,anon,authenticated,service_role;

alter function public.set_makeup_right_policy(
  public.makeup_right_source,integer,text
) owner to postgres;
alter function private.convert_lesson_credit_reservation_to_makeup_core(
  uuid,uuid,uuid,uuid,text,integer
) owner to postgres;
alter function public.cancel_lesson_booking(
  uuid,public.booking_credit_outcome,text,text
) owner to postgres;

revoke all on function public.set_makeup_right_policy(
  public.makeup_right_source,integer,text
) from public,anon,service_role;
grant execute on function public.set_makeup_right_policy(
  public.makeup_right_source,integer,text
) to authenticated;
revoke all on function private.convert_lesson_credit_reservation_to_makeup_core(
  uuid,uuid,uuid,uuid,text,integer
) from public,anon,authenticated,service_role;
revoke all on function public.cancel_lesson_booking(
  uuid,public.booking_credit_outcome,text,text
) from public,anon,service_role;
grant execute on function public.cancel_lesson_booking(
  uuid,public.booking_credit_outcome,text,text
) to authenticated;

commit;
