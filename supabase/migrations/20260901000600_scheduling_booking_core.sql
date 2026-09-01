begin;

create type public.availability_exception_kind as enum ('unavailable','opening');
create type public.booking_source as enum ('flexible','fixed');
create type public.booking_status as enum (
  'confirmed','cancelled','rescheduled','completed','credit_required','failed'
);
create type public.booking_credit_outcome as enum (
  'released','consumed','unchanged','manual_review_required'
);
create type public.recurring_series_status as enum ('active','paused','ended');
create type public.recurring_occurrence_status as enum (
  'planned','credit_required','materialized','released','skipped','failed'
);
create type public.recurring_series_exception_kind as enum (
  'cancel','reschedule','release','teacher_unavailable','student_leave','skip_holiday'
);

create table public.teacher_scheduling_settings (
  teacher_user_id uuid primary key references auth.users(id) on delete restrict,
  timezone text not null,
  minimum_booking_notice_minutes integer not null default 1440
    check (minimum_booking_notice_minutes between 0 and 43200),
  booking_horizon_days integer not null default 60
    check (booking_horizon_days between 1 and 366),
  slot_interval_minutes integer not null default 10
    check (slot_interval_minutes between 5 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.teacher_availability_rules (
  id uuid primary key default gen_random_uuid(),
  teacher_user_id uuid not null references auth.users(id) on delete restrict,
  weekday smallint not null check (weekday between 0 and 6),
  local_start_time time not null,
  local_end_time time not null,
  timezone text not null,
  effective_from date not null,
  effective_until date,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (local_start_time < local_end_time),
  check (effective_until is null or effective_until >= effective_from)
);

create table public.teacher_availability_exceptions (
  id uuid primary key default gen_random_uuid(),
  teacher_user_id uuid not null references auth.users(id) on delete restrict,
  exception_kind public.availability_exception_kind not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text not null check (char_length(reason) between 3 and 1000),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (starts_at < ends_at)
);

create table public.recurring_lesson_series (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references auth.users(id) on delete restrict,
  teacher_user_id uuid not null references auth.users(id) on delete restrict,
  relationship_id uuid not null,
  preferred_entitlement_id uuid references public.entitlements(id) on delete restrict,
  weekday smallint not null check (weekday between 0 and 6),
  local_start_time time not null,
  timezone text not null,
  duration_minutes smallint not null check (duration_minutes between 1 and 480),
  effective_from date not null,
  effective_until date,
  status public.recurring_series_status not null default 'active',
  created_by uuid not null references auth.users(id) on delete restrict,
  paused_at timestamptz,
  ended_at timestamptz,
  lifecycle_reason text check (lifecycle_reason is null or char_length(lifecycle_reason) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (student_user_id <> teacher_user_id),
  check (effective_until is null or effective_until >= effective_from),
  check (
    (status='active' and ended_at is null)
    or (status='paused' and paused_at is not null and ended_at is null)
    or (status='ended' and ended_at is not null)
  ),
  foreign key(relationship_id,student_user_id,teacher_user_id)
    references public.student_teacher_relationships(id,student_user_id,teacher_user_id)
    on delete restrict
);

create table public.recurring_lesson_occurrences (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.recurring_lesson_series(id) on delete restrict,
  student_user_id uuid not null references auth.users(id) on delete restrict,
  teacher_user_id uuid not null references auth.users(id) on delete restrict,
  occurrence_date date not null,
  starts_at timestamptz,
  ends_at timestamptz,
  status public.recurring_occurrence_status not null default 'planned',
  booking_id uuid,
  lesson_id uuid references public.lessons(id) on delete restrict,
  error_code text check (error_code is null or char_length(error_code) <= 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((starts_at is null) = (ends_at is null)),
  check (starts_at is null or starts_at < ends_at),
  check ((status='failed' and error_code is not null) or status<>'failed'),
  unique(series_id,occurrence_date),
  unique(booking_id),
  unique(lesson_id)
);

create table public.recurring_lesson_series_exceptions (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.recurring_lesson_series(id) on delete restrict,
  occurrence_date date not null,
  exception_kind public.recurring_series_exception_kind not null,
  replacement_starts_at timestamptz,
  replacement_ends_at timestamptz,
  release_this_occurrence boolean not null default false,
  reason text not null check (char_length(reason) between 3 and 1000),
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  actor_role public.app_role not null,
  created_at timestamptz not null default now(),
  check ((replacement_starts_at is null) = (replacement_ends_at is null)),
  check (replacement_starts_at is null or replacement_starts_at < replacement_ends_at),
  check (exception_kind='reschedule' or replacement_starts_at is null),
  unique(series_id,occurrence_date)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references auth.users(id) on delete restrict,
  teacher_user_id uuid not null references auth.users(id) on delete restrict,
  relationship_id uuid not null,
  source public.booking_source not null,
  status public.booking_status not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  timezone_anchor text not null,
  lesson_id uuid unique references public.lessons(id) on delete restrict,
  credit_reservation_id uuid unique references public.lesson_credit_reservations(id) on delete restrict,
  recurring_series_id uuid references public.recurring_lesson_series(id) on delete restrict,
  occurrence_date date,
  created_by uuid not null references auth.users(id) on delete restrict,
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 160),
  cancelled_at timestamptz,
  cancellation_reason text check (cancellation_reason is null or char_length(cancellation_reason) <= 1000),
  cancellation_credit_outcome public.booking_credit_outcome,
  earning_outcome text check (earning_outcome is null or char_length(earning_outcome) <= 100),
  rescheduled_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (student_user_id <> teacher_user_id),
  check (starts_at < ends_at),
  check (
    (status='cancelled' and cancelled_at is not null and cancellation_credit_outcome is not null)
    or status<>'cancelled'
  ),
  check ((source='fixed')=(recurring_series_id is not null)),
  check ((source='fixed')=(occurrence_date is not null)),
  foreign key(relationship_id,student_user_id,teacher_user_id)
    references public.student_teacher_relationships(id,student_user_id,teacher_user_id)
    on delete restrict,
  unique(student_user_id,idempotency_key),
  unique(recurring_series_id,occurrence_date)
);

alter table public.recurring_lesson_occurrences
  add constraint recurring_occurrences_booking_fk
  foreign key(booking_id) references public.bookings(id) on delete restrict;
alter table public.lesson_credit_reservations
  add column booking_id uuid unique references public.bookings(id) on delete restrict;

create index availability_rules_teacher_day_idx
  on public.teacher_availability_rules(teacher_user_id,weekday,effective_from,effective_until)
  where is_active;
create index availability_exceptions_teacher_time_idx
  on public.teacher_availability_exceptions(teacher_user_id,starts_at,ends_at);
create index bookings_student_time_idx on public.bookings(student_user_id,starts_at,status);
create index bookings_teacher_time_idx on public.bookings(teacher_user_id,starts_at,status);
create index recurring_series_teacher_idx
  on public.recurring_lesson_series(teacher_user_id,status,effective_from,effective_until);
create index recurring_series_student_idx
  on public.recurring_lesson_series(student_user_id,status,effective_from,effective_until);
create index recurring_occurrences_series_idx
  on public.recurring_lesson_occurrences(series_id,occurrence_date,status);

alter table public.recurring_lesson_occurrences add constraint recurring_occurrences_teacher_no_overlap
  exclude using gist (
    teacher_user_id with =,
    tstzrange(starts_at,ends_at,'[)') with &&
  ) where (status in ('planned','credit_required','materialized') and starts_at is not null);
alter table public.recurring_lesson_occurrences add constraint recurring_occurrences_student_no_overlap
  exclude using gist (
    student_user_id with =,
    tstzrange(starts_at,ends_at,'[)') with &&
  ) where (status in ('planned','credit_required','materialized') and starts_at is not null);

create or replace function private.resolve_scheduling_local_datetime(
  p_date date,p_time time,p_timezone text
) returns timestamptz
language plpgsql stable security definer set search_path=''
as $$
declare local_value timestamp; candidate timestamptz; match_count integer;
begin
  if p_date is null or p_time is null or not private.is_valid_iana_timezone(p_timezone) then
    raise exception using errcode='22023',message='INVALID_SCHEDULING_TIMEZONE';
  end if;
  local_value:=p_date+p_time;
  candidate:=local_value at time zone p_timezone;
  if candidate at time zone p_timezone <> local_value then
    raise exception using errcode='P0001',message='NONEXISTENT_LOCAL_TIME';
  end if;
  select count(*) into match_count
  from generate_series(candidate-interval '3 hours',candidate+interval '3 hours',interval '15 minutes') instant
  where instant at time zone p_timezone=local_value;
  if match_count<>1 then
    raise exception using errcode='P0001',message='AMBIGUOUS_LOCAL_TIME';
  end if;
  return candidate;
end;
$$;

create or replace function private.scheduling_actor_role(p_actor uuid)
returns public.app_role language sql stable security definer set search_path=''
as $$
  select role from public.user_roles where user_id=p_actor
  order by case role when 'super_admin' then 1 when 'admin' then 2 when 'teacher' then 3 else 4 end
  limit 1;
$$;

create or replace function private.scheduling_teacher_authorized(p_teacher_user_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
  select private.current_user_is_active() and (
    (auth.uid()=p_teacher_user_id
      and private.current_user_has_role(array['teacher'::public.app_role])
      and exists(
        select 1 from public.teacher_profiles teacher
        where teacher.user_id=p_teacher_user_id
          and teacher.teaching_status='active'
      ))
    or private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
  );
$$;

create or replace function private.scheduling_relationship_is_active(
  p_relationship_id uuid,p_student_user_id uuid,p_teacher_user_id uuid
) returns boolean language sql stable security definer set search_path=''
as $$
  select exists(
    select 1 from public.student_teacher_relationships r
    where r.id=p_relationship_id and r.student_user_id=p_student_user_id
      and r.teacher_user_id=p_teacher_user_id
      and r.relationship_status='active'
  );
$$;

create or replace function private.lock_scheduling_teacher(p_teacher_user_id uuid)
returns void language plpgsql security invoker set search_path=''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'the-one:v1:lesson-schedule:teacher:'||p_teacher_user_id::text,0));
end;
$$;

create or replace function private.scheduling_entitlement_eligible(
  p_entitlement_id uuid,p_student_user_id uuid,p_teacher_user_id uuid,p_mode public.booking_source
) returns boolean language sql stable security definer set search_path=''
as $$
  select exists(
    select 1 from public.entitlements e
    cross join lateral private.lesson_credit_balance(e.id) b
    where e.id=p_entitlement_id and e.beneficiary_user_id=p_student_user_id
      and e.entitlement_type='lesson_package' and e.status='active'
      and e.starts_at<=now() and (e.expires_at is null or e.expires_at>now())
      and b.available>0
      and (e.teacher_scope_user_id is null or e.teacher_scope_user_id=p_teacher_user_id)
      and (e.booking_mode_eligibility='both'
        or e.booking_mode_eligibility::text=p_mode::text)
  );
$$;

create or replace function private.scheduling_slot_clear(
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

create or replace function private.ensure_recurring_occurrences(
  p_series_id uuid,p_through_date date
) returns integer language plpgsql security definer set search_path=''
as $$
declare s public.recurring_lesson_series%rowtype; settings public.teacher_scheduling_settings%rowtype;
  occurrence_date date; occurrence_start timestamptz; occurrence_end timestamptz; inserted_count integer:=0;
begin
  select * into s from public.recurring_lesson_series where id=p_series_id for update;
  if not found or s.status='ended' then raise exception using errcode='P0001',message='RECURRING_SERIES_INACTIVE'; end if;
  select * into settings from public.teacher_scheduling_settings where teacher_user_id=s.teacher_user_id;
  if not found then raise exception using errcode='P0001',message='SCHEDULING_SETTINGS_REQUIRED'; end if;
  for occurrence_date in
    select day::date from generate_series(
      greatest(s.effective_from,current_date),
      least(coalesce(s.effective_until,current_date+settings.booking_horizon_days),
        least(p_through_date,current_date+settings.booking_horizon_days)),interval '1 day') day
    where extract(dow from day)::smallint=s.weekday
  loop
    begin
      occurrence_start:=private.resolve_scheduling_local_datetime(occurrence_date,s.local_start_time,s.timezone);
      occurrence_end:=occurrence_start+make_interval(mins=>s.duration_minutes);
      if not private.scheduling_slot_clear(s.student_user_id,s.teacher_user_id,occurrence_start,occurrence_end,null,null) then
        raise exception using errcode='P0001',message='RECURRING_SERIES_CONFLICT';
      end if;
      insert into public.recurring_lesson_occurrences(
        series_id,student_user_id,teacher_user_id,occurrence_date,starts_at,ends_at,status
      ) values(s.id,s.student_user_id,s.teacher_user_id,occurrence_date,occurrence_start,occurrence_end,'planned')
      on conflict on constraint recurring_lesson_occurrences_series_id_occurrence_date_key do nothing;
      if found then inserted_count:=inserted_count+1; end if;
    exception when sqlstate 'P0001' then
      if sqlerrm in('AMBIGUOUS_LOCAL_TIME','NONEXISTENT_LOCAL_TIME') then
        insert into public.recurring_lesson_occurrences(
          series_id,student_user_id,teacher_user_id,occurrence_date,status,error_code
        ) values(s.id,s.student_user_id,s.teacher_user_id,occurrence_date,'failed',sqlerrm)
        on conflict on constraint recurring_lesson_occurrences_series_id_occurrence_date_key do nothing;
      else raise; end if;
    end;
  end loop;
  return inserted_count;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='RECURRING_SERIES_CONFLICT';
end;
$$;

create or replace function public.set_teacher_scheduling_settings(
  p_teacher_user_id uuid,p_timezone text,p_minimum_booking_notice_minutes integer,
  p_booking_horizon_days integer,p_slot_interval_minutes integer,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); old_row public.teacher_scheduling_settings%rowtype;
begin
  if caller is null or not private.scheduling_teacher_authorized(p_teacher_user_id) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if not private.is_valid_iana_timezone(p_timezone)
    or p_minimum_booking_notice_minutes not between 0 and 43200
    or p_booking_horizon_days not between 1 and 366
    or p_slot_interval_minutes not between 5 and 120
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_SCHEDULING_SETTINGS';
  end if;
  select * into old_row from public.teacher_scheduling_settings where teacher_user_id=p_teacher_user_id;
  insert into public.teacher_scheduling_settings(
    teacher_user_id,timezone,minimum_booking_notice_minutes,booking_horizon_days,slot_interval_minutes
  ) values(p_teacher_user_id,p_timezone,p_minimum_booking_notice_minutes,p_booking_horizon_days,p_slot_interval_minutes)
  on conflict(teacher_user_id) do update set timezone=excluded.timezone,
    minimum_booking_notice_minutes=excluded.minimum_booking_notice_minutes,
    booking_horizon_days=excluded.booking_horizon_days,
    slot_interval_minutes=excluded.slot_interval_minutes,updated_at=now();
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'scheduling.settings_changed','teacher_scheduling_settings',p_teacher_user_id,
    case when old_row.teacher_user_id is null then '{}'::jsonb else jsonb_build_object(
      'timezone',old_row.timezone,'minimum_booking_notice_minutes',old_row.minimum_booking_notice_minutes,
      'booking_horizon_days',old_row.booking_horizon_days,'slot_interval_minutes',old_row.slot_interval_minutes) end,
    jsonb_build_object('timezone',p_timezone,'minimum_booking_notice_minutes',p_minimum_booking_notice_minutes,
      'booking_horizon_days',p_booking_horizon_days,'slot_interval_minutes',p_slot_interval_minutes),trim(p_reason));
  return p_teacher_user_id;
end;
$$;

create or replace function public.create_teacher_availability_rule(
  p_teacher_user_id uuid,p_weekday smallint,p_local_start_time time,p_local_end_time time,
  p_timezone text,p_effective_from date,p_effective_until date,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); settings public.teacher_scheduling_settings%rowtype; result_id uuid;
begin
  if caller is null or not private.scheduling_teacher_authorized(p_teacher_user_id) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  select * into settings from public.teacher_scheduling_settings where teacher_user_id=p_teacher_user_id;
  if not found or settings.timezone<>p_timezone or p_weekday not between 0 and 6
    or p_local_start_time>=p_local_end_time or p_effective_from is null
    or p_effective_until<p_effective_from
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_AVAILABILITY_RULE';
  end if;
  perform private.lock_scheduling_teacher(p_teacher_user_id);
  insert into public.teacher_availability_rules(
    teacher_user_id,weekday,local_start_time,local_end_time,timezone,effective_from,effective_until,created_by
  ) values(p_teacher_user_id,p_weekday,p_local_start_time,p_local_end_time,p_timezone,p_effective_from,p_effective_until,caller)
  returning id into result_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(caller,'availability.rule_created','teacher_availability_rule',result_id,
    jsonb_build_object('teacher_user_id',p_teacher_user_id,'weekday',p_weekday,
      'local_start_time',p_local_start_time,'local_end_time',p_local_end_time,'timezone',p_timezone),trim(p_reason));
  return result_id;
end;
$$;

create or replace function public.create_teacher_availability_exception(
  p_teacher_user_id uuid,p_exception_kind public.availability_exception_kind,
  p_starts_at timestamptz,p_ends_at timestamptz,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); result_id uuid;
begin
  if caller is null or not private.scheduling_teacher_authorized(p_teacher_user_id) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if p_starts_at is null or p_ends_at<=p_starts_at
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_AVAILABILITY_EXCEPTION';
  end if;
  perform private.lock_scheduling_teacher(p_teacher_user_id);
  if p_exception_kind='unavailable' and exists(
    select 1 from public.lessons where teacher_user_id=p_teacher_user_id and status='scheduled'
      and tstzrange(starts_at,ends_at,'[)')&&tstzrange(p_starts_at,p_ends_at,'[)')
  ) then raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE'; end if;
  insert into public.teacher_availability_exceptions(
    teacher_user_id,exception_kind,starts_at,ends_at,reason,created_by
  ) values(p_teacher_user_id,p_exception_kind,p_starts_at,p_ends_at,trim(p_reason),caller)
  returning id into result_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(caller,'availability.exception_created','teacher_availability_exception',result_id,
    jsonb_build_object('teacher_user_id',p_teacher_user_id,'kind',p_exception_kind,
      'starts_at',p_starts_at,'ends_at',p_ends_at),trim(p_reason));
  return result_id;
end;
$$;

create or replace function public.get_available_flexible_slots(
  p_teacher_user_id uuid,p_entitlement_id uuid,p_from timestamptz,p_to timestamptz
) returns table(
  starts_at timestamptz,ends_at timestamptz,teacher_timezone text,
  lesson_duration_minutes integer,booking_mode_eligibility public.lesson_booking_mode_eligibility
) language plpgsql stable security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); settings public.teacher_scheduling_settings%rowtype;
  ent public.entitlements%rowtype;
begin
  if caller is null or not private.current_user_is_active()
    or not private.current_user_has_role(array['student'::public.app_role]) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  select * into settings from public.teacher_scheduling_settings where teacher_user_id=p_teacher_user_id;
  select * into ent from public.entitlements where id=p_entitlement_id;
  if not found or not private.scheduling_entitlement_eligible(p_entitlement_id,caller,p_teacher_user_id,'flexible')
    then raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ELIGIBLE'; end if;
  if not exists(select 1 from public.teacher_profiles teacher
    join public.profiles profile on profile.user_id=teacher.user_id
    where teacher.user_id=p_teacher_user_id and teacher.teaching_status='active'
      and profile.account_status='active') then
    raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
  end if;
  if settings.teacher_user_id is null or p_from is null or p_to<=p_from
    or p_to-p_from>interval '31 days' or p_to>now()+make_interval(days=>settings.booking_horizon_days)
    then raise exception using errcode='22023',message='INVALID_SLOT_QUERY_RANGE'; end if;
  if not exists(select 1 from public.student_teacher_relationships r
    where r.student_user_id=caller and r.teacher_user_id=p_teacher_user_id
      and r.relationship_status='active') then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  return query
  with local_days as (
    select day::date local_date from generate_series(
      (p_from at time zone settings.timezone)::date,
      (p_to at time zone settings.timezone)::date,interval '1 day') day
  ), recurring_windows as (
    select private.resolve_scheduling_local_datetime(d.local_date,r.local_start_time,r.timezone) window_start,
      private.resolve_scheduling_local_datetime(d.local_date,r.local_end_time,r.timezone) window_end
    from local_days d join public.teacher_availability_rules r
      on r.teacher_user_id=p_teacher_user_id and r.is_active
      and r.weekday=extract(dow from d.local_date)::smallint
      and d.local_date>=r.effective_from and (r.effective_until is null or d.local_date<=r.effective_until)
  ), opening_windows as (
    select greatest(x.starts_at,p_from),least(x.ends_at,p_to)
    from public.teacher_availability_exceptions x
    where x.teacher_user_id=p_teacher_user_id and x.exception_kind='opening'
      and tstzrange(x.starts_at,x.ends_at,'[)')&&tstzrange(p_from,p_to,'[)')
  ), windows as (
    select * from recurring_windows union select * from opening_windows
  ), candidates as (
    select slot_start,
      slot_start+make_interval(mins=>ent.lesson_duration_minutes) slot_end
    from windows w cross join lateral generate_series(
      w.window_start,w.window_end-make_interval(mins=>ent.lesson_duration_minutes),
      make_interval(mins=>settings.slot_interval_minutes)) slot_start
  )
  select distinct c.slot_start,c.slot_end,settings.timezone,
    ent.lesson_duration_minutes,ent.booking_mode_eligibility
  from candidates c
  where c.slot_start>=p_from and c.slot_end<=p_to
    and c.slot_start>=now()+make_interval(mins=>settings.minimum_booking_notice_minutes)
    and private.scheduling_slot_clear(caller,p_teacher_user_id,c.slot_start,c.slot_end)
  order by c.slot_start;
end;
$$;

create or replace function private.flexible_slot_is_available(
  p_student_user_id uuid,p_teacher_user_id uuid,p_starts_at timestamptz,
  p_duration_minutes integer,p_ignore_lesson_id uuid default null,
  p_ignore_occurrence_id uuid default null
) returns boolean language plpgsql stable security definer set search_path=''
as $$
declare settings public.teacher_scheduling_settings%rowtype; slot_end timestamptz;
  local_date date; window_start timestamptz; window_end timestamptz;
begin
  select * into settings from public.teacher_scheduling_settings where teacher_user_id=p_teacher_user_id;
  if not found or p_starts_at is null or p_duration_minutes not between 1 and 480 then return false; end if;
  slot_end:=p_starts_at+make_interval(mins=>p_duration_minutes);
  if p_starts_at<now()+make_interval(mins=>settings.minimum_booking_notice_minutes)
    or p_starts_at>now()+make_interval(days=>settings.booking_horizon_days) then return false; end if;
  local_date:=(p_starts_at at time zone settings.timezone)::date;
  if not exists(
    select 1 from public.teacher_availability_rules r
    cross join lateral (select
      private.resolve_scheduling_local_datetime(local_date,r.local_start_time,r.timezone) ws,
      private.resolve_scheduling_local_datetime(local_date,r.local_end_time,r.timezone) we) w
    where r.teacher_user_id=p_teacher_user_id and r.is_active and r.timezone=settings.timezone
      and r.weekday=extract(dow from local_date)::smallint
      and local_date>=r.effective_from and (r.effective_until is null or local_date<=r.effective_until)
      and p_starts_at>=w.ws and slot_end<=w.we
      and mod(extract(epoch from (p_starts_at-w.ws))::integer/60,settings.slot_interval_minutes)=0
  ) and not exists(
    select 1 from public.teacher_availability_exceptions x
    where x.teacher_user_id=p_teacher_user_id and x.exception_kind='opening'
      and p_starts_at>=x.starts_at and slot_end<=x.ends_at
      and mod(extract(epoch from (p_starts_at-x.starts_at))::integer/60,settings.slot_interval_minutes)=0
  ) then return false; end if;
  return private.scheduling_slot_clear(p_student_user_id,p_teacher_user_id,p_starts_at,slot_end,
    p_ignore_lesson_id,p_ignore_occurrence_id);
exception when sqlstate 'P0001' then return false;
end;
$$;

create or replace function private.reserve_lesson_credit_core(
  p_entitlement_id uuid,p_beneficiary_user_id uuid,p_reservation_key text,
  p_lesson_id uuid,p_booking_reference text,p_actor_user_id uuid
) returns uuid language plpgsql security definer set search_path=''
as $$
declare ent public.entitlements%rowtype; existing public.lesson_credit_reservations%rowtype;
  balance record; result_id uuid;
begin
  if char_length(coalesce(p_reservation_key,'')) not between 16 and 160
    or (p_lesson_id is null and nullif(trim(coalesce(p_booking_reference,'')),'') is null) then
    raise exception using errcode='22023',message='INVALID_CREDIT_RESERVATION';
  end if;
  select * into ent from public.entitlements where id=p_entitlement_id for update;
  if not found or ent.beneficiary_user_id<>p_beneficiary_user_id or ent.entitlement_type<>'lesson_package' then
    raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ELIGIBLE';
  end if;
  select * into existing from public.lesson_credit_reservations
  where beneficiary_user_id=p_beneficiary_user_id and reservation_key=p_reservation_key for update;
  if found then
    if existing.entitlement_id is distinct from p_entitlement_id
      or existing.lesson_id is distinct from p_lesson_id
      or existing.booking_reference is distinct from nullif(trim(coalesce(p_booking_reference,'')),'') then
      raise exception using errcode='P0001',message='CREDIT_RESERVATION_PAYLOAD_MISMATCH';
    end if;
    if existing.status='reserved' then return existing.id; end if;
    raise exception using errcode='P0001',message=case when existing.status='consumed'
      then 'CREDIT_ALREADY_CONSUMED' else 'CREDIT_ALREADY_RELEASED' end;
  end if;
  if ent.status<>'active' then raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ACTIVE'; end if;
  if ent.starts_at>now() then raise exception using errcode='P0001',message='ENTITLEMENT_NOT_STARTED'; end if;
  if ent.expires_at is not null and ent.expires_at<=now() then
    raise exception using errcode='P0001',message='ENTITLEMENT_EXPIRED';
  end if;
  if p_lesson_id is not null and not exists(
    select 1 from public.lessons lesson
    where lesson.id=p_lesson_id and lesson.student_user_id=p_beneficiary_user_id
  ) then raise exception using errcode='42501',message='Not authorized'; end if;
  select * into balance from private.lesson_credit_balance(ent.id);
  if balance.available<1 then raise exception using errcode='P0001',message='INSUFFICIENT_LESSON_CREDITS'; end if;
  insert into public.lesson_credit_reservations(
    entitlement_id,beneficiary_user_id,reservation_key,lesson_id,booking_reference
  ) values(ent.id,p_beneficiary_user_id,p_reservation_key,p_lesson_id,
    nullif(trim(coalesce(p_booking_reference,'')),''))
  on conflict do nothing
  returning id into result_id;
  if result_id is null then
    raise exception using errcode='P0001',message='CREDIT_ALREADY_RESERVED';
  end if;
  insert into public.lesson_credit_ledger(
    entitlement_id,beneficiary_user_id,entry_type,available_delta,reserved_delta,
    reservation_id,lesson_id,operation_key,reason_code,actor_user_id,metadata
  ) values(ent.id,p_beneficiary_user_id,'reservation',-1,1,result_id,p_lesson_id,
    'reserve:'||p_reservation_key,'booking_reservation',p_actor_user_id,
    jsonb_build_object('booking_reference',nullif(trim(coalesce(p_booking_reference,'')),'')));
  return result_id;
end;
$$;

create or replace function private.release_lesson_credit_core(
  p_reservation_id uuid,p_reason_code text,p_actor_user_id uuid,p_metadata jsonb default '{}'::jsonb,
  p_allow_booking_bound boolean default false
) returns uuid language plpgsql security definer set search_path=''
as $$
declare res public.lesson_credit_reservations%rowtype; ent public.entitlements%rowtype;
begin
  select entitlement.* into ent from public.entitlements entitlement
  join public.lesson_credit_reservations reservation on reservation.entitlement_id=entitlement.id
  where reservation.id=p_reservation_id for update of entitlement;
  if not found then raise exception using errcode='P0001',message='CREDIT_RESERVATION_NOT_FOUND'; end if;
  select * into res from public.lesson_credit_reservations where id=p_reservation_id for update;
  if res.booking_id is not null and not p_allow_booking_bound then
    raise exception using errcode='P0001',message='CREDIT_RESERVATION_MANAGED_BY_BOOKING';
  end if;
  if res.status='released' then return res.id; end if;
  if res.status='consumed' then raise exception using errcode='P0001',message='CREDIT_ALREADY_CONSUMED'; end if;
  update public.lesson_credit_reservations set status='released',released_at=now(),updated_at=now() where id=res.id;
  insert into public.lesson_credit_ledger(
    entitlement_id,beneficiary_user_id,entry_type,available_delta,reserved_delta,
    reservation_id,lesson_id,operation_key,reason_code,actor_user_id,metadata
  ) values(ent.id,ent.beneficiary_user_id,'release',1,-1,res.id,res.lesson_id,
    'release:'||res.id::text,left(coalesce(nullif(trim(p_reason_code),''),'booking_release'),100),
    p_actor_user_id,coalesce(p_metadata,'{}'::jsonb));
  if ent.status='exhausted' and (ent.expires_at is null or ent.expires_at>now()) then
    update public.entitlements set status='active',updated_at=now() where id=ent.id;
  end if;
  return res.id;
end;
$$;

create or replace function private.consume_lesson_credit_core(
  p_reservation_id uuid,p_lesson_id uuid,p_reason_code text,p_actor_user_id uuid,
  p_metadata jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path=''
as $$
declare res public.lesson_credit_reservations%rowtype; ent public.entitlements%rowtype; balance record;
begin
  select entitlement.* into ent from public.entitlements entitlement
  join public.lesson_credit_reservations reservation on reservation.entitlement_id=entitlement.id
  where reservation.id=p_reservation_id for update of entitlement;
  if not found then raise exception using errcode='P0001',message='CREDIT_RESERVATION_NOT_FOUND'; end if;
  select * into res from public.lesson_credit_reservations where id=p_reservation_id for update;
  if res.lesson_id is distinct from p_lesson_id then
    raise exception using errcode='P0001',message='CREDIT_RESERVATION_PAYLOAD_MISMATCH';
  end if;
  if res.status='consumed' then return res.id; end if;
  if res.status='released' then raise exception using errcode='P0001',message='CREDIT_ALREADY_RELEASED'; end if;
  update public.lesson_credit_reservations
  set status='consumed',consumed_at=now(),updated_at=now() where id=res.id;
  insert into public.lesson_credit_ledger(
    entitlement_id,beneficiary_user_id,entry_type,reserved_delta,consumed_delta,
    reservation_id,lesson_id,operation_key,reason_code,actor_user_id,metadata
  ) values(ent.id,ent.beneficiary_user_id,'consumption',-1,1,res.id,p_lesson_id,
    'consume:'||res.id::text,left(coalesce(nullif(trim(p_reason_code),''),'lesson_completed'),100),
    p_actor_user_id,coalesce(p_metadata,'{}'::jsonb));
  select * into balance from private.lesson_credit_balance(ent.id);
  if balance.available=0 and balance.reserved=0 then
    update public.entitlements set status='exhausted',updated_at=now()
    where id=ent.id and status='active';
  end if;
  return res.id;
end;
$$;

create or replace function private.bind_lesson_credit_reservation_booking_core(
  p_reservation_id uuid,p_booking_id uuid,p_beneficiary_user_id uuid,
  p_entitlement_id uuid,p_lesson_id uuid
) returns uuid language plpgsql security definer set search_path=''
as $$
declare ent public.entitlements%rowtype; res public.lesson_credit_reservations%rowtype;
  booking public.bookings%rowtype;
begin
  select * into ent from public.entitlements where id=p_entitlement_id for update;
  if not found or ent.beneficiary_user_id<>p_beneficiary_user_id then
    raise exception using errcode='P0001',message='CREDIT_RESERVATION_BINDING_MISMATCH';
  end if;
  select * into res from public.lesson_credit_reservations where id=p_reservation_id for update;
  select * into booking from public.bookings where id=p_booking_id for update;
  if not found or res.id is null or res.entitlement_id<>p_entitlement_id
    or res.beneficiary_user_id<>p_beneficiary_user_id or res.lesson_id is distinct from p_lesson_id
    or booking.student_user_id<>p_beneficiary_user_id
    or booking.credit_reservation_id<>p_reservation_id or booking.lesson_id is distinct from p_lesson_id
    or (res.booking_id is not null and res.booking_id<>p_booking_id) then
    raise exception using errcode='P0001',message='CREDIT_RESERVATION_BINDING_MISMATCH';
  end if;
  update public.lesson_credit_reservations set booking_id=p_booking_id,updated_at=now()
  where id=p_reservation_id and booking_id is null;
  return p_reservation_id;
end;
$$;

create or replace function public.reserve_lesson_credit(
  p_entitlement_id uuid,p_reservation_key text,p_lesson_id uuid default null,
  p_booking_reference text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); ent public.entitlements%rowtype;
begin
  if caller is null or not private.current_user_is_active() then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  if char_length(coalesce(p_reservation_key,'')) not between 16 and 160
    or (p_lesson_id is null and nullif(trim(coalesce(p_booking_reference,'')),'') is null) then
    raise exception using errcode='22023',message='INVALID_CREDIT_RESERVATION';
  end if;
  select * into ent from public.entitlements where id=p_entitlement_id;
  if not found or ent.beneficiary_user_id<>caller or ent.entitlement_type<>'lesson_package' then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  return private.reserve_lesson_credit_core(p_entitlement_id,caller,p_reservation_key,
    p_lesson_id,p_booking_reference,caller);
end; $$;

create or replace function public.release_lesson_credit(
  p_reservation_id uuid,p_reason text default 'booking_release'
) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); beneficiary_id uuid;
begin
  if caller is null or not private.current_user_is_active() then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  select reservation.beneficiary_user_id into beneficiary_id
  from public.lesson_credit_reservations reservation where reservation.id=p_reservation_id;
  if not found or (beneficiary_id<>caller and not private.current_user_has_role(
    array['admin'::public.app_role,'super_admin'::public.app_role])) then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  return private.release_lesson_credit_core(p_reservation_id,p_reason,caller);
end; $$;

create or replace function public.consume_lesson_credit(p_reservation_id uuid,p_lesson_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); beneficiary_id uuid; reservation_lesson_id uuid;
begin
  if caller is null or not private.current_user_is_active() then
    raise exception using errcode='42501',message='Not authorized';
  end if;
  select reservation.beneficiary_user_id,reservation.lesson_id
    into beneficiary_id,reservation_lesson_id
  from public.lesson_credit_reservations reservation where reservation.id=p_reservation_id;
  if not found then raise exception using errcode='P0001',message='CREDIT_RESERVATION_NOT_FOUND'; end if;
  if reservation_lesson_id is distinct from p_lesson_id then
    raise exception using errcode='P0001',message='CREDIT_RESERVATION_PAYLOAD_MISMATCH';
  end if;
  if not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role])
    and not exists(
      select 1 from public.lessons lesson
      join public.teacher_profiles teacher on teacher.user_id=lesson.teacher_user_id
      where lesson.id=p_lesson_id and lesson.teacher_user_id=caller
        and lesson.student_user_id=beneficiary_id and lesson.status='completed'
        and teacher.teaching_status='active'
    ) then raise exception using errcode='42501',message='Not authorized'; end if;
  return private.consume_lesson_credit_core(p_reservation_id,p_lesson_id,
    'lesson_completed',caller);
end; $$;

create or replace function public.create_lesson_booking(
  p_student_user_id uuid,p_teacher_user_id uuid,p_relationship_id uuid,
  p_entitlement_id uuid,p_starts_at timestamptz,p_timezone text,
  p_idempotency_key text,p_reason text default 'Flexible booking'
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); student_id uuid; actor_role public.app_role;
  ent public.entitlements%rowtype; teacher public.teacher_profiles%rowtype;
  relation public.student_teacher_relationships%rowtype; existing public.bookings%rowtype;
  new_booking_id uuid:=gen_random_uuid(); new_lesson_id uuid:=gen_random_uuid(); reservation_id uuid;
  lesson_end timestamptz;
begin
  if caller is null or not private.current_user_is_active() then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  actor_role:=private.scheduling_actor_role(caller);
  if actor_role='student' then
    student_id:=caller;
    if p_student_user_id is distinct from caller then raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION'; end if;
  elsif actor_role='teacher' then
    student_id:=p_student_user_id;
    if caller<>p_teacher_user_id or not private.scheduling_teacher_authorized(p_teacher_user_id) then
      raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
    end if;
  elsif actor_role in('admin','super_admin') then student_id:=p_student_user_id;
  else raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION'; end if;
  if char_length(coalesce(p_idempotency_key,'')) not between 16 and 160
    or not private.is_valid_iana_timezone(p_timezone)
    or char_length(trim(coalesce(p_reason,''))) not between 3 and 1000 then
    raise exception using errcode='22023',message='INVALID_BOOKING_REQUEST';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'the-one:v1:booking:idempotency:'||student_id::text||':'||p_idempotency_key,6));
  select * into existing from public.bookings where student_user_id=student_id and idempotency_key=p_idempotency_key;
  if found then
    if existing.teacher_user_id<>p_teacher_user_id or existing.relationship_id<>p_relationship_id
      or existing.starts_at<>p_starts_at or existing.source<>'flexible'
      or existing.timezone_anchor<>p_timezone
      or not exists(select 1 from public.lesson_credit_reservations existing_reservation
        where existing_reservation.id=existing.credit_reservation_id
          and existing_reservation.entitlement_id=p_entitlement_id) then
      raise exception using errcode='P0001',message='BOOKING_ALREADY_EXISTS';
    end if;
    return existing.id;
  end if;
  select * into relation from public.student_teacher_relationships where id=p_relationship_id;
  if not found or relation.student_user_id<>student_id or relation.teacher_user_id<>p_teacher_user_id
    or relation.relationship_status<>'active' then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  select * into ent from public.entitlements where id=p_entitlement_id;
  if not found or not private.scheduling_entitlement_eligible(p_entitlement_id,student_id,p_teacher_user_id,'flexible') then
    raise exception using errcode='P0001',message='ENTITLEMENT_NOT_ELIGIBLE';
  end if;
  lesson_end:=p_starts_at+make_interval(mins=>ent.lesson_duration_minutes);
  perform private.lock_lesson_schedule_resources(student_id,p_teacher_user_id);
  perform 1 from public.entitlements where id=p_entitlement_id for update;
  if not private.flexible_slot_is_available(student_id,p_teacher_user_id,p_starts_at,ent.lesson_duration_minutes) then
    raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
  end if;
  select * into teacher from public.teacher_profiles where user_id=p_teacher_user_id;
  if not found or teacher.teaching_status<>'active' then
    raise exception using errcode='P0001',message='TEACHER_SCHEDULE_CONFLICT';
  end if;
  insert into public.lessons(
    id,student_user_id,teacher_user_id,relationship_id,lesson_type,delivery_mode,
    starts_at,ends_at,duration_minutes,timezone_anchor,status,
    meeting_provider,meeting_url,location_text
  ) values(
    new_lesson_id,student_id,p_teacher_user_id,p_relationship_id,'flexible',relation.preferred_mode,
    p_starts_at,lesson_end,ent.lesson_duration_minutes,p_timezone,'scheduled',
    case when relation.preferred_mode='online' then teacher.default_meeting_provider end,
    case when relation.preferred_mode='online' then teacher.default_meeting_url end,
    case when relation.preferred_mode='onsite' then teacher.location_text end
  );
  reservation_id:=private.reserve_lesson_credit_core(p_entitlement_id,student_id,
    'booking:'||p_idempotency_key,new_lesson_id,new_booking_id::text,caller);
  insert into public.bookings(
    id,student_user_id,teacher_user_id,relationship_id,source,status,starts_at,ends_at,
    timezone_anchor,lesson_id,credit_reservation_id,created_by,idempotency_key
  ) values(new_booking_id,student_id,p_teacher_user_id,p_relationship_id,'flexible','confirmed',
    p_starts_at,lesson_end,p_timezone,new_lesson_id,reservation_id,caller,p_idempotency_key);
  perform private.bind_lesson_credit_reservation_booking_core(
    reservation_id,new_booking_id,student_id,p_entitlement_id,new_lesson_id);
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(caller,'booking.created','booking',new_booking_id,jsonb_build_object(
    'actor_role',actor_role,'student_user_id',student_id,'teacher_user_id',p_teacher_user_id,
    'lesson_id',new_lesson_id,'source','flexible','starts_at',p_starts_at,'ends_at',lesson_end,
    'credit_reservation_id',reservation_id),trim(p_reason));
  return new_booking_id;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
when unique_violation then
  raise exception using errcode='P0001',message='BOOKING_ALREADY_EXISTS';
end;
$$;

create or replace function public.cancel_lesson_booking(
  p_booking_id uuid,p_credit_outcome public.booking_credit_outcome,p_reason text,
  p_earning_outcome text default 'not_applicable'
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; b public.bookings%rowtype;
  ent public.entitlements%rowtype; reservation public.lesson_credit_reservations%rowtype;
  lesson public.lessons%rowtype; occurrence_id uuid;
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
    or (caller=b.teacher_user_id
      and private.scheduling_teacher_authorized(b.teacher_user_id))
    or actor_role in('admin','super_admin')) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if p_credit_outcome='consumed' and actor_role not in('admin','super_admin') then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if actor_role not in('admin','super_admin') and p_credit_outcome<>'released' then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
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
  if b.status='cancelled' then return b.id; end if;
  if b.status not in('confirmed','rescheduled') then
    raise exception using errcode='P0001',message='BOOKING_NOT_CANCELLABLE';
  end if;
  if p_credit_outcome='released' then
    perform private.release_lesson_credit_core(
      reservation.id,'booking_cancellation',caller,
      jsonb_build_object('booking_id',b.id,'reason',trim(p_reason)),true);
  elsif p_credit_outcome='consumed' then
    perform private.consume_lesson_credit_core(
      reservation.id,lesson.id,'admin_cancellation_consumed',caller,
      jsonb_build_object('booking_id',b.id,'reason',trim(p_reason)));
  end if;
  update public.lessons set status=case
      when actor_role in('admin','super_admin') then 'admin_cancelled'::public.lesson_status
      when caller=b.teacher_user_id then 'teacher_cancelled'::public.lesson_status
      else 'student_cancelled'::public.lesson_status
    end,updated_at=now()
    where id=lesson.id and status='scheduled';
  update public.bookings set status='cancelled',cancelled_at=now(),
    cancellation_reason=trim(p_reason),cancellation_credit_outcome=p_credit_outcome,
    earning_outcome=p_earning_outcome,updated_at=now() where id=b.id;
  if occurrence_id is not null then
    update public.recurring_lesson_occurrences set status=case when p_credit_outcome='released'
      then 'released'::public.recurring_occurrence_status else status end,updated_at=now()
      where id=occurrence_id;
  end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'booking.cancelled','booking',b.id,
    jsonb_build_object('status',b.status,'starts_at',b.starts_at,'ends_at',b.ends_at),
    jsonb_build_object('status','cancelled','credit_outcome',p_credit_outcome,
      'earning_outcome',p_earning_outcome,'lesson_id',b.lesson_id),trim(p_reason));
  return b.id;
end;
$$;

create or replace function public.reschedule_lesson_booking(
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
    or (caller=b.teacher_user_id
      and private.scheduling_teacher_authorized(b.teacher_user_id))
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
  new_end:=p_new_starts_at+make_interval(mins=>extract(epoch from (b.ends_at-b.starts_at))::integer/60);
  select id into occurrence_id from public.recurring_lesson_occurrences where booking_id=b.id for update;
  select * into lesson from public.lessons where id=b.lesson_id for update;
  if not private.flexible_slot_is_available(b.student_user_id,b.teacher_user_id,p_new_starts_at,
    extract(epoch from (new_end-p_new_starts_at))::integer/60,b.lesson_id,occurrence_id) then
    raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
  end if;
  update public.lessons set starts_at=p_new_starts_at,ends_at=new_end,
    timezone_anchor=p_timezone,status='scheduled',updated_at=now() where id=lesson.id;
  update public.bookings set starts_at=p_new_starts_at,ends_at=new_end,
    timezone_anchor=p_timezone,status='rescheduled',rescheduled_at=now(),updated_at=now() where id=b.id;
  if occurrence_id is not null then
    update public.recurring_lesson_occurrences set starts_at=p_new_starts_at,ends_at=new_end,updated_at=now()
      where id=occurrence_id;
    insert into public.recurring_lesson_series_exceptions(
      series_id,occurrence_date,exception_kind,replacement_starts_at,replacement_ends_at,
      reason,actor_user_id,actor_role
    ) values(b.recurring_series_id,b.occurrence_date,'reschedule',p_new_starts_at,new_end,
      trim(p_reason),caller,actor_role)
    on conflict(series_id,occurrence_date) do update set
      exception_kind='reschedule',replacement_starts_at=excluded.replacement_starts_at,
      replacement_ends_at=excluded.replacement_ends_at,reason=excluded.reason,
      actor_user_id=excluded.actor_user_id,actor_role=excluded.actor_role,created_at=now();
  end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'booking.rescheduled','booking',b.id,
    jsonb_build_object('starts_at',b.starts_at,'ends_at',b.ends_at),
    jsonb_build_object('starts_at',p_new_starts_at,'ends_at',new_end,
      'credit_reservation_id',b.credit_reservation_id),trim(p_reason));
  return b.id;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
end;
$$;

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
  if exists(
    select 1 from public.recurring_lesson_series s
    where s.status in('active','paused') and s.weekday=p_weekday
      and (s.teacher_user_id=p_teacher_user_id or s.student_user_id=p_student_user_id)
      and daterange(s.effective_from,coalesce(s.effective_until,'infinity'::date),'[]')
        &&daterange(p_effective_from,coalesce(p_effective_until,'infinity'::date),'[]')
      and int4range(extract(epoch from s.local_start_time)::integer/60,
        extract(epoch from s.local_start_time)::integer/60+s.duration_minutes,'[)')
        &&int4range(extract(epoch from p_local_start_time)::integer/60,
          extract(epoch from p_local_start_time)::integer/60+p_duration_minutes,'[)')
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

create or replace function public.refresh_recurring_series_occurrences(
  p_series_id uuid,p_through_date date
) returns integer language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); s public.recurring_lesson_series%rowtype;
begin
  select * into s from public.recurring_lesson_series where id=p_series_id;
  if not found or caller is null or not private.scheduling_teacher_authorized(s.teacher_user_id) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  perform private.lock_lesson_schedule_resources(s.student_user_id,s.teacher_user_id);
  return private.ensure_recurring_occurrences(s.id,p_through_date);
end;
$$;

create or replace function public.set_recurring_lesson_series_status(
  p_series_id uuid,p_status public.recurring_series_status,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; s public.recurring_lesson_series%rowtype;
begin
  select * into s from public.recurring_lesson_series where id=p_series_id;
  actor_role:=private.scheduling_actor_role(caller);
  if not found or caller is null or not private.scheduling_teacher_authorized(s.teacher_user_id)
    or actor_role not in('teacher','admin','super_admin') then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or (s.status='ended' and p_status<>'ended') then
    raise exception using errcode='P0001',message='RECURRING_SERIES_INACTIVE';
  end if;
  perform private.lock_lesson_schedule_resources(s.student_user_id,s.teacher_user_id);
  select * into s from public.recurring_lesson_series where id=p_series_id for update;
  update public.recurring_lesson_series set status=p_status,
    paused_at=case when p_status='paused' then now() when p_status='active' then null else paused_at end,
    ended_at=case when p_status='ended' then now() else null end,
    effective_until=case when p_status='ended' then least(coalesce(effective_until,current_date),current_date) else effective_until end,
    lifecycle_reason=trim(p_reason),updated_at=now() where id=s.id;
  if p_status='ended' then
    update public.recurring_lesson_occurrences set status='released',updated_at=now()
    where series_id=s.id and occurrence_date>current_date and status in('planned','credit_required');
  end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'recurring_series.'||p_status::text,'recurring_lesson_series',s.id,
    jsonb_build_object('status',s.status),jsonb_build_object('status',p_status,'actor_role',actor_role),trim(p_reason));
  return s.id;
end;
$$;

create or replace function public.set_recurring_lesson_series_exception(
  p_series_id uuid,p_occurrence_date date,
  p_exception_kind public.recurring_series_exception_kind,
  p_replacement_starts_at timestamptz,p_replacement_ends_at timestamptz,
  p_release_this_occurrence boolean,p_reason text
) returns uuid language plpgsql security definer set search_path=''
as $$
declare caller uuid:=auth.uid(); actor_role public.app_role; s public.recurring_lesson_series%rowtype;
  o public.recurring_lesson_occurrences%rowtype; result_id uuid;
begin
  select * into s from public.recurring_lesson_series where id=p_series_id;
  actor_role:=private.scheduling_actor_role(caller);
  if not found or caller is null or not private.scheduling_teacher_authorized(s.teacher_user_id)
    or actor_role not in('teacher','admin','super_admin') then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 1000
    or (p_exception_kind='reschedule' and (p_replacement_starts_at is null
      or p_replacement_ends_at<=p_replacement_starts_at
      or p_replacement_ends_at<>p_replacement_starts_at+make_interval(mins=>s.duration_minutes)))
    or (p_exception_kind<>'reschedule' and p_replacement_starts_at is not null) then
    raise exception using errcode='22023',message='INVALID_SERIES_EXCEPTION';
  end if;
  perform private.lock_lesson_schedule_resources(s.student_user_id,s.teacher_user_id);
  select * into o from public.recurring_lesson_occurrences
    where series_id=s.id and occurrence_date=p_occurrence_date for update;
  if not found then raise exception using errcode='P0001',message='OCCURRENCE_NOT_FOUND'; end if;
  if o.status='materialized' then raise exception using errcode='P0001',message='OCCURRENCE_ALREADY_MATERIALIZED'; end if;
  if p_exception_kind='reschedule' then
    if not private.scheduling_slot_clear(s.student_user_id,s.teacher_user_id,
      p_replacement_starts_at,p_replacement_ends_at,null,o.id) then
      raise exception using errcode='P0001',message='SLOT_NOT_AVAILABLE';
    end if;
    update public.recurring_lesson_occurrences set starts_at=p_replacement_starts_at,
      ends_at=p_replacement_ends_at,status='planned',error_code=null,updated_at=now() where id=o.id;
  elsif p_release_this_occurrence or p_exception_kind in('release','cancel','skip_holiday','student_leave') then
    update public.recurring_lesson_occurrences set status=case when p_exception_kind='release'
      then 'released'::public.recurring_occurrence_status else 'skipped'::public.recurring_occurrence_status end,
      updated_at=now() where id=o.id;
  end if;
  insert into public.recurring_lesson_series_exceptions(
    series_id,occurrence_date,exception_kind,replacement_starts_at,replacement_ends_at,
    release_this_occurrence,reason,actor_user_id,actor_role
  ) values(s.id,p_occurrence_date,p_exception_kind,p_replacement_starts_at,p_replacement_ends_at,
    p_release_this_occurrence,trim(p_reason),caller,actor_role)
  on conflict(series_id,occurrence_date) do update set exception_kind=excluded.exception_kind,
    replacement_starts_at=excluded.replacement_starts_at,replacement_ends_at=excluded.replacement_ends_at,
    release_this_occurrence=excluded.release_this_occurrence,reason=excluded.reason,
    actor_user_id=excluded.actor_user_id,actor_role=excluded.actor_role,created_at=now()
  returning id into result_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot,reason)
  values(caller,'recurring_series.exception_set','recurring_lesson_series_exception',result_id,
    jsonb_build_object('series_id',s.id,'occurrence_date',p_occurrence_date,
      'kind',p_exception_kind,'release_this_occurrence',p_release_this_occurrence,
      'replacement_starts_at',p_replacement_starts_at,'replacement_ends_at',p_replacement_ends_at),trim(p_reason));
  return result_id;
exception when exclusion_violation then
  raise exception using errcode='P0001',message='RECURRING_SERIES_CONFLICT';
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

create or replace function public.complete_lesson_booking(
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
  if b.status='completed' and lesson.status='completed' and reservation.status='consumed' then return lesson.id; end if;
  if b.status not in('confirmed','rescheduled') or lesson.status<>'scheduled' then
    raise exception using errcode='P0001',message='BOOKING_NOT_COMPLETABLE';
  end if;
  if lesson.starts_at>now() then
    raise exception using errcode='P0001',message='BOOKING_NOT_COMPLETABLE';
  end if;
  update public.lessons set status='completed',updated_at=now() where id=lesson.id;
  insert into public.lesson_records(
    lesson_id,student_visible_notes,private_teacher_notes,performance_summary,
    next_goal,homework,completed_at,completed_by
  ) values(lesson.id,coalesce(p_student_visible_notes,''),coalesce(p_private_teacher_notes,''),
    coalesce(p_performance_summary,''),coalesce(p_next_goal,''),coalesce(p_homework,''),now(),caller)
  on conflict(lesson_id) do nothing;
  perform private.consume_lesson_credit_core(
    reservation.id,lesson.id,'lesson_completed',caller,
    jsonb_build_object('booking_id',b.id,'reason','Lesson completed'));
  update public.bookings set status='completed',completed_at=now(),updated_at=now() where id=b.id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,before_snapshot,after_snapshot,reason)
  values(caller,'booking.completed','booking',b.id,jsonb_build_object('status',b.status),
    jsonb_build_object('status','completed','lesson_id',lesson.id,
      'credit_reservation_id',reservation.id,'earning_outcome','future_integration'),'Lesson completed');
  return lesson.id;
end;
$$;

create or replace function public.get_own_scheduling_bookings()
returns table(
  id uuid,source public.booking_source,status public.booking_status,starts_at timestamptz,
  ends_at timestamptz,timezone_anchor text,lesson_id uuid,teacher_user_id uuid,
  recurring_series_id uuid,credit_outcome public.booking_credit_outcome
) language sql stable security definer set search_path=''
as $$
  select b.id,b.source,b.status,b.starts_at,b.ends_at,b.timezone_anchor,b.lesson_id,
    b.teacher_user_id,b.recurring_series_id,b.cancellation_credit_outcome
  from public.bookings b where b.student_user_id=auth.uid()
    and private.current_user_is_active() order by b.starts_at;
$$;

create or replace function public.get_teacher_scheduling_bookings()
returns table(
  id uuid,source public.booking_source,status public.booking_status,starts_at timestamptz,
  ends_at timestamptz,timezone_anchor text,lesson_id uuid,student_user_id uuid,
  recurring_series_id uuid,credit_outcome public.booking_credit_outcome
) language plpgsql stable security definer set search_path=''
as $$
begin
  if auth.uid() is null or not private.current_user_is_active()
    or not private.current_user_has_role(array['teacher'::public.app_role]) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  return query select b.id,b.source,b.status,b.starts_at,b.ends_at,b.timezone_anchor,
    b.lesson_id,b.student_user_id,b.recurring_series_id,b.cancellation_credit_outcome
  from public.bookings b where b.teacher_user_id=auth.uid() order by b.starts_at;
end;
$$;

create or replace function public.get_own_recurring_lesson_series()
returns table(
  id uuid,teacher_user_id uuid,weekday smallint,local_start_time time,timezone text,
  duration_minutes smallint,effective_from date,effective_until date,
  status public.recurring_series_status
) language sql stable security definer set search_path=''
as $$
  select s.id,s.teacher_user_id,s.weekday,s.local_start_time,s.timezone,s.duration_minutes,
    s.effective_from,s.effective_until,s.status
  from public.recurring_lesson_series s where s.student_user_id=auth.uid()
    and private.current_user_is_active() order by s.effective_from,s.local_start_time;
$$;

create or replace function public.get_teacher_recurring_lesson_series()
returns table(
  id uuid,student_user_id uuid,weekday smallint,local_start_time time,timezone text,
  duration_minutes smallint,effective_from date,effective_until date,
  status public.recurring_series_status,preferred_entitlement_id uuid
) language plpgsql stable security definer set search_path=''
as $$
begin
  if auth.uid() is null or not private.current_user_is_active()
    or not private.current_user_has_role(array['teacher'::public.app_role]) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  return query select s.id,s.student_user_id,s.weekday,s.local_start_time,s.timezone,
    s.duration_minutes,s.effective_from,s.effective_until,s.status,s.preferred_entitlement_id
  from public.recurring_lesson_series s where s.teacher_user_id=auth.uid()
  order by s.effective_from,s.local_start_time;
end;
$$;

create or replace function public.get_teacher_availability_configuration()
returns table(
  setting_timezone text,minimum_booking_notice_minutes integer,booking_horizon_days integer,
  slot_interval_minutes integer,rule_id uuid,weekday smallint,local_start_time time,
  local_end_time time,effective_from date,effective_until date,is_active boolean
) language plpgsql stable security definer set search_path=''
as $$
begin
  if auth.uid() is null or not private.current_user_is_active()
    or not private.current_user_has_role(array['teacher'::public.app_role]) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  return query select s.timezone,s.minimum_booking_notice_minutes,s.booking_horizon_days,
    s.slot_interval_minutes,r.id,r.weekday,r.local_start_time,r.local_end_time,
    r.effective_from,r.effective_until,r.is_active
  from public.teacher_scheduling_settings s left join public.teacher_availability_rules r
    on r.teacher_user_id=s.teacher_user_id
  where s.teacher_user_id=auth.uid() order by r.weekday,r.local_start_time;
end;
$$;

create or replace function public.get_admin_schedule_overview(p_from timestamptz,p_to timestamptz)
returns table(
  booking_id uuid,student_user_id uuid,teacher_user_id uuid,source public.booking_source,
  status public.booking_status,starts_at timestamptz,ends_at timestamptz,lesson_id uuid,
  recurring_series_id uuid,credit_reservation_id uuid
) language plpgsql stable security definer set search_path=''
as $$
begin
  if auth.uid() is null or not private.current_user_is_active()
    or not private.current_user_has_role(array['admin'::public.app_role,'super_admin'::public.app_role]) then
    raise exception using errcode='42501',message='UNAUTHORIZED_BOOKING_ACTION';
  end if;
  if p_from is null or p_to<=p_from or p_to-p_from>interval '366 days' then
    raise exception using errcode='22023',message='INVALID_SLOT_QUERY_RANGE';
  end if;
  return query select b.id,b.student_user_id,b.teacher_user_id,b.source,b.status,
    b.starts_at,b.ends_at,b.lesson_id,b.recurring_series_id,b.credit_reservation_id
  from public.bookings b where tstzrange(b.starts_at,b.ends_at,'[)')&&tstzrange(p_from,p_to,'[)')
  order by b.starts_at;
end;
$$;

alter table public.teacher_scheduling_settings enable row level security;
alter table public.teacher_availability_rules enable row level security;
alter table public.teacher_availability_exceptions enable row level security;
alter table public.recurring_lesson_series enable row level security;
alter table public.recurring_lesson_occurrences enable row level security;
alter table public.recurring_lesson_series_exceptions enable row level security;
alter table public.bookings enable row level security;

create policy scheduling_settings_teacher_select on public.teacher_scheduling_settings
  for select to authenticated using(teacher_user_id=auth.uid() and private.current_user_is_active());
create policy availability_rules_teacher_select on public.teacher_availability_rules
  for select to authenticated using(teacher_user_id=auth.uid() and private.current_user_is_active());
create policy availability_exceptions_teacher_select on public.teacher_availability_exceptions
  for select to authenticated using(teacher_user_id=auth.uid() and private.current_user_is_active());
create policy bookings_participant_select on public.bookings
  for select to authenticated using(
    private.current_user_is_active() and auth.uid() in(student_user_id,teacher_user_id));
create policy recurring_series_participant_select on public.recurring_lesson_series
  for select to authenticated using(
    private.current_user_is_active() and auth.uid() in(student_user_id,teacher_user_id));
create policy recurring_occurrences_participant_select on public.recurring_lesson_occurrences
  for select to authenticated using(
    private.current_user_is_active() and auth.uid() in(student_user_id,teacher_user_id));
create policy recurring_exceptions_participant_select on public.recurring_lesson_series_exceptions
  for select to authenticated using(private.current_user_is_active() and exists(
    select 1 from public.recurring_lesson_series s where s.id=series_id
      and auth.uid() in(s.student_user_id,s.teacher_user_id)));

revoke all on table public.teacher_scheduling_settings,public.teacher_availability_rules,
  public.teacher_availability_exceptions,public.recurring_lesson_series,
  public.recurring_lesson_occurrences,public.recurring_lesson_series_exceptions,
  public.bookings from public,anon,authenticated,service_role;

alter function private.resolve_scheduling_local_datetime(date,time,text) owner to postgres;
alter function private.scheduling_actor_role(uuid) owner to postgres;
alter function private.scheduling_teacher_authorized(uuid) owner to postgres;
alter function private.scheduling_relationship_is_active(uuid,uuid,uuid) owner to postgres;
alter function private.lock_scheduling_teacher(uuid) owner to postgres;
alter function private.scheduling_entitlement_eligible(uuid,uuid,uuid,public.booking_source) owner to postgres;
alter function private.scheduling_slot_clear(uuid,uuid,timestamptz,timestamptz,uuid,uuid) owner to postgres;
alter function private.ensure_recurring_occurrences(uuid,date) owner to postgres;
alter function private.flexible_slot_is_available(uuid,uuid,timestamptz,integer,uuid,uuid) owner to postgres;
alter function private.reserve_lesson_credit_core(uuid,uuid,text,uuid,text,uuid) owner to postgres;
alter function private.release_lesson_credit_core(uuid,text,uuid,jsonb,boolean) owner to postgres;
alter function private.consume_lesson_credit_core(uuid,uuid,text,uuid,jsonb) owner to postgres;
alter function private.bind_lesson_credit_reservation_booking_core(uuid,uuid,uuid,uuid,uuid) owner to postgres;
alter function public.reserve_lesson_credit(uuid,text,uuid,text) owner to postgres;
alter function public.release_lesson_credit(uuid,text) owner to postgres;
alter function public.consume_lesson_credit(uuid,uuid) owner to postgres;
alter function public.set_teacher_scheduling_settings(uuid,text,integer,integer,integer,text) owner to postgres;
alter function public.create_teacher_availability_rule(uuid,smallint,time,time,text,date,date,text) owner to postgres;
alter function public.create_teacher_availability_exception(uuid,public.availability_exception_kind,timestamptz,timestamptz,text) owner to postgres;
alter function public.get_available_flexible_slots(uuid,uuid,timestamptz,timestamptz) owner to postgres;
alter function public.create_lesson_booking(uuid,uuid,uuid,uuid,timestamptz,text,text,text) owner to postgres;
alter function public.cancel_lesson_booking(uuid,public.booking_credit_outcome,text,text) owner to postgres;
alter function public.reschedule_lesson_booking(uuid,timestamptz,text,text) owner to postgres;
alter function public.create_recurring_lesson_series(uuid,uuid,uuid,uuid,smallint,time,text,smallint,date,date,text) owner to postgres;
alter function public.refresh_recurring_series_occurrences(uuid,date) owner to postgres;
alter function public.set_recurring_lesson_series_status(uuid,public.recurring_series_status,text) owner to postgres;
alter function public.set_recurring_lesson_series_exception(uuid,date,public.recurring_series_exception_kind,timestamptz,timestamptz,boolean,text) owner to postgres;
alter function public.materialize_recurring_lesson_occurrence(uuid,date,uuid,text) owner to postgres;
alter function public.complete_lesson_booking(uuid,text,text,text,text,text) owner to postgres;
alter function public.get_own_scheduling_bookings() owner to postgres;
alter function public.get_teacher_scheduling_bookings() owner to postgres;
alter function public.get_own_recurring_lesson_series() owner to postgres;
alter function public.get_teacher_recurring_lesson_series() owner to postgres;
alter function public.get_teacher_availability_configuration() owner to postgres;
alter function public.get_admin_schedule_overview(timestamptz,timestamptz) owner to postgres;

revoke all on function private.resolve_scheduling_local_datetime(date,time,text),
  private.scheduling_actor_role(uuid),private.scheduling_teacher_authorized(uuid),
  private.scheduling_relationship_is_active(uuid,uuid,uuid),private.lock_scheduling_teacher(uuid),
  private.scheduling_entitlement_eligible(uuid,uuid,uuid,public.booking_source),
  private.scheduling_slot_clear(uuid,uuid,timestamptz,timestamptz,uuid,uuid),
  private.ensure_recurring_occurrences(uuid,date),
  private.flexible_slot_is_available(uuid,uuid,timestamptz,integer,uuid,uuid),
  private.reserve_lesson_credit_core(uuid,uuid,text,uuid,text,uuid),
  private.release_lesson_credit_core(uuid,text,uuid,jsonb,boolean),
  private.consume_lesson_credit_core(uuid,uuid,text,uuid,jsonb),
  private.bind_lesson_credit_reservation_booking_core(uuid,uuid,uuid,uuid,uuid)
from public,anon,authenticated,service_role;

revoke all on function public.reserve_lesson_credit(uuid,text,uuid,text),
  public.release_lesson_credit(uuid,text),public.consume_lesson_credit(uuid,uuid)
from public,anon,authenticated,service_role;
grant execute on function public.reserve_lesson_credit(uuid,text,uuid,text),
  public.release_lesson_credit(uuid,text),public.consume_lesson_credit(uuid,uuid)
to authenticated;

revoke all on function public.set_teacher_scheduling_settings(uuid,text,integer,integer,integer,text),
  public.create_teacher_availability_rule(uuid,smallint,time,time,text,date,date,text),
  public.create_teacher_availability_exception(uuid,public.availability_exception_kind,timestamptz,timestamptz,text),
  public.get_available_flexible_slots(uuid,uuid,timestamptz,timestamptz),
  public.create_lesson_booking(uuid,uuid,uuid,uuid,timestamptz,text,text,text),
  public.cancel_lesson_booking(uuid,public.booking_credit_outcome,text,text),
  public.reschedule_lesson_booking(uuid,timestamptz,text,text),
  public.create_recurring_lesson_series(uuid,uuid,uuid,uuid,smallint,time,text,smallint,date,date,text),
  public.refresh_recurring_series_occurrences(uuid,date),
  public.set_recurring_lesson_series_status(uuid,public.recurring_series_status,text),
  public.set_recurring_lesson_series_exception(uuid,date,public.recurring_series_exception_kind,timestamptz,timestamptz,boolean,text),
  public.materialize_recurring_lesson_occurrence(uuid,date,uuid,text),
  public.complete_lesson_booking(uuid,text,text,text,text,text),
  public.get_own_scheduling_bookings(),public.get_teacher_scheduling_bookings(),
  public.get_own_recurring_lesson_series(),public.get_teacher_recurring_lesson_series(),
  public.get_teacher_availability_configuration(),public.get_admin_schedule_overview(timestamptz,timestamptz)
from public,anon,authenticated,service_role;

grant execute on function public.set_teacher_scheduling_settings(uuid,text,integer,integer,integer,text),
  public.create_teacher_availability_rule(uuid,smallint,time,time,text,date,date,text),
  public.create_teacher_availability_exception(uuid,public.availability_exception_kind,timestamptz,timestamptz,text),
  public.get_available_flexible_slots(uuid,uuid,timestamptz,timestamptz),
  public.create_lesson_booking(uuid,uuid,uuid,uuid,timestamptz,text,text,text),
  public.cancel_lesson_booking(uuid,public.booking_credit_outcome,text,text),
  public.reschedule_lesson_booking(uuid,timestamptz,text,text),
  public.create_recurring_lesson_series(uuid,uuid,uuid,uuid,smallint,time,text,smallint,date,date,text),
  public.refresh_recurring_series_occurrences(uuid,date),
  public.set_recurring_lesson_series_status(uuid,public.recurring_series_status,text),
  public.set_recurring_lesson_series_exception(uuid,date,public.recurring_series_exception_kind,timestamptz,timestamptz,boolean,text),
  public.materialize_recurring_lesson_occurrence(uuid,date,uuid,text),
  public.complete_lesson_booking(uuid,text,text,text,text,text),
  public.get_own_scheduling_bookings(),public.get_teacher_scheduling_bookings(),
  public.get_own_recurring_lesson_series(),public.get_teacher_recurring_lesson_series(),
  public.get_teacher_availability_configuration(),public.get_admin_schedule_overview(timestamptz,timestamptz)
to authenticated;

comment on table public.bookings is
  'Scheduling commitment linked one-to-one with an actual Lesson and one shared Epic 5 credit reservation.';
comment on table public.recurring_lesson_series is
  'Weekly local-wall-clock Fixed commitment. Preferred entitlement is optional and is reselected per occurrence.';
comment on table public.recurring_lesson_occurrences is
  'Bounded priority claims and lazy materialization state; not an unbounded future Lesson expansion.';
comment on function private.resolve_scheduling_local_datetime(date,time,text) is
  'Resolves recurring local wall time through IANA tzdata and rejects ambiguous or nonexistent instants.';

commit;
