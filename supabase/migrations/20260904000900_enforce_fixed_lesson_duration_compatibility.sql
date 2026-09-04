begin;

create or replace function private.validate_lesson_duration_compatibility(
  p_entitlement_id uuid,
  p_target_duration_minutes integer
) returns void
language plpgsql
stable
security definer
set search_path=''
as $$
declare entitlement_duration integer;
begin
  select e.lesson_duration_minutes into entitlement_duration
  from public.entitlements e
  where e.id=p_entitlement_id and e.entitlement_type='lesson_package';

  if not found then
    raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ELIGIBLE';
  end if;
  if entitlement_duration is distinct from p_target_duration_minutes then
    raise exception using errcode='P0001',message='LESSON_DURATION_MISMATCH';
  end if;
end;
$$;

create or replace function public.materialize_recurring_lesson_occurrence(
  p_series_id uuid,p_occurrence_date date,p_entitlement_id uuid,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; s public.recurring_lesson_series%rowtype;
  o public.recurring_lesson_occurrences%rowtype; ent public.entitlements%rowtype;
  relation public.student_teacher_relationships%rowtype; teacher public.teacher_profiles%rowtype;
  new_booking_id uuid:=gen_random_uuid(); new_lesson_id uuid:=gen_random_uuid(); reservation_id uuid;
begin
  select * into s from public.recurring_lesson_series where id=p_series_id;
  actor_role:=private.scheduling_actor_role(caller);
  if not found or caller is null or not private.scheduling_teacher_authorized(s.teacher_user_id)
    or actor_role not in('teacher','admin','super_admin') then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if char_length(coalesce(p_idempotency_key,'')) not between 16 and 160 then
    raise exception using errcode='22023',message='INVALID_BOOKING_REQUEST';
  end if;
  perform private.lock_lesson_schedule_resources(s.student_user_id,s.teacher_user_id);
  select * into o from public.recurring_lesson_occurrences
    where series_id=s.id and occurrence_date=p_occurrence_date;
  if not found then raise exception using errcode='P0001',message='OCCURRENCE_NOT_FOUND'; end if;
  if o.status='materialized' then return o.booking_id; end if;
  if s.status<>'active' then raise exception using errcode='P0001',message='RECURRING_SERIES_INACTIVE'; end if;
  if o.status in('released','skipped','failed') then
    raise exception using errcode='P0001',message='OCCURRENCE_NOT_MATERIALIZABLE';
  end if;
  if p_entitlement_id is null or not private.scheduling_entitlement_eligible(
    p_entitlement_id,s.student_user_id,s.teacher_user_id,'fixed') then
    select * into s from public.recurring_lesson_series where id=p_series_id for update;
    select * into o from public.recurring_lesson_occurrences
      where series_id=s.id and occurrence_date=p_occurrence_date for update;
    if o.status='materialized' then return o.booking_id; end if;
    update public.recurring_lesson_occurrences set status='credit_required',
      error_code='CREDIT_REQUIRED',updated_at=now() where id=o.id;
    insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
    values(caller,'recurring_occurrence.credit_required','recurring_lesson_occurrence',o.id,
      jsonb_build_object('series_id',s.id,'occurrence_date',o.occurrence_date,'actor_role',actor_role),
      'Eligible explicit entitlement is required');
    return null;
  end if;

  -- Preserve the established schedule/value lock order, then validate the
  -- immutable purchase-time Entitlement snapshot before any value mutation.
  select * into ent from public.entitlements where id=p_entitlement_id for update;
  select * into s from public.recurring_lesson_series where id=p_series_id for update;
  select * into o from public.recurring_lesson_occurrences
    where series_id=s.id and occurrence_date=p_occurrence_date for update;
  if o.status='materialized' then return o.booking_id; end if;
  if s.status<>'active' or o.status in('released','skipped','failed') then
    raise exception using errcode='P0001',message='OCCURRENCE_NOT_MATERIALIZABLE';
  end if;
  if not private.scheduling_entitlement_eligible(
    p_entitlement_id,s.student_user_id,s.teacher_user_id,'fixed') then
    raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ELIGIBLE';
  end if;
  if o.starts_at is null or o.ends_at is distinct from
    o.starts_at+make_interval(mins=>s.duration_minutes) then
    raise exception using errcode='P0001',message='LESSON_DURATION_MISMATCH';
  end if;
  perform private.validate_lesson_duration_compatibility(ent.id,s.duration_minutes);

  if not private.scheduling_slot_clear(s.student_user_id,s.teacher_user_id,o.starts_at,o.ends_at,null,o.id) then
    raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
  end if;
  select * into relation from public.student_teacher_relationships where id=s.relationship_id;
  select * into teacher from public.teacher_profiles where user_id=s.teacher_user_id;
  if relation.relationship_status<>'active' or teacher.teaching_status<>'active' then
    raise exception using errcode='P0001',message='RECURRING_SERIES_INACTIVE';
  end if;
  insert into public.lessons(
    id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
    starts_at,ends_at,duration_minutes,timezone_anchor,status,
    meeting_provider,meeting_url,location_text
  ) values(new_lesson_id,s.student_user_id,s.teacher_user_id,s.relationship_id,'fixed',relation.preferred_mode,
    o.starts_at,o.ends_at,s.duration_minutes,s.timezone,'scheduled',
    case when relation.preferred_mode='online' then teacher.default_meeting_provider end,
    case when relation.preferred_mode='online' then teacher.default_meeting_url end,
    case when relation.preferred_mode='onsite' then teacher.location_text end);
  reservation_id:=private.reserve_lesson_credit_core(p_entitlement_id,s.student_user_id,
    'booking:'||p_idempotency_key,new_lesson_id,new_booking_id::text,caller);
  insert into public.bookings(
    id,student_user_id,teacher_user_id,relationship_id,source,status,starts_at,ends_at,
    timezone_anchor,lesson_id,credit_reservation_id,recurring_series_id,occurrence_date,
    created_by,idempotency_key
  ) values(new_booking_id,s.student_user_id,s.teacher_user_id,s.relationship_id,'fixed','confirmed',
    o.starts_at,o.ends_at,s.timezone,new_lesson_id,reservation_id,s.id,o.occurrence_date,caller,p_idempotency_key);
  perform private.bind_lesson_credit_reservation_booking_core(
    reservation_id,new_booking_id,s.student_user_id,p_entitlement_id,new_lesson_id);
  update public.recurring_lesson_occurrences o2 set status='materialized',booking_id=new_booking_id,
    lesson_id=new_lesson_id,error_code=null,updated_at=now() where id=o.id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(caller,'recurring_occurrence.materialized','booking',new_booking_id,jsonb_build_object(
    'series_id',s.id,'occurrence_id',o.id,'occurrence_date',o.occurrence_date,
    'lesson_id',new_lesson_id,'credit_reservation_id',reservation_id,'actor_role',actor_role),
    'Fixed recurring occurrence materialization');
  return new_booking_id;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
when unique_violation then
  select occurrence.booking_id into new_booking_id from public.recurring_lesson_occurrences occurrence
    where occurrence.series_id=p_series_id and occurrence.occurrence_date=p_occurrence_date;
  if new_booking_id is not null then return new_booking_id; end if;
  raise exception using errcode='P0001',message='OCCURRENCE_ALREADY_MATERIALIZED';
end;
$$;

alter function private.validate_lesson_duration_compatibility(uuid,integer) owner to postgres;
alter function public.materialize_recurring_lesson_occurrence(uuid,date,uuid,text) owner to postgres;

revoke all on function private.validate_lesson_duration_compatibility(uuid,integer)
from public,anon,authenticated,service_role;
revoke all on function public.materialize_recurring_lesson_occurrence(uuid,date,uuid,text)
from public,anon,authenticated,service_role;
grant execute on function public.materialize_recurring_lesson_occurrence(uuid,date,uuid,text)
to authenticated;

commit;
