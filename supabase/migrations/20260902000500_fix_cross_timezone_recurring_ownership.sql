begin;

-- Admission checks every weekly date in a bounded window, not a sample offset.
-- Each pair starts at its effective intersection (even beyond today's expansion)
-- and checks up to the maximum supported scheduling horizon, 366 days. This is
-- not a lifetime certificate: the target-window checks in scheduling_slot_clear
-- and ensure_recurring_occurrences remain authoritative as time advances.
create or replace function private.recurring_ownership_clear(
  p_student_user_id uuid,p_teacher_user_id uuid,p_weekday smallint,
  p_local_start_time time,p_timezone text,p_duration_minutes smallint,
  p_effective_from date,p_effective_until date
) returns boolean language plpgsql stable security definer set search_path=''
as $$
declare s public.recurring_lesson_series%rowtype; o record;
  window_from date; window_until date; candidate_date date; existing_date date;
  candidate_start timestamptz; candidate_end timestamptz; existing_start timestamptz;
begin
  -- Concrete priority takes precedence, including reschedules outside the base
  -- effective range and materialized occurrences belonging to ended series.
  for o in select starts_at,ends_at from public.recurring_lesson_occurrences
    where status in('planned','credit_required','materialized') and starts_at is not null
      and (teacher_user_id=p_teacher_user_id or student_user_id=p_student_user_id)
  loop
    window_from:=greatest(p_effective_from,current_date,(o.starts_at at time zone p_timezone)::date-1);
    window_until:=least(coalesce(p_effective_until,'infinity'::date),(o.ends_at at time zone p_timezone)::date);
    for candidate_date in
      select window_from+i from generate_series(0,window_until-window_from) i
      where extract(dow from window_from+i)::smallint=p_weekday
    loop
      begin
        candidate_start:=private.resolve_scheduling_local_datetime(candidate_date,p_local_start_time,p_timezone);
      exception when sqlstate 'P0001' then
        if sqlerrm in('AMBIGUOUS_LOCAL_TIME','NONEXISTENT_LOCAL_TIME') then continue; else raise; end if;
      end;
      if tstzrange(candidate_start,candidate_start+make_interval(mins=>p_duration_minutes),'[)')
        &&tstzrange(o.starts_at,o.ends_at,'[)') then return false; end if;
    end loop;
  end loop;

  -- Preserve create-series ownership for active AND paused series. Pausing does
  -- not surrender Fixed ownership; ended series have only concrete-row authority.
  for s in select * from public.recurring_lesson_series
    where status in('active','paused')
      and (teacher_user_id=p_teacher_user_id or student_user_id=p_student_user_id)
  loop
    -- Convert the effective calendar boundaries before narrowing dates. Calendar
    -- dates can differ across timezones even when their actual intervals overlap.
    window_from:=greatest(p_effective_from,current_date,
      ((s.effective_from::timestamp at time zone s.timezone) at time zone p_timezone)::date-1);
    window_until:=least(coalesce(p_effective_until,'infinity'::date),window_from+366);
    if s.effective_until is not null and isfinite(s.effective_until) then
      window_until:=least(window_until,
        (((s.effective_until+1)::timestamp at time zone s.timezone) at time zone p_timezone)::date);
    end if;
    for candidate_date in
      select window_from+i from generate_series(0,window_until-window_from) i
      where extract(dow from window_from+i)::smallint=p_weekday
    loop
      begin
        candidate_start:=private.resolve_scheduling_local_datetime(candidate_date,p_local_start_time,p_timezone);
      exception when sqlstate 'P0001' then
        if sqlerrm in('AMBIGUOUS_LOCAL_TIME','NONEXISTENT_LOCAL_TIME') then continue; else raise; end if;
      end;
      candidate_end:=candidate_start+make_interval(mins=>p_duration_minutes);
      -- Same bounded target-interval semantics as unexpanded_fixed_priority_clear.
      for existing_date in
        select d::date from generate_series(
          greatest(s.effective_from,(candidate_start at time zone s.timezone)::date-1),
          least(coalesce(s.effective_until,'infinity'::date),(candidate_end at time zone s.timezone)::date),
          interval '1 day') d where extract(dow from d)::smallint=s.weekday
      loop
        if exists(select 1 from public.recurring_lesson_occurrences
          where series_id=s.id and occurrence_date=existing_date) then continue; end if;
        begin
          existing_start:=private.resolve_scheduling_local_datetime(existing_date,s.local_start_time,s.timezone);
        exception when sqlstate 'P0001' then
          if sqlerrm in('AMBIGUOUS_LOCAL_TIME','NONEXISTENT_LOCAL_TIME') then continue; else raise; end if;
        end;
        if tstzrange(candidate_start,candidate_end,'[)')
          &&tstzrange(existing_start,existing_start+make_interval(mins=>s.duration_minutes),'[)') then
          return false;
        end if;
      end loop;
    end loop;
  end loop;
  return true;
end;
$$;

alter function private.recurring_ownership_clear(uuid,uuid,smallint,time,text,smallint,date,date) owner to postgres;
revoke all on function private.recurring_ownership_clear(uuid,uuid,smallint,time,text,smallint,date,date)
  from public,anon,authenticated,service_role;

create or replace function public.create_recurring_lesson_series(
  p_student_user_id uuid,p_teacher_user_id uuid,p_relationship_id uuid,
  p_preferred_entitlement_id uuid,p_weekday smallint,p_local_start_time time,
  p_timezone text,p_duration_minutes smallint,p_effective_from date,p_effective_until date,
  p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; settings public.teacher_scheduling_settings%rowtype;
  result_id uuid; new_end_time time;
begin
  actor_role:=private.scheduling_actor_role(caller);
  if caller is null or not private.scheduling_teacher_authorized(p_teacher_user_id)
    or actor_role not in('teacher','admin','super_admin') then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  select * into settings from public.teacher_scheduling_settings where teacher_user_id=p_teacher_user_id;
  if not found or settings.timezone<>p_timezone or p_weekday not between 0 and 6
    or p_duration_minutes not between 1 and 480 or p_effective_from is null
    or p_effective_until<p_effective_from
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_RECURRING_SERIES';
  end if;
  if not private.scheduling_relationship_is_active(p_relationship_id,p_student_user_id,p_teacher_user_id) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if p_preferred_entitlement_id is not null and not exists(
    select 1 from public.entitlements e where e.id=p_preferred_entitlement_id
      and e.beneficiary_user_id=p_student_user_id and e.entitlement_type='lesson_package'
      and e.booking_mode_eligibility in('fixed','both')
      and (e.teacher_scope_user_id is null or e.teacher_scope_user_id=p_teacher_user_id)
  ) then raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ELIGIBLE'; end if;
  new_end_time:=p_local_start_time+make_interval(mins=>p_duration_minutes);
  if new_end_time<=p_local_start_time then
    raise exception using errcode='22023',message='OVERNIGHT_RECURRING_SERIES_UNSUPPORTED';
  end if;
  perform private.lock_lesson_schedule_resources(p_student_user_id,p_teacher_user_id);
  if not private.recurring_ownership_clear(
    p_student_user_id,p_teacher_user_id,p_weekday,p_local_start_time,p_timezone,
    p_duration_minutes,p_effective_from,p_effective_until
  ) then raise exception using errcode='P0001',message='RECURRING_SERIES_CONFLICT'; end if;
  insert into public.recurring_lesson_series(
    student_user_id,teacher_user_id,relationship_id,preferred_entitlement_id,weekday,
    local_start_time,timezone,duration_minutes,effective_from,effective_until,created_by
  ) values(p_student_user_id,p_teacher_user_id,p_relationship_id,p_preferred_entitlement_id,
    p_weekday,p_local_start_time,p_timezone,p_duration_minutes,p_effective_from,p_effective_until,caller)
  returning id into result_id;
  perform private.ensure_recurring_occurrences(result_id,current_date+settings.booking_horizon_days);
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(caller,'recurring_series.created','recurring_lesson_series',result_id,jsonb_build_object(
    'actor_role',actor_role,'student_user_id',p_student_user_id,'teacher_user_id',p_teacher_user_id,
    'weekday',p_weekday,'local_start_time',p_local_start_time,'timezone',p_timezone,
    'duration_minutes',p_duration_minutes,'effective_from',p_effective_from,
    'effective_until',p_effective_until,'preferred_entitlement_id',p_preferred_entitlement_id),trim(p_reason));
  return result_id;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='RECURRING_SERIES_CONFLICT';
end;
$$;


commit;
