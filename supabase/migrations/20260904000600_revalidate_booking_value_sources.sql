begin;

create or replace function private.validate_booking_value_source(
  p_booking_id uuid,
  p_effective_starts_at timestamptz,
  p_operation text
) returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  booking_row public.bookings%rowtype;
  lesson_row public.lessons%rowtype;
  reservation_row public.lesson_credit_reservations%rowtype;
  entitlement_row public.entitlements%rowtype;
  right_row public.makeup_rights%rowtype;
begin
  if p_effective_starts_at is null or p_operation not in('reschedule','complete') then
    raise exception using errcode='22023',message='INVALID_BOOKING_VALUE_SOURCE_VALIDATION';
  end if;

  select * into booking_row from public.bookings where id=p_booking_id;
  if not found then
    raise exception using errcode='P0001',message='BOOKING_SOURCE_MISMATCH';
  end if;
  select * into lesson_row from public.lessons where id=booking_row.lesson_id;
  if not found or lesson_row.student_user_id<>booking_row.student_user_id
    or lesson_row.teacher_user_id<>booking_row.teacher_user_id
    or lesson_row.relationship_id<>booking_row.relationship_id then
    raise exception using errcode='P0001',message='BOOKING_SOURCE_MISMATCH';
  end if;

  if booking_row.source in('flexible','fixed') then
    if booking_row.credit_reservation_id is null or booking_row.makeup_right_id is not null then
      raise exception using errcode='P0001',message='BOOKING_SOURCE_MISMATCH';
    end if;
    select * into reservation_row from public.lesson_credit_reservations
    where id=booking_row.credit_reservation_id;
    if not found
      or reservation_row.booking_id is distinct from booking_row.id
      or reservation_row.lesson_id is distinct from booking_row.lesson_id
      or reservation_row.beneficiary_user_id<>booking_row.student_user_id then
      raise exception using errcode='P0001',message='BOOKING_SOURCE_MISMATCH';
    end if;
    if reservation_row.status='released' or reservation_row.converted_makeup_right_id is not null then
      raise exception using errcode='P0001',message='CREDIT_ALREADY_RELEASED';
    end if;
    if reservation_row.status='consumed' then
      raise exception using errcode='P0001',message='CREDIT_ALREADY_CONSUMED';
    end if;

    select * into entitlement_row from public.entitlements
    where id=reservation_row.entitlement_id;
    if not found or entitlement_row.entitlement_type<>'lesson_package'
      or entitlement_row.beneficiary_user_id<>booking_row.student_user_id
      or (entitlement_row.teacher_scope_user_id is not null
        and entitlement_row.teacher_scope_user_id<>booking_row.teacher_user_id)
      or not (entitlement_row.booking_mode_eligibility='both'
        or entitlement_row.booking_mode_eligibility::text=booking_row.source::text) then
      raise exception using errcode='P0001',message='BOOKING_SOURCE_MISMATCH';
    end if;
    if (p_operation='reschedule' and entitlement_row.status<>'active')
      or (p_operation='complete' and entitlement_row.status not in('active','expired')) then
      raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ACTIVE';
    end if;
    if p_operation='reschedule' and p_effective_starts_at<entitlement_row.starts_at then
      raise exception using errcode='P0001',message='ENTITLEMENT_NOT_STARTED';
    end if;
    if entitlement_row.expires_at is not null
      and p_effective_starts_at>entitlement_row.expires_at then
      raise exception using errcode='P0001',message='ENTITLEMENT_EXPIRED';
    end if;
    return;
  end if;

  if booking_row.source='makeup' then
    if booking_row.makeup_right_id is null or booking_row.credit_reservation_id is not null
      or booking_row.recurring_series_id is not null or booking_row.occurrence_date is not null then
      raise exception using errcode='P0001',message='BOOKING_SOURCE_MISMATCH';
    end if;
    select * into right_row from public.makeup_rights where id=booking_row.makeup_right_id;
    if not found or right_row.student_user_id<>booking_row.student_user_id
      or right_row.current_teacher_user_id<>booking_row.teacher_user_id
      or not exists(
        select 1 from public.makeup_right_operations operation
        where operation.makeup_right_id=right_row.id
          and operation.operation_type='reserve'
          and operation.booking_id=booking_row.id
          and operation.lesson_id=booking_row.lesson_id
      ) then
      raise exception using errcode='P0001',message='BOOKING_SOURCE_MISMATCH';
    end if;
    if right_row.status='expired' or p_effective_starts_at>right_row.valid_until then
      raise exception using errcode='P0001',message='MAKEUP_RIGHT_EXPIRED';
    end if;
    if right_row.status<>'reserved' then
      raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_RESERVED';
    end if;
    return;
  end if;

  raise exception using errcode='P0001',message='BOOKING_SOURCE_MISMATCH';
end;
$$;

create or replace function private.reschedule_ordinary_lesson_booking_authority(
  p_booking_id uuid,p_new_starts_at timestamptz,p_timezone text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; b public.bookings%rowtype;
  ent public.entitlements%rowtype; reservation public.lesson_credit_reservations%rowtype;
  lesson public.lessons%rowtype; new_end timestamptz; occurrence_id uuid;
begin
  if caller is null or not private.current_user_is_active()
    or not private.is_valid_iana_timezone(p_timezone)
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  select * into b from public.bookings where id=p_booking_id;
  if not found then raise exception using errcode='P0001',message='BOOKING_NOT_RESCHEDULABLE'; end if;
  actor_role:=private.scheduling_actor_role(caller);
  if not (caller=b.student_user_id
    or (caller=b.teacher_user_id and private.scheduling_teacher_authorized(b.teacher_user_id))
    or actor_role in('admin','super_admin')) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  perform private.lock_lesson_schedule_resources(b.student_user_id,b.teacher_user_id);
  select e.* into ent from public.entitlements e join public.lesson_credit_reservations r
    on r.entitlement_id=e.id where r.id=b.credit_reservation_id for update of e;
  select * into reservation from public.lesson_credit_reservations
    where id=b.credit_reservation_id for update;
  select * into b from public.bookings where id=p_booking_id for update;
  if b.status not in('confirmed','rescheduled') then
    raise exception using errcode='P0001',message='BOOKING_NOT_RESCHEDULABLE';
  end if;
  new_end:=p_new_starts_at+make_interval(
    mins=>extract(epoch from (b.ends_at-b.starts_at))::integer/60);
  select id into occurrence_id from public.recurring_lesson_occurrences
    where booking_id=b.id for update;
  select * into lesson from public.lessons where id=b.lesson_id for update;
  perform private.validate_booking_value_source(b.id,p_new_starts_at,'reschedule');
  if lesson.status<>'scheduled' then
    raise exception using errcode='P0001',message='BOOKING_NOT_RESCHEDULABLE';
  end if;
  if not private.flexible_slot_is_available(
    b.student_user_id,b.teacher_user_id,p_new_starts_at,
    extract(epoch from (new_end-p_new_starts_at))::integer/60,b.lesson_id,occurrence_id
  ) then
    raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
  end if;
  update public.lessons set starts_at=p_new_starts_at,ends_at=new_end,
    timezone_anchor=p_timezone,status='scheduled',updated_at=now() where id=lesson.id;
  update public.bookings set starts_at=p_new_starts_at,ends_at=new_end,
    timezone_anchor=p_timezone,status='rescheduled',rescheduled_at=now(),updated_at=now()
    where id=b.id;
  if occurrence_id is not null then
    update public.recurring_lesson_occurrences
    set starts_at=p_new_starts_at,ends_at=new_end,updated_at=now()
    where id=occurrence_id;
    insert into public.recurring_lesson_series_exceptions(
      series_id,occurrence_date,exception_kind,replacement_starts_at,replacement_ends_at,
      reason,actor_user_id,actor_role
    ) values(
      b.recurring_series_id,b.occurrence_date,'reschedule',p_new_starts_at,new_end,
      trim(p_reason),caller,actor_role
    ) on conflict(series_id,occurrence_date) do update set
      exception_kind='reschedule',replacement_starts_at=excluded.replacement_starts_at,
      replacement_ends_at=excluded.replacement_ends_at,reason=excluded.reason,
      actor_user_id=excluded.actor_user_id,actor_role=excluded.actor_role,created_at=now();
  end if;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(
    caller,'booking.rescheduled','booking',b.id,
    jsonb_build_object('starts_at',b.starts_at,'ends_at',b.ends_at),
    jsonb_build_object('starts_at',p_new_starts_at,'ends_at',new_end,
      'credit_reservation_id',b.credit_reservation_id),trim(p_reason)
  );
  return b.id;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
end;
$$;

create or replace function private.complete_ordinary_lesson_booking_authority(
  p_booking_id uuid,p_student_visible_notes text,p_private_teacher_notes text,
  p_performance_summary text,p_next_goal text,p_homework text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; b public.bookings%rowtype;
  ent public.entitlements%rowtype; lesson public.lessons%rowtype;
  reservation public.lesson_credit_reservations%rowtype; occurrence_id uuid;
begin
  select * into b from public.bookings where id=p_booking_id;
  actor_role:=private.scheduling_actor_role(caller);
  if not found or caller is null or not private.current_user_is_active()
    or not ((caller=b.teacher_user_id and private.scheduling_teacher_authorized(b.teacher_user_id))
      or actor_role in('admin','super_admin')) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if char_length(coalesce(p_student_visible_notes,''))>4000
    or char_length(coalesce(p_private_teacher_notes,''))>4000
    or char_length(coalesce(p_performance_summary,''))>4000
    or char_length(coalesce(p_next_goal,''))>2000
    or char_length(coalesce(p_homework,''))>2000 then
    raise exception using errcode='22023',message='INVALID_LESSON_RECORD';
  end if;
  perform private.lock_lesson_schedule_resources(b.student_user_id,b.teacher_user_id);
  select entitlement.* into ent from public.entitlements entitlement
  join public.lesson_credit_reservations credit on credit.entitlement_id=entitlement.id
  where credit.id=b.credit_reservation_id for update of entitlement;
  select * into reservation from public.lesson_credit_reservations
    where id=b.credit_reservation_id for update;
  select * into b from public.bookings where id=p_booking_id for update;
  select id into occurrence_id from public.recurring_lesson_occurrences
    where booking_id=b.id for update;
  select * into lesson from public.lessons where id=b.lesson_id for update;
  if b.status='completed' and lesson.status='completed' and reservation.status='consumed' then
    return lesson.id;
  end if;
  perform private.validate_booking_value_source(b.id,lesson.starts_at,'complete');
  if b.status not in('confirmed','rescheduled') or lesson.status<>'scheduled'
    or lesson.starts_at>now() then
    raise exception using errcode='P0001',message='BOOKING_NOT_COMPLETABLE';
  end if;
  update public.lessons set status='completed',updated_at=now() where id=lesson.id;
  insert into public.lesson_records(
    lesson_id,student_visible_notes,private_teacher_notes,performance_summary,
    next_goal,homework,completed_at,completed_by
  ) values(
    lesson.id,coalesce(p_student_visible_notes,''),coalesce(p_private_teacher_notes,''),
    coalesce(p_performance_summary,''),coalesce(p_next_goal,''),
    coalesce(p_homework,''),now(),caller
  ) on conflict(lesson_id) do nothing;
  perform private.consume_lesson_credit_core(
    reservation.id,lesson.id,'lesson_completed',caller,
    jsonb_build_object('booking_id',b.id,'reason','Lesson completed'));
  update public.bookings set status='completed',completed_at=now(),updated_at=now()
    where id=b.id;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(
    caller,'booking.completed','booking',b.id,jsonb_build_object('status',b.status),
    jsonb_build_object('status','completed','lesson_id',lesson.id,
      'credit_reservation_id',reservation.id,'earning_outcome','future_integration'),
    'Lesson completed'
  );
  return lesson.id;
end;
$$;

create or replace function private.reschedule_makeup_lesson_booking_core(
  p_booking_id uuid,p_new_starts_at timestamptz,p_timezone text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; b public.bookings%rowtype;
  lesson public.lessons%rowtype; right_locked public.makeup_rights%rowtype;
  new_end timestamptz;
begin
  if caller is null or not private.current_user_is_active()
    or not private.is_valid_iana_timezone(p_timezone)
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  select * into b from public.bookings where id=p_booking_id;
  actor_role:=private.scheduling_actor_role(caller);
  if not found or b.source<>'makeup' or b.makeup_right_id is null
    or not (caller=b.student_user_id
      or (caller=b.teacher_user_id and private.scheduling_teacher_authorized(b.teacher_user_id))
      or actor_role in('admin','super_admin')) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  select * into right_locked from public.makeup_rights
    where id=b.makeup_right_id for update;
  perform private.lock_lesson_schedule_resources(b.student_user_id,b.teacher_user_id);
  select * into b from public.bookings where id=p_booking_id for update;
  select * into lesson from public.lessons where id=b.lesson_id for update;
  if b.status not in('confirmed','rescheduled') or lesson.status<>'scheduled' then
    raise exception using errcode='P0001',message='BOOKING_NOT_RESCHEDULABLE';
  end if;
  perform private.validate_booking_value_source(b.id,p_new_starts_at,'reschedule');
  new_end:=p_new_starts_at+(b.ends_at-b.starts_at);
  if not private.flexible_slot_is_available(
    b.student_user_id,b.teacher_user_id,p_new_starts_at,
    extract(epoch from (new_end-p_new_starts_at))::integer/60,b.lesson_id,null
  ) then
    raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
  end if;
  update public.lessons set starts_at=p_new_starts_at,ends_at=new_end,
    timezone_anchor=p_timezone,status='scheduled',updated_at=now() where id=lesson.id;
  update public.bookings set starts_at=p_new_starts_at,ends_at=new_end,
    timezone_anchor=p_timezone,status='rescheduled',rescheduled_at=now(),updated_at=now()
    where id=b.id;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(
    caller,'makeup_booking.rescheduled','booking',b.id,
    jsonb_build_object('starts_at',b.starts_at,'ends_at',b.ends_at,
      'makeup_right_id',right_locked.id,'lesson_id',lesson.id),
    jsonb_build_object('starts_at',p_new_starts_at,'ends_at',new_end,
      'makeup_right_id',right_locked.id,'lesson_id',lesson.id),trim(p_reason)
  );
  return b.id;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
end;
$$;

create or replace function private.complete_makeup_lesson_booking_core(
  p_booking_id uuid,p_student_visible_notes text,p_private_teacher_notes text,
  p_performance_summary text,p_next_goal text,p_homework text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; b public.bookings%rowtype;
  lesson public.lessons%rowtype; right_before public.makeup_rights%rowtype;
  right_changed public.makeup_rights%rowtype;
begin
  select * into b from public.bookings where id=p_booking_id;
  actor_role:=private.scheduling_actor_role(caller);
  if not found or b.source<>'makeup' or b.makeup_right_id is null
    or caller is null or not private.current_user_is_active()
    or not ((caller=b.teacher_user_id and private.scheduling_teacher_authorized(b.teacher_user_id))
      or actor_role in('admin','super_admin')) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if char_length(coalesce(p_student_visible_notes,''))>4000
    or char_length(coalesce(p_private_teacher_notes,''))>4000
    or char_length(coalesce(p_performance_summary,''))>4000
    or char_length(coalesce(p_next_goal,''))>2000
    or char_length(coalesce(p_homework,''))>2000 then
    raise exception using errcode='22023',message='INVALID_LESSON_RECORD';
  end if;
  select * into right_before from public.makeup_rights
    where id=b.makeup_right_id for update;
  perform private.lock_lesson_schedule_resources(b.student_user_id,b.teacher_user_id);
  select * into b from public.bookings where id=p_booking_id for update;
  select * into lesson from public.lessons where id=b.lesson_id for update;
  if b.status='completed' and lesson.status='completed' and right_before.status='used' then
    return lesson.id;
  end if;
  perform private.validate_booking_value_source(b.id,lesson.starts_at,'complete');
  if b.status not in('confirmed','rescheduled') or lesson.status<>'scheduled'
    or lesson.starts_at>now() then
    raise exception using errcode='P0001',message='BOOKING_NOT_COMPLETABLE';
  end if;
  update public.lessons set status='completed',updated_at=now() where id=lesson.id;
  insert into public.lesson_records(
    lesson_id,student_visible_notes,private_teacher_notes,performance_summary,
    next_goal,homework,completed_at,completed_by
  ) values(
    lesson.id,coalesce(p_student_visible_notes,''),coalesce(p_private_teacher_notes,''),
    coalesce(p_performance_summary,''),coalesce(p_next_goal,''),
    coalesce(p_homework,''),now(),caller
  ) on conflict(lesson_id) do nothing;
  update public.makeup_rights
  set status='used',used_at=now(),used_by=caller,updated_at=now()
  where id=right_before.id and status='reserved' returning * into right_changed;
  if right_changed.id is null then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_RESERVED';
  end if;
  perform private.record_makeup_booking_operation(
    right_changed,'consume','makeup-booking-consume:'||b.id::text,caller,
    'Makeup lesson completed',right_before.status,to_jsonb(right_before),b.id,lesson.id
  );
  update public.bookings set status='completed',completed_at=now(),updated_at=now()
    where id=b.id;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(
    caller,'makeup_booking.completed','booking',b.id,
    jsonb_build_object('status',b.status,'makeup_right_id',right_before.id,
      'right_status',right_before.status,'lesson_id',lesson.id),
    jsonb_build_object('status','completed','makeup_right_id',right_changed.id,
      'right_status','used','lesson_id',lesson.id),'Makeup lesson completed'
  );
  return lesson.id;
end;
$$;

alter function private.validate_booking_value_source(uuid,timestamptz,text) owner to postgres;
alter function private.reschedule_ordinary_lesson_booking_authority(uuid,timestamptz,text,text)
  owner to postgres;
alter function private.complete_ordinary_lesson_booking_authority(uuid,text,text,text,text,text)
  owner to postgres;
alter function private.reschedule_makeup_lesson_booking_core(uuid,timestamptz,text,text)
  owner to postgres;
alter function private.complete_makeup_lesson_booking_core(uuid,text,text,text,text,text)
  owner to postgres;

revoke all on function private.validate_booking_value_source(uuid,timestamptz,text),
  private.reschedule_ordinary_lesson_booking_authority(uuid,timestamptz,text,text),
  private.complete_ordinary_lesson_booking_authority(uuid,text,text,text,text,text),
  private.reschedule_makeup_lesson_booking_core(uuid,timestamptz,text,text),
  private.complete_makeup_lesson_booking_core(uuid,text,text,text,text,text)
from public,anon,authenticated,service_role;

comment on function private.validate_booking_value_source(uuid,timestamptz,text) is
  'Explicit authority for ordinary credit and Makeup Right binding, lifecycle, scope, and scheduled-time validation. Callers must acquire source and Booking/Lesson locks first.';

commit;
