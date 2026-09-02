begin;

-- Keep the existing physical collision checks as an internal primitive.
create or replace function private.scheduling_instance_slot_clear(
  p_student_user_id uuid,p_teacher_user_id uuid,p_starts_at timestamptz,p_ends_at timestamptz,
  p_ignore_lesson_id uuid default null,p_ignore_occurrence_id uuid default null
) returns boolean language sql stable security definer set search_path=''
as $$
  select not exists(
      select 1 from public.teacher_availability_exceptions x
      where x.teacher_user_id=p_teacher_user_id and x.exception_kind='unavailable'
        and tstzrange(x.starts_at,x.ends_at,'[)')&&tstzrange(p_starts_at,p_ends_at,'[)')
    ) and not exists(
      select 1 from public.lessons l
      where l.id is distinct from p_ignore_lesson_id and l.status='scheduled'
        and (l.student_user_id=p_student_user_id or l.teacher_user_id=p_teacher_user_id)
        and tstzrange(l.starts_at,l.ends_at,'[)')&&tstzrange(p_starts_at,p_ends_at,'[)')
    ) and not exists(
      select 1 from public.recurring_lesson_occurrences o
      where o.id is distinct from p_ignore_occurrence_id
        and o.status in('planned','credit_required','materialized')
        and (o.student_user_id=p_student_user_id or o.teacher_user_id=p_teacher_user_id)
        and tstzrange(o.starts_at,o.ends_at,'[)')&&tstzrange(p_starts_at,p_ends_at,'[)')
    );
$$;


-- Read-only target-window authority. Persisted occurrences supersede their base
-- dates, including release/skip, reschedule, materialization and resolver failures.
create or replace function private.unexpanded_fixed_priority_clear(
  p_student_user_id uuid,p_teacher_user_id uuid,p_starts_at timestamptz,p_ends_at timestamptz,
  p_ignore_series_id uuid default null,p_ignore_occurrence_date date default null
) returns boolean language plpgsql stable security definer set search_path=''
as $$
declare s public.recurring_lesson_series%rowtype; candidate_date date;
  occurrence_start timestamptz; occurrence_end timestamptz;
begin
  if p_starts_at is null or p_ends_at is null or p_ends_at<=p_starts_at then return false; end if;
  for s in
    select series.* from public.recurring_lesson_series series
    where series.status='active'
      and (series.teacher_user_id=p_teacher_user_id or series.student_user_id=p_student_user_id)
      and series.effective_from<=(p_ends_at at time zone series.timezone)::date
      and (series.effective_until is null
        or series.effective_until>=(p_starts_at at time zone series.timezone)::date-1)
  loop
    -- Include the preceding local date for an interval crossing midnight.
    -- Work is bounded by the candidate interval, not the series lifetime/horizon.
    for candidate_date in
      select day::date from generate_series(
        greatest(s.effective_from,(p_starts_at at time zone s.timezone)::date-1),
        least(coalesce(s.effective_until,(p_ends_at at time zone s.timezone)::date),
          (p_ends_at at time zone s.timezone)::date),interval '1 day') day
      where extract(dow from day)::smallint=s.weekday
    loop
      if s.id=p_ignore_series_id and candidate_date=p_ignore_occurrence_date then continue; end if;
      if exists(select 1 from public.recurring_lesson_occurrences o
        where o.series_id=s.id and o.occurrence_date=candidate_date) then continue; end if;
      begin
        occurrence_start:=private.resolve_scheduling_local_datetime(candidate_date,s.local_start_time,s.timezone);
      exception when sqlstate 'P0001' then
        -- Match ensure's existing failed-occurrence semantics for invalid wall times.
        if sqlerrm in('AMBIGUOUS_LOCAL_TIME','NONEXISTENT_LOCAL_TIME') then continue; else raise; end if;
      end;
      occurrence_end:=occurrence_start+make_interval(mins=>s.duration_minutes);
      if tstzrange(occurrence_start,occurrence_end,'[)')&&tstzrange(p_starts_at,p_ends_at,'[)') then
        return false;
      end if;
    end loop;
  end loop;
  return true;
end;
$$;

create or replace function private.scheduling_slot_clear(
  p_student_user_id uuid,p_teacher_user_id uuid,p_starts_at timestamptz,p_ends_at timestamptz,
  p_ignore_lesson_id uuid default null,p_ignore_occurrence_id uuid default null
) returns boolean language sql stable security definer set search_path=''
as $$
  select private.scheduling_instance_slot_clear(
    p_student_user_id,p_teacher_user_id,p_starts_at,p_ends_at,p_ignore_lesson_id,p_ignore_occurrence_id
  ) and private.unexpanded_fixed_priority_clear(
    p_student_user_id,p_teacher_user_id,p_starts_at,p_ends_at
  );
$$;

-- Expansion must not collide with its own unexpanded logical date.
create or replace function private.ensure_recurring_occurrences(
  p_series_id uuid,p_through_date date
) returns integer language plpgsql security definer set search_path=''
as $$
declare s public.recurring_lesson_series%rowtype; settings public.teacher_scheduling_settings%rowtype;
  existing_occurrence public.recurring_lesson_occurrences%rowtype;
  candidate_date date; occurrence_start timestamptz; occurrence_end timestamptz; inserted_count integer:=0;
begin
  select * into s from public.recurring_lesson_series where id=p_series_id for update;
  if not found or s.status='ended' then raise exception using errcode='P0001',message='RECURRING_SERIES_INACTIVE'; end if;
  select * into settings from public.teacher_scheduling_settings where teacher_user_id=s.teacher_user_id;
  if not found then raise exception using errcode='P0001',message='SCHEDULING_SETTINGS_REQUIRED'; end if;
  for candidate_date in
    select day::date from generate_series(
      greatest(s.effective_from,current_date),
      least(coalesce(s.effective_until,current_date+settings.booking_horizon_days),
        least(p_through_date,current_date+settings.booking_horizon_days)),interval '1 day') day
    where extract(dow from day)::smallint=s.weekday
  loop
    begin
      -- The schema's unique(series_id, occurrence_date) is the logical identity.
      select o.* into existing_occurrence from public.recurring_lesson_occurrences o
      where o.series_id=s.id and o.occurrence_date=candidate_date for update;
      if found then
        -- A rescheduled occurrence owns its persisted range, not the base time.
        -- Materialization also creates its own Lesson; ignore only that link.
        if existing_occurrence.status in('planned','credit_required','materialized')
          and existing_occurrence.starts_at is not null then
          if not private.scheduling_slot_clear(
            s.student_user_id,s.teacher_user_id,existing_occurrence.starts_at,existing_occurrence.ends_at,
            case when existing_occurrence.status='materialized' then existing_occurrence.lesson_id else null end,
            existing_occurrence.id
          ) then
            raise exception using errcode='P0001',message='RECURRING_SERIES_CONFLICT';
          end if;
        end if;
        -- Keep every existing state, exception and binding unchanged. Released,
        -- skipped and failed rows must not regain priority during refresh.
        continue;
      end if;

      occurrence_start:=private.resolve_scheduling_local_datetime(candidate_date,s.local_start_time,s.timezone);
      occurrence_end:=occurrence_start+make_interval(mins=>s.duration_minutes);
      -- Ignore only this as-yet-uninserted logical date, never the entire series.
      if not private.scheduling_instance_slot_clear(s.student_user_id,s.teacher_user_id,occurrence_start,occurrence_end,null,null)
        or not private.unexpanded_fixed_priority_clear(
          s.student_user_id,s.teacher_user_id,occurrence_start,occurrence_end,s.id,candidate_date
        ) then
        raise exception using errcode='P0001',message='RECURRING_SERIES_CONFLICT';
      end if;
      insert into public.recurring_lesson_occurrences(
        series_id,student_user_id,teacher_user_id,occurrence_date,starts_at,ends_at,status
      ) values(s.id,s.student_user_id,s.teacher_user_id,candidate_date,occurrence_start,occurrence_end,'planned')
      on conflict on constraint recurring_lesson_occurrences_series_id_occurrence_date_key do nothing;
      if found then inserted_count:=inserted_count+1; end if;
    exception when sqlstate 'P0001' then
      if sqlerrm in('AMBIGUOUS_LOCAL_TIME','NONEXISTENT_LOCAL_TIME') then
        insert into public.recurring_lesson_occurrences(
          series_id,student_user_id,teacher_user_id,occurrence_date,status,error_code
        ) values(s.id,s.student_user_id,s.teacher_user_id,candidate_date,'failed',sqlerrm)
        on conflict on constraint recurring_lesson_occurrences_series_id_occurrence_date_key do nothing;
      else raise; end if;
    end;
  end loop;
  return inserted_count;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='RECURRING_SERIES_CONFLICT';
end;
$$;


-- New helpers stay internal; existing function ACLs survive CREATE OR REPLACE.
alter function private.scheduling_instance_slot_clear(uuid,uuid,timestamptz,timestamptz,uuid,uuid) owner to postgres;
alter function private.unexpanded_fixed_priority_clear(uuid,uuid,timestamptz,timestamptz,uuid,date) owner to postgres;
revoke all on function private.scheduling_instance_slot_clear(uuid,uuid,timestamptz,timestamptz,uuid,uuid),
  private.unexpanded_fixed_priority_clear(uuid,uuid,timestamptz,timestamptz,uuid,date)
from public,anon,authenticated,service_role;

commit;
