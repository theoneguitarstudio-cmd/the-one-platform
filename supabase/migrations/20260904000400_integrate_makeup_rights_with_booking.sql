alter type public.booking_source add value if not exists 'makeup';

begin;

alter table public.bookings
  add column makeup_right_id uuid references public.makeup_rights(id) on delete restrict;

create unique index bookings_one_active_makeup_right_idx
  on public.bookings(makeup_right_id)
  where makeup_right_id is not null and status in('confirmed','rescheduled');

alter table public.bookings add constraint bookings_value_source_shape check(
  (source='makeup' and makeup_right_id is not null and credit_reservation_id is null
    and recurring_series_id is null and occurrence_date is null)
  or (source in('flexible','fixed') and makeup_right_id is null
    and credit_reservation_id is not null)
);

alter table public.makeup_right_operations
  add column booking_id uuid references public.bookings(id) on delete restrict,
  add column lesson_id uuid references public.lessons(id) on delete restrict;

create index makeup_right_operations_booking_idx
  on public.makeup_right_operations(booking_id,created_at)
  where booking_id is not null;

comment on column public.bookings.makeup_right_id is
  'Explicit Makeup Right value source. Makeup bookings never use an ordinary lesson-credit reservation.';

create or replace function private.record_makeup_booking_operation(
  p_right public.makeup_rights,p_operation_type public.makeup_right_operation_type,
  p_operation_key text,p_actor_user_id uuid,p_reason text,
  p_from_status public.makeup_right_status,p_before_snapshot jsonb,
  p_booking_id uuid,p_lesson_id uuid
) returns uuid language plpgsql security definer set search_path=''
as $$
declare audit_id uuid; operation_id uuid; linked_after jsonb;
begin
  if p_actor_user_id is null or p_booking_id is null or p_lesson_id is null
    or char_length(coalesce(p_operation_key,'')) not between 16 and 160
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_MAKEUP_BOOKING_OPERATION';
  end if;
  if not exists(
    select 1 from public.bookings b join public.lessons l on l.id=b.lesson_id
    where b.id=p_booking_id and b.lesson_id=p_lesson_id and b.makeup_right_id=p_right.id
      and b.source='makeup' and l.lesson_type='makeup'
      and b.student_user_id=p_right.student_user_id
      and b.teacher_user_id=p_right.current_teacher_user_id
  ) then
    raise exception using errcode='P0001',message='MAKEUP_BOOKING_BINDING_MISMATCH';
  end if;
  linked_after:=to_jsonb(p_right)||jsonb_build_object(
    'booking_id',p_booking_id,'lesson_id',p_lesson_id,
    'student_user_id',p_right.student_user_id,
    'teacher_user_id',p_right.current_teacher_user_id
  );
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(
    p_actor_user_id,'makeup_right.'||p_operation_type::text,'makeup_right',p_right.id,
    coalesce(p_before_snapshot,'{}'::jsonb),linked_after,trim(p_reason)
  ) returning id into audit_id;
  insert into public.makeup_right_operations(
    makeup_right_id,operation_type,operation_key,actor_user_id,reason,
    from_status,to_status,before_snapshot,after_snapshot,audit_log_id,
    booking_id,lesson_id
  ) values(
    p_right.id,p_operation_type,p_operation_key,p_actor_user_id,trim(p_reason),
    p_from_status,p_right.status,coalesce(p_before_snapshot,'{}'::jsonb),linked_after,
    audit_id,p_booking_id,p_lesson_id
  ) returning id into operation_id;
  return operation_id;
end;
$$;

create or replace function public.create_makeup_lesson_booking(
  p_makeup_right_id uuid,p_student_user_id uuid,p_teacher_user_id uuid,
  p_relationship_id uuid,p_starts_at timestamptz,p_timezone text,
  p_idempotency_key text,p_reason text default 'Makeup lesson booking'
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); student_id uuid; actor_role public.app_role;
  right_before public.makeup_rights%rowtype; right_changed public.makeup_rights%rowtype;
  origin_lesson public.lessons%rowtype; teacher public.teacher_profiles%rowtype;
  relation public.student_teacher_relationships%rowtype; existing public.bookings%rowtype;
  new_booking_id uuid:=gen_random_uuid(); new_lesson_id uuid:=gen_random_uuid();
  lesson_end timestamptz;
begin
  if caller is null or not private.current_user_is_active() then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  actor_role:=private.scheduling_actor_role(caller);
  if actor_role='student' then
    student_id:=caller;
    if p_student_user_id is distinct from caller then
      raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
    end if;
  elsif actor_role in('admin','super_admin') then
    student_id:=p_student_user_id;
  else
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if char_length(coalesce(p_idempotency_key,'')) not between 16 and 160
    or not private.is_valid_iana_timezone(p_timezone)
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_BOOKING_REQUEST';
  end if;
  if not exists(select 1 from public.profiles p join public.user_roles r on r.user_id=p.user_id
    where p.user_id=student_id and p.account_status='active' and r.role='student') then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'the-one:v1:booking:idempotency:'||student_id::text||':'||p_idempotency_key,6));
  select * into existing from public.bookings
    where student_user_id=student_id and idempotency_key=p_idempotency_key;
  if found then
    if existing.source<>'makeup' or existing.makeup_right_id<>p_makeup_right_id
      or existing.teacher_user_id<>p_teacher_user_id
      or existing.relationship_id<>p_relationship_id
      or existing.starts_at<>p_starts_at or existing.timezone_anchor<>p_timezone then
      raise exception using errcode='P0001',message='BOOKING_ALREADY_EXISTS';
    end if;
    return existing.id;
  end if;
  select * into right_before from public.makeup_rights
    where id=p_makeup_right_id for update;
  if not found or right_before.student_user_id<>student_id
    or right_before.current_teacher_user_id<>p_teacher_user_id then
    raise exception using errcode='42501',message='UNAUTHORIZED_MAKEUP_ACTION';
  end if;
  if right_before.status<>'available' then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_AVAILABLE';
  end if;
  if right_before.valid_until<=now() or p_starts_at>right_before.valid_until then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_EXPIRED';
  end if;
  select * into relation from public.student_teacher_relationships where id=p_relationship_id;
  if not found or relation.student_user_id<>student_id
    or relation.teacher_user_id<>p_teacher_user_id
    or relation.relationship_status<>'active' then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if not private.teacher_owner_is_active(p_teacher_user_id) then
    raise exception using errcode='P0001',message='TEACHER_SCHEDULE_CONFLICT';
  end if;
  select * into origin_lesson from public.lessons where id=right_before.origin_lesson_id;
  select * into teacher from public.teacher_profiles where user_id=p_teacher_user_id;
  if origin_lesson.id is null or teacher.user_id is null or teacher.teaching_status<>'active' then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_ORIGIN_MISMATCH';
  end if;
  lesson_end:=p_starts_at+make_interval(mins=>origin_lesson.duration_minutes);
  perform private.lock_lesson_schedule_resources(student_id,p_teacher_user_id);
  if not private.flexible_slot_is_available(
    student_id,p_teacher_user_id,p_starts_at,origin_lesson.duration_minutes
  ) then
    raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
  end if;
  insert into public.lessons(
    id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
    starts_at,ends_at,duration_minutes,timezone_anchor,status,
    meeting_provider,meeting_url,location_text
  ) values(
    new_lesson_id,student_id,p_teacher_user_id,p_relationship_id,'makeup',relation.preferred_mode,
    p_starts_at,lesson_end,origin_lesson.duration_minutes,p_timezone,'scheduled',
    case when relation.preferred_mode='online' then teacher.default_meeting_provider end,
    case when relation.preferred_mode='online' then teacher.default_meeting_url end,
    case when relation.preferred_mode='onsite' then teacher.location_text end
  );
  insert into public.bookings(
    id,student_user_id,teacher_user_id,relationship_id,source,status,starts_at,ends_at,
    timezone_anchor,lesson_id,makeup_right_id,created_by,idempotency_key
  ) values(
    new_booking_id,student_id,p_teacher_user_id,p_relationship_id,'makeup','confirmed',
    p_starts_at,lesson_end,p_timezone,new_lesson_id,p_makeup_right_id,caller,p_idempotency_key
  );
  update public.makeup_rights set status='reserved',reserved_at=now(),reserved_by=caller,
    updated_at=now() where id=right_before.id and status='available'
    returning * into right_changed;
  if right_changed.id is null then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_AVAILABLE';
  end if;
  perform private.record_makeup_booking_operation(
    right_changed,'reserve','makeup-booking-reserve:'||new_booking_id::text,caller,p_reason,
    right_before.status,to_jsonb(right_before),new_booking_id,new_lesson_id
  );
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(caller,'makeup_booking.created','booking',new_booking_id,jsonb_build_object(
    'actor_role',actor_role,'makeup_right_id',right_changed.id,
    'student_user_id',student_id,'teacher_user_id',p_teacher_user_id,
    'lesson_id',new_lesson_id,'source','makeup','starts_at',p_starts_at,
    'ends_at',lesson_end),trim(p_reason));
  return new_booking_id;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
when unique_violation then
  raise exception using errcode='P0001',message='BOOKING_ALREADY_EXISTS';
end;
$$;

-- Preserve the already-applied ordinary authorities exactly and dispatch by the
-- persisted booking value source from new public wrappers.
alter function public.cancel_lesson_booking(
  uuid,public.booking_credit_outcome,text,text
) rename to cancel_ordinary_lesson_booking_authority;
alter function public.cancel_ordinary_lesson_booking_authority(
  uuid,public.booking_credit_outcome,text,text
) set schema private;

alter function public.reschedule_lesson_booking(uuid,timestamptz,text,text)
  rename to reschedule_ordinary_lesson_booking_authority;
alter function public.reschedule_ordinary_lesson_booking_authority(uuid,timestamptz,text,text)
  set schema private;

alter function public.complete_lesson_booking(uuid,text,text,text,text,text)
  rename to complete_ordinary_lesson_booking_authority;
alter function public.complete_ordinary_lesson_booking_authority(uuid,text,text,text,text,text)
  set schema private;

create or replace function private.cancel_makeup_lesson_booking_core(
  p_booking_id uuid,p_credit_outcome public.booking_credit_outcome,p_reason text,
  p_earning_outcome text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; b public.bookings%rowtype;
  lesson public.lessons%rowtype; right_before public.makeup_rights%rowtype;
  right_changed public.makeup_rights%rowtype; teacher_caused boolean;
begin
  if caller is null or not private.current_user_is_active()
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or char_length(coalesce(p_earning_outcome,'')) not between 1 and 100 then
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
  teacher_caused:=caller=b.teacher_user_id
    or (actor_role in('admin','super_admin') and p_earning_outcome='teacher_caused');
  if p_credit_outcome not in('released','unchanged') then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  select * into right_before from public.makeup_rights
    where id=b.makeup_right_id for update;
  perform private.lock_lesson_schedule_resources(b.student_user_id,b.teacher_user_id);
  select * into b from public.bookings where id=p_booking_id for update;
  select * into lesson from public.lessons where id=b.lesson_id for update;
  if b.status='cancelled' then return b.id; end if;
  if b.status not in('confirmed','rescheduled') or lesson.status<>'scheduled'
    or right_before.id is null or right_before.status<>'reserved'
    or right_before.student_user_id<>b.student_user_id
    or right_before.current_teacher_user_id<>b.teacher_user_id then
    raise exception using errcode='P0001',message='BOOKING_NOT_CANCELLABLE';
  end if;
  update public.makeup_rights set status='available',reserved_at=null,reserved_by=null,
    updated_at=now() where id=right_before.id and status='reserved'
    returning * into right_changed;
  perform private.record_makeup_booking_operation(
    right_changed,'restore','makeup-booking-restore:'||b.id::text,caller,p_reason,
    right_before.status,to_jsonb(right_before),b.id,lesson.id
  );
  update public.lessons set status=case
      when teacher_caused then 'teacher_cancelled'::public.lesson_status
      when actor_role in('admin','super_admin') then 'admin_cancelled'::public.lesson_status
      else 'student_cancelled'::public.lesson_status
    end,updated_at=now()
    where id=lesson.id and status='scheduled';
  update public.bookings set status='cancelled',cancelled_at=now(),
    cancellation_reason=trim(p_reason),cancellation_credit_outcome='released',
    earning_outcome=p_earning_outcome,updated_at=now() where id=b.id;
  insert into public.audit_logs(
    actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason
  ) values(caller,'makeup_booking.cancelled','booking',b.id,
    jsonb_build_object('status',b.status,'makeup_right_id',right_before.id,
      'lesson_id',lesson.id,'right_status',right_before.status),
    jsonb_build_object('status','cancelled','makeup_right_id',right_changed.id,
      'lesson_id',lesson.id,'right_status','available','teacher_caused',teacher_caused),trim(p_reason));
  return b.id;
end;
$$;

create or replace function public.cancel_lesson_booking(
  p_booking_id uuid,p_credit_outcome public.booking_credit_outcome,p_reason text,
  p_earning_outcome text default 'not_applicable'
) returns uuid language plpgsql security definer set search_path=''
as $$
declare source_kind public.booking_source;
begin
  select source into source_kind from public.bookings where id=p_booking_id;
  if source_kind='makeup' then
    return private.cancel_makeup_lesson_booking_core(
      p_booking_id,p_credit_outcome,p_reason,p_earning_outcome);
  end if;
  return private.cancel_ordinary_lesson_booking_authority(
    p_booking_id,p_credit_outcome,p_reason,p_earning_outcome);
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
  if b.status not in('confirmed','rescheduled') or lesson.status<>'scheduled'
    or right_locked.status<>'reserved' then
    raise exception using errcode='P0001',message='BOOKING_NOT_RESCHEDULABLE';
  end if;
  new_end:=p_new_starts_at+(b.ends_at-b.starts_at);
  if p_new_starts_at>right_locked.valid_until then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_EXPIRED';
  end if;
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
  ) values(caller,'makeup_booking.rescheduled','booking',b.id,
    jsonb_build_object('starts_at',b.starts_at,'ends_at',b.ends_at,
      'makeup_right_id',right_locked.id,'lesson_id',lesson.id),
    jsonb_build_object('starts_at',p_new_starts_at,'ends_at',new_end,
      'makeup_right_id',right_locked.id,'lesson_id',lesson.id),trim(p_reason));
  return b.id;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
end;
$$;

create or replace function public.reschedule_lesson_booking(
  p_booking_id uuid,p_new_starts_at timestamptz,p_timezone text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare source_kind public.booking_source;
begin
  select source into source_kind from public.bookings where id=p_booking_id;
  if source_kind='makeup' then
    return private.reschedule_makeup_lesson_booking_core(
      p_booking_id,p_new_starts_at,p_timezone,p_reason);
  end if;
  return private.reschedule_ordinary_lesson_booking_authority(
    p_booking_id,p_new_starts_at,p_timezone,p_reason);
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
    or not ((caller=b.teacher_user_id
      and private.scheduling_teacher_authorized(b.teacher_user_id))
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
  if b.status not in('confirmed','rescheduled') or lesson.status<>'scheduled'
    or lesson.starts_at>now() or lesson.starts_at>right_before.valid_until
    or right_before.status<>'reserved'
    or right_before.student_user_id<>b.student_user_id
    or right_before.current_teacher_user_id<>b.teacher_user_id then
    raise exception using errcode='P0001',message='BOOKING_NOT_COMPLETABLE';
  end if;
  update public.lessons set status='completed',updated_at=now() where id=lesson.id;
  insert into public.lesson_records(
    lesson_id,student_visible_notes,private_teacher_notes,performance_summary,
    next_goal,homework,completed_at,completed_by
  ) values(
    lesson.id,coalesce(p_student_visible_notes,''),coalesce(p_private_teacher_notes,''),
    coalesce(p_performance_summary,''),coalesce(p_next_goal,''),coalesce(p_homework,''),now(),caller
  ) on conflict(lesson_id) do nothing;
  update public.makeup_rights set status='used',used_at=now(),used_by=caller,updated_at=now()
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
  ) values(caller,'makeup_booking.completed','booking',b.id,
    jsonb_build_object('status',b.status,'makeup_right_id',right_before.id,
      'right_status',right_before.status,'lesson_id',lesson.id),
    jsonb_build_object('status','completed','makeup_right_id',right_changed.id,
      'right_status','used','lesson_id',lesson.id),'Makeup lesson completed');
  return lesson.id;
end;
$$;

create or replace function public.complete_lesson_booking(
  p_booking_id uuid,p_student_visible_notes text,p_private_teacher_notes text,
  p_performance_summary text,p_next_goal text,p_homework text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare source_kind public.booking_source;
begin
  select source into source_kind from public.bookings where id=p_booking_id;
  if source_kind='makeup' then
    return private.complete_makeup_lesson_booking_core(
      p_booking_id,p_student_visible_notes,p_private_teacher_notes,
      p_performance_summary,p_next_goal,p_homework);
  end if;
  return private.complete_ordinary_lesson_booking_authority(
    p_booking_id,p_student_visible_notes,p_private_teacher_notes,
    p_performance_summary,p_next_goal,p_homework);
end;
$$;

-- Preserve the generic P1-5B lifecycle for unbound Rights, while making an
-- active Booking the only authority allowed to restore, expire, revoke, or
-- consume a bound Right. Locking the Right before checking the binding closes
-- the check/use race with concurrent Booking creation.
alter function public.restore_makeup_right(uuid,text,text)
  rename to restore_unbound_makeup_right_authority;
alter function public.restore_unbound_makeup_right_authority(uuid,text,text)
  set schema private;
alter function public.expire_makeup_right(uuid,text,text)
  rename to expire_unbound_makeup_right_authority;
alter function public.expire_unbound_makeup_right_authority(uuid,text,text)
  set schema private;
alter function public.revoke_makeup_right(uuid,text,text)
  rename to revoke_unbound_makeup_right_authority;
alter function public.revoke_unbound_makeup_right_authority(uuid,text,text)
  set schema private;

create or replace function public.restore_makeup_right(
  p_makeup_right_id uuid,p_operation_key text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
begin
  perform 1 from public.makeup_rights where id=p_makeup_right_id for update;
  if exists(
    select 1 from public.bookings
    where makeup_right_id=p_makeup_right_id and status in('confirmed','rescheduled')
  ) then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_MANAGED_BY_BOOKING';
  end if;
  return private.restore_unbound_makeup_right_authority(
    p_makeup_right_id,p_operation_key,p_reason);
end;
$$;

create or replace function public.expire_makeup_right(
  p_makeup_right_id uuid,p_operation_key text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
begin
  perform 1 from public.makeup_rights where id=p_makeup_right_id for update;
  if exists(
    select 1 from public.bookings
    where makeup_right_id=p_makeup_right_id and status in('confirmed','rescheduled')
  ) then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_MANAGED_BY_BOOKING';
  end if;
  return private.expire_unbound_makeup_right_authority(
    p_makeup_right_id,p_operation_key,p_reason);
end;
$$;

create or replace function public.revoke_makeup_right(
  p_makeup_right_id uuid,p_operation_key text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
begin
  perform 1 from public.makeup_rights where id=p_makeup_right_id for update;
  if exists(
    select 1 from public.bookings
    where makeup_right_id=p_makeup_right_id and status in('confirmed','rescheduled')
  ) then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_MANAGED_BY_BOOKING';
  end if;
  return private.revoke_unbound_makeup_right_authority(
    p_makeup_right_id,p_operation_key,p_reason);
end;
$$;

-- Teachers cannot consume a Right outside assigned booking completion.
create or replace function public.consume_makeup_right(
  p_makeup_right_id uuid,p_operation_key text,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); before_right public.makeup_rights%rowtype;
  changed public.makeup_rights%rowtype; prior public.makeup_right_operations%rowtype;
begin
  if caller is null or not private.current_user_has_role(
    array['admin'::public.app_role,'super_admin'::public.app_role]) then
    raise exception using errcode='42501',message='UNAUTHORIZED_MAKEUP_ACTION';
  end if;
  if char_length(coalesce(p_operation_key,'')) not between 16 and 160
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_MAKEUP_OPERATION';
  end if;
  select * into before_right from public.makeup_rights where id=p_makeup_right_id for update;
  if not found then raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_FOUND'; end if;
  if exists(select 1 from public.bookings where makeup_right_id=before_right.id) then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_MANAGED_BY_BOOKING';
  end if;
  select * into prior from public.makeup_right_operations
    where makeup_right_id=p_makeup_right_id and operation_key=p_operation_key;
  if found then
    if prior.operation_type='consume' then return p_makeup_right_id; end if;
    raise exception using errcode='P0001',message='MAKEUP_OPERATION_KEY_CONFLICT';
  end if;
  if before_right.valid_until<=now() or before_right.status='expired' then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_EXPIRED';
  end if;
  if not private.makeup_status_transition_allowed(before_right.status,'used') then
    raise exception using errcode='P0001',message='MAKEUP_RIGHT_NOT_RESERVED';
  end if;
  update public.makeup_rights set status='used',used_at=now(),used_by=caller,updated_at=now()
    where id=p_makeup_right_id returning * into changed;
  perform private.record_makeup_right_operation(changed,'consume',p_operation_key,caller,p_reason,
    before_right.status,to_jsonb(before_right));
  return changed.id;
end;
$$;

alter function private.record_makeup_booking_operation(
  public.makeup_rights,public.makeup_right_operation_type,text,uuid,text,
  public.makeup_right_status,jsonb,uuid,uuid
) owner to postgres;
alter function public.create_makeup_lesson_booking(
  uuid,uuid,uuid,uuid,timestamptz,text,text,text
) owner to postgres;
alter function private.cancel_ordinary_lesson_booking_authority(
  uuid,public.booking_credit_outcome,text,text
) owner to postgres;
alter function private.reschedule_ordinary_lesson_booking_authority(
  uuid,timestamptz,text,text
) owner to postgres;
alter function private.complete_ordinary_lesson_booking_authority(
  uuid,text,text,text,text,text
) owner to postgres;
alter function private.cancel_makeup_lesson_booking_core(
  uuid,public.booking_credit_outcome,text,text
) owner to postgres;
alter function private.reschedule_makeup_lesson_booking_core(
  uuid,timestamptz,text,text
) owner to postgres;
alter function private.complete_makeup_lesson_booking_core(
  uuid,text,text,text,text,text
) owner to postgres;
alter function private.restore_unbound_makeup_right_authority(uuid,text,text) owner to postgres;
alter function private.expire_unbound_makeup_right_authority(uuid,text,text) owner to postgres;
alter function private.revoke_unbound_makeup_right_authority(uuid,text,text) owner to postgres;
alter function public.cancel_lesson_booking(
  uuid,public.booking_credit_outcome,text,text
) owner to postgres;
alter function public.reschedule_lesson_booking(uuid,timestamptz,text,text) owner to postgres;
alter function public.complete_lesson_booking(uuid,text,text,text,text,text) owner to postgres;
alter function public.restore_makeup_right(uuid,text,text) owner to postgres;
alter function public.expire_makeup_right(uuid,text,text) owner to postgres;
alter function public.revoke_makeup_right(uuid,text,text) owner to postgres;
alter function public.consume_makeup_right(uuid,text,text) owner to postgres;

revoke all on function private.record_makeup_booking_operation(
  public.makeup_rights,public.makeup_right_operation_type,text,uuid,text,
  public.makeup_right_status,jsonb,uuid,uuid
) from public,anon,authenticated,service_role;
revoke all on function private.cancel_ordinary_lesson_booking_authority(
  uuid,public.booking_credit_outcome,text,text
),private.reschedule_ordinary_lesson_booking_authority(uuid,timestamptz,text,text),
  private.complete_ordinary_lesson_booking_authority(uuid,text,text,text,text,text),
  private.cancel_makeup_lesson_booking_core(uuid,public.booking_credit_outcome,text,text),
  private.reschedule_makeup_lesson_booking_core(uuid,timestamptz,text,text),
  private.complete_makeup_lesson_booking_core(uuid,text,text,text,text,text),
  private.restore_unbound_makeup_right_authority(uuid,text,text),
  private.expire_unbound_makeup_right_authority(uuid,text,text),
  private.revoke_unbound_makeup_right_authority(uuid,text,text)
from public,anon,authenticated,service_role;

revoke all on function public.create_makeup_lesson_booking(
  uuid,uuid,uuid,uuid,timestamptz,text,text,text
),public.cancel_lesson_booking(uuid,public.booking_credit_outcome,text,text),
  public.reschedule_lesson_booking(uuid,timestamptz,text,text),
  public.complete_lesson_booking(uuid,text,text,text,text,text),
  public.restore_makeup_right(uuid,text,text),
  public.expire_makeup_right(uuid,text,text),
  public.revoke_makeup_right(uuid,text,text),
  public.consume_makeup_right(uuid,text,text)
from public,anon,authenticated,service_role;

grant execute on function public.create_makeup_lesson_booking(
  uuid,uuid,uuid,uuid,timestamptz,text,text,text
),public.cancel_lesson_booking(uuid,public.booking_credit_outcome,text,text),
  public.reschedule_lesson_booking(uuid,timestamptz,text,text),
  public.complete_lesson_booking(uuid,text,text,text,text,text),
  public.restore_makeup_right(uuid,text,text),
  public.expire_makeup_right(uuid,text,text),
  public.revoke_makeup_right(uuid,text,text),
  public.consume_makeup_right(uuid,text,text)
to authenticated;

comment on table public.bookings is
  'Scheduling commitment linked one-to-one with a Lesson and explicitly funded by either an ordinary credit reservation or a Makeup Right.';

commit;
