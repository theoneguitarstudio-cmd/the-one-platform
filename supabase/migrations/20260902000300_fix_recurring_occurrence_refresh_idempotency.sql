begin;

-- Preserve the existing owner/ACL and the wrapper's schedule-resource locks.
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
      if not private.scheduling_slot_clear(s.student_user_id,s.teacher_user_id,occurrence_start,occurrence_end,null,null) then
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

commit;
