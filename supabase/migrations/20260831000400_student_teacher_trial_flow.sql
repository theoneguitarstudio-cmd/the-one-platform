begin;

create extension if not exists btree_gist with schema extensions;

create type public.student_onboarding_status as enum ('incomplete', 'complete');
create type public.student_teacher_relationship_status as enum (
  'trial', 'awaiting_conversion', 'active', 'paused', 'ended', 'transferred'
);
create type public.lesson_type as enum ('trial', 'fixed', 'flexible', 'makeup');
create type public.lesson_status as enum (
  'scheduled', 'completed', 'student_cancelled', 'student_late_cancel',
  'student_no_show', 'teacher_cancelled', 'rescheduled', 'admin_cancelled'
);
create type public.meeting_provider as enum (
  'manual_google_meet', 'manual_zoom', 'manual_url'
);
create type public.trial_payment_status as enum ('pending', 'paid', 'cancelled');
create type public.assessment_type as enum ('teacher_trial_assessment');
create type public.recommendation_type as enum (
  'recorded_course', 'one_to_one', 'hybrid'
);

alter table public.teacher_profiles
  add column default_meeting_provider public.meeting_provider,
  add column default_meeting_url text
    check (
      default_meeting_url is null
      or (
        char_length(default_meeting_url) <= 2048
        and default_meeting_url ~ '^https://'
      )
    ),
  add constraint teacher_default_meeting_complete
    check (
      (default_meeting_provider is null) = (default_meeting_url is null)
    );

create table public.student_profiles (
  user_id uuid primary key references auth.users (id) on delete restrict,
  learning_goal text not null default '' check (char_length(learning_goal) <= 1000),
  preferred_mode public.teaching_mode,
  preferred_location text check (
    preferred_location is null or char_length(preferred_location) <= 160
  ),
  onboarding_status public.student_onboarding_status not null default 'incomplete',
  current_stage smallint references public.learning_map_stages (stage_number) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.student_teacher_relationships (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references auth.users (id) on delete restrict,
  teacher_user_id uuid not null references auth.users (id) on delete restrict,
  relationship_status public.student_teacher_relationship_status not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  preferred_mode public.teaching_mode not null,
  notes text check (notes is null or char_length(notes) <= 2000),
  internal_notes text check (internal_notes is null or char_length(internal_notes) <= 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (student_user_id <> teacher_user_id),
  check (ended_at is null or ended_at >= started_at),
  unique (id, student_user_id, teacher_user_id)
);

create unique index student_teacher_one_open_relationship_idx
on public.student_teacher_relationships (student_user_id, teacher_user_id)
where relationship_status in ('trial', 'awaiting_conversion', 'active', 'paused');

create table public.trial_orders (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique
    check (char_length(idempotency_key) between 16 and 160),
  student_user_id uuid not null references auth.users (id) on delete restrict,
  teacher_user_id uuid not null references auth.users (id) on delete restrict,
  delivery_mode public.teaching_mode not null,
  proposed_starts_at timestamptz not null,
  timezone text not null check (char_length(timezone) between 3 and 80),
  price_twd integer not null check (price_twd >= 0),
  payment_status public.trial_payment_status not null default 'pending',
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (student_user_id <> teacher_user_id),
  check (
    (payment_status = 'paid' and confirmed_at is not null)
    or (payment_status <> 'paid' and confirmed_at is null)
  ),
  unique (id, student_user_id, teacher_user_id)
);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references auth.users (id) on delete restrict,
  teacher_user_id uuid not null references auth.users (id) on delete restrict,
  relationship_id uuid not null references public.student_teacher_relationships (id) on delete restrict,
  trial_order_id uuid unique references public.trial_orders (id) on delete restrict,
  lesson_type public.lesson_type not null,
  delivery_mode public.teaching_mode not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  duration_minutes smallint not null check (duration_minutes between 1 and 480),
  timezone_anchor text not null check (char_length(timezone_anchor) between 3 and 80),
  status public.lesson_status not null default 'scheduled',
  meeting_provider public.meeting_provider,
  meeting_url text check (
    meeting_url is null
    or (char_length(meeting_url) <= 2048 and meeting_url ~ '^https://')
  ),
  location_text text check (location_text is null or char_length(location_text) <= 160),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (student_user_id <> teacher_user_id),
  check (starts_at < ends_at),
  check (ends_at = starts_at + duration_minutes * interval '1 minute'),
  check (lesson_type <> 'trial' or duration_minutes = 50),
  check (lesson_type = 'trial' or trial_order_id is null),
  check (
    (delivery_mode = 'online' and meeting_provider is not null and meeting_url is not null)
    or (delivery_mode = 'onsite' and meeting_provider is null and meeting_url is null)
  ),
  foreign key (relationship_id, student_user_id, teacher_user_id)
    references public.student_teacher_relationships (id, student_user_id, teacher_user_id)
    on delete restrict,
  foreign key (trial_order_id, student_user_id, teacher_user_id)
    references public.trial_orders (id, student_user_id, teacher_user_id)
    on delete restrict
);

alter table public.lessons
  add constraint lessons_teacher_no_overlap
  exclude using gist (
    teacher_user_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status = 'scheduled');

alter table public.lessons
  add constraint lessons_student_no_overlap
  exclude using gist (
    student_user_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status = 'scheduled');

create table public.lesson_records (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null unique references public.lessons (id) on delete restrict,
  stage_number smallint references public.learning_map_stages (stage_number) on delete set null,
  student_visible_notes text not null default '' check (char_length(student_visible_notes) <= 4000),
  private_teacher_notes text not null default '' check (char_length(private_teacher_notes) <= 4000),
  performance_summary text not null default '' check (char_length(performance_summary) <= 4000),
  next_goal text not null default '' check (char_length(next_goal) <= 2000),
  homework text not null default '' check (char_length(homework) <= 2000),
  completed_at timestamptz not null,
  completed_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references auth.users (id) on delete restrict,
  teacher_user_id uuid not null references auth.users (id) on delete restrict,
  lesson_id uuid not null unique references public.lessons (id) on delete restrict,
  assessment_type public.assessment_type not null default 'teacher_trial_assessment',
  primary_stage smallint references public.learning_map_stages (stage_number) on delete set null,
  recommendation_type public.recommendation_type not null,
  summary text not null check (char_length(summary) between 1 and 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index relationships_student_lookup_idx
  on public.student_teacher_relationships (student_user_id, relationship_status);
create index relationships_teacher_lookup_idx
  on public.student_teacher_relationships (teacher_user_id, relationship_status);
create index lessons_teacher_starts_at_idx on public.lessons (teacher_user_id, starts_at);
create index lessons_student_starts_at_idx on public.lessons (student_user_id, starts_at);
create index lessons_trial_status_idx on public.lessons (status, starts_at)
  where lesson_type = 'trial';
create index trial_orders_status_idx on public.trial_orders (payment_status, created_at);
create index assessments_lesson_lookup_idx on public.assessments (lesson_id);

alter table public.student_profiles enable row level security;
alter table public.student_teacher_relationships enable row level security;
alter table public.trial_orders enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_records enable row level security;
alter table public.assessments enable row level security;

revoke all on table public.student_profiles from anon, authenticated;
revoke all on table public.student_teacher_relationships from anon, authenticated;
revoke all on table public.trial_orders from anon, authenticated;
revoke all on table public.lessons from anon, authenticated;
revoke all on table public.lesson_records from anon, authenticated;
revoke all on table public.assessments from anon, authenticated;

grant select on table public.student_profiles to authenticated;
grant select (
  id, student_user_id, teacher_user_id, relationship_status, started_at,
  ended_at, preferred_mode, notes, created_at, updated_at
) on table public.student_teacher_relationships to authenticated;
grant select (
  id, teacher_user_id, delivery_mode, proposed_starts_at, timezone,
  price_twd, payment_status, confirmed_at, created_at, updated_at
) on table public.trial_orders to authenticated;
grant select on table public.lessons to authenticated;
grant select (
  id, lesson_id, stage_number, student_visible_notes, performance_summary,
  next_goal, homework, completed_at, completed_by, created_at, updated_at
) on table public.lesson_records to authenticated;
grant select on table public.assessments to authenticated;

grant all on table public.student_profiles to service_role;
grant all on table public.student_teacher_relationships to service_role;
grant all on table public.trial_orders to service_role;
grant all on table public.lessons to service_role;
grant all on table public.lesson_records to service_role;
grant all on table public.assessments to service_role;

create or replace function private.current_user_participates_in_lesson(
  requested_lesson_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.lessons as lesson
    where lesson.id = requested_lesson_id
      and (select auth.uid()) in (lesson.student_user_id, lesson.teacher_user_id)
      and (select private.current_user_is_active())
  );
$$;

revoke all on function private.current_user_participates_in_lesson(uuid)
  from public, anon, authenticated;
grant execute on function private.current_user_participates_in_lesson(uuid)
  to authenticated;

create policy student_profiles_select_own
on public.student_profiles for select to authenticated
using (
  user_id = (select auth.uid())
  and (select private.current_user_is_active())
  and (select private.current_user_has_role('student'))
);

create policy relationships_select_participant
on public.student_teacher_relationships for select to authenticated
using (
  (select private.current_user_is_active())
  and (select auth.uid()) in (student_user_id, teacher_user_id)
);

create policy trial_orders_select_own_student
on public.trial_orders for select to authenticated
using (
  student_user_id = (select auth.uid())
  and (select private.current_user_is_active())
  and (select private.current_user_has_role('student'))
);

create policy lessons_select_participant
on public.lessons for select to authenticated
using (
  (select private.current_user_is_active())
  and (select auth.uid()) in (student_user_id, teacher_user_id)
);

create policy lesson_records_select_participant
on public.lesson_records for select to authenticated
using ((select private.current_user_participates_in_lesson(lesson_id)));

create policy assessments_select_participant
on public.assessments for select to authenticated
using (
  (select private.current_user_is_active())
  and (select auth.uid()) in (student_user_id, teacher_user_id)
);

create trigger student_profiles_set_updated_at before update on public.student_profiles
for each row execute function private.set_updated_at();
create trigger relationships_set_updated_at before update on public.student_teacher_relationships
for each row execute function private.set_updated_at();
create trigger trial_orders_set_updated_at before update on public.trial_orders
for each row execute function private.set_updated_at();
create trigger lessons_set_updated_at before update on public.lessons
for each row execute function private.set_updated_at();
create trigger lesson_records_set_updated_at before update on public.lesson_records
for each row execute function private.set_updated_at();
create trigger assessments_set_updated_at before update on public.assessments
for each row execute function private.set_updated_at();

create or replace function public.request_trial_checkout(
  p_teacher_slug text,
  p_learning_goal text,
  p_preferred_mode public.teaching_mode,
  p_preferred_location text,
  p_proposed_starts_at timestamptz,
  p_timezone text,
  p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  requested_teacher record;
  existing_order public.trial_orders%rowtype;
  created_order_id uuid;
begin
  if current_user_id is null
    or not (select private.current_user_is_active())
    or not (select private.current_user_has_role('student')) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if p_learning_goal is null or char_length(trim(p_learning_goal)) not between 1 and 1000
    or p_preferred_location is not null and char_length(p_preferred_location) > 160
    or p_proposed_starts_at is null or p_proposed_starts_at <= now()
    or p_timezone is null or not exists (
      select 1 from pg_catalog.pg_timezone_names where name = p_timezone
    )
    or p_idempotency_key is null or char_length(p_idempotency_key) not between 16 and 160 then
    raise exception 'invalid trial request' using errcode = '23514';
  end if;

  select teacher.user_id, teacher.trial_price_twd, teacher.teaching_modes
  into requested_teacher
  from public.teacher_profiles as teacher
  join public.teacher_public_profiles as projection
    on projection.teacher_profile_id = teacher.id
  join public.profiles as account on account.user_id = teacher.user_id
  where teacher.public_slug = p_teacher_slug
    and teacher.is_public
    and teacher.teaching_status = 'active'
    and account.account_status = 'active'
    and projection.is_discoverable
  limit 1;

  if requested_teacher.user_id is null
    or requested_teacher.trial_price_twd is null
    or not (p_preferred_mode = any(requested_teacher.teaching_modes)) then
    raise exception 'teacher unavailable for trial' using errcode = 'P0002';
  end if;

  select * into existing_order from public.trial_orders
  where idempotency_key = p_idempotency_key;
  if found then
    if existing_order.student_user_id <> current_user_id then
      raise exception 'idempotency key belongs to another user' using errcode = '42501';
    end if;
    if existing_order.teacher_user_id <> requested_teacher.user_id
      or existing_order.delivery_mode <> p_preferred_mode
      or existing_order.proposed_starts_at <> p_proposed_starts_at
      or existing_order.timezone <> p_timezone then
      raise exception 'idempotency key payload mismatch' using errcode = '23514';
    end if;
    return existing_order.id;
  end if;

  insert into public.student_profiles (
    user_id, learning_goal, preferred_mode, preferred_location, onboarding_status
  ) values (
    current_user_id, trim(p_learning_goal), p_preferred_mode,
    nullif(trim(coalesce(p_preferred_location, '')), ''), 'complete'
  )
  on conflict (user_id) do update set
    learning_goal = excluded.learning_goal,
    preferred_mode = excluded.preferred_mode,
    preferred_location = excluded.preferred_location,
    onboarding_status = 'complete';

  insert into public.trial_orders (
    idempotency_key, student_user_id, teacher_user_id, delivery_mode,
    proposed_starts_at, timezone, price_twd
  ) values (
    p_idempotency_key, current_user_id, requested_teacher.user_id,
    p_preferred_mode, p_proposed_starts_at, p_timezone,
    requested_teacher.trial_price_twd
  ) returning id into created_order_id;

  return created_order_id;
end;
$$;

create or replace function public.confirm_trial_payment(
  p_order_id uuid,
  p_starts_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  trial_order public.trial_orders%rowtype;
  teacher public.teacher_profiles%rowtype;
  relationship_id uuid;
  lesson_id uuid;
  effective_starts_at timestamptz;
begin
  if current_user_id is null
    or not (select private.current_user_is_active())
    or not (
      (select private.current_user_has_role('admin'))
      or (select private.current_user_has_role('super_admin'))
    ) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select * into trial_order from public.trial_orders
  where id = p_order_id for update;
  if not found then
    raise exception 'trial order not found' using errcode = 'P0002';
  end if;

  select id into lesson_id from public.lessons where trial_order_id = trial_order.id;
  if trial_order.payment_status = 'paid' and lesson_id is not null then
    return lesson_id;
  end if;
  if trial_order.payment_status <> 'pending' then
    raise exception 'trial order cannot be confirmed' using errcode = '23514';
  end if;

  effective_starts_at := coalesce(p_starts_at, trial_order.proposed_starts_at);
  if effective_starts_at is null or effective_starts_at <= now()
    or not exists (
      select 1 from pg_catalog.pg_timezone_names where name = trial_order.timezone
    ) then
    raise exception 'invalid trial schedule' using errcode = '23514';
  end if;

  select * into teacher from public.teacher_profiles
  where user_id = trial_order.teacher_user_id;
  if not found or teacher.teaching_status <> 'active' or not teacher.is_public
    or not exists (
      select 1 from public.profiles as account
      where account.user_id = trial_order.teacher_user_id
        and account.account_status = 'active'
    )
    or not exists (
      select 1 from public.user_roles as role_assignment
      where role_assignment.user_id = trial_order.teacher_user_id
        and role_assignment.role = 'teacher'
    ) then
    raise exception 'teacher unavailable' using errcode = '23514';
  end if;
  if trial_order.delivery_mode = 'online'
    and (teacher.default_meeting_provider is null or teacher.default_meeting_url is null) then
    raise exception 'teacher meeting settings missing' using errcode = '23514';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      trial_order.student_user_id::text || ':' || trial_order.teacher_user_id::text,
      0
    )
  );

  select relation.id into relationship_id
  from public.student_teacher_relationships as relation
  where relation.student_user_id = trial_order.student_user_id
    and relation.teacher_user_id = trial_order.teacher_user_id
    and relation.relationship_status in ('trial', 'awaiting_conversion', 'active', 'paused')
  limit 1;

  if relationship_id is null then
    insert into public.student_teacher_relationships (
      student_user_id, teacher_user_id, relationship_status, preferred_mode
    ) values (
      trial_order.student_user_id, trial_order.teacher_user_id, 'trial',
      trial_order.delivery_mode
    ) returning id into relationship_id;
  end if;

  insert into public.lessons (
    student_user_id, teacher_user_id, relationship_id, trial_order_id,
    lesson_type, delivery_mode, starts_at, ends_at, duration_minutes,
    timezone_anchor, status, meeting_provider, meeting_url, location_text
  ) values (
    trial_order.student_user_id, trial_order.teacher_user_id, relationship_id,
    trial_order.id, 'trial', trial_order.delivery_mode, effective_starts_at,
    effective_starts_at + interval '50 minutes', 50, trial_order.timezone,
    'scheduled',
    case when trial_order.delivery_mode = 'online' then teacher.default_meeting_provider end,
    case when trial_order.delivery_mode = 'online' then teacher.default_meeting_url end,
    case when trial_order.delivery_mode = 'onsite' then teacher.location_text end
  ) returning id into lesson_id;

  update public.trial_orders set
    payment_status = 'paid', confirmed_at = now(), confirmed_by = current_user_id
  where id = trial_order.id;

  return lesson_id;
end;
$$;

create or replace function public.update_own_teacher_meeting_defaults(
  p_provider public.meeting_provider,
  p_url text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
begin
  if current_user_id is null
    or not (select private.current_user_is_active())
    or not (select private.current_user_has_role('teacher')) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if (p_provider is null) <> (p_url is null)
    or p_url is not null and (char_length(p_url) > 2048 or p_url !~ '^https://') then
    raise exception 'invalid meeting defaults' using errcode = '23514';
  end if;
  update public.teacher_profiles set
    default_meeting_provider = p_provider,
    default_meeting_url = p_url
  where user_id = current_user_id;
  if not found then
    raise exception 'teacher profile not found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.complete_trial_lesson(
  p_lesson_id uuid,
  p_stage_number smallint,
  p_student_visible_notes text,
  p_private_teacher_notes text,
  p_performance_summary text,
  p_next_goal text,
  p_homework text,
  p_recommendation_type public.recommendation_type,
  p_assessment_summary text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  trial_lesson public.lessons%rowtype;
  assessment_id uuid;
begin
  if current_user_id is null
    or not (select private.current_user_is_active())
    or not (select private.current_user_has_role('teacher')) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if p_stage_number is null or not exists (
      select 1 from public.learning_map_stages where stage_number = p_stage_number
    )
    or p_student_visible_notes is null or char_length(p_student_visible_notes) > 4000
    or p_private_teacher_notes is null or char_length(p_private_teacher_notes) > 4000
    or p_performance_summary is null or char_length(p_performance_summary) > 4000
    or p_next_goal is null or char_length(p_next_goal) > 2000
    or p_homework is null or char_length(p_homework) > 2000
    or p_assessment_summary is null or char_length(trim(p_assessment_summary)) not between 1 and 4000 then
    raise exception 'invalid trial completion' using errcode = '23514';
  end if;

  select * into trial_lesson from public.lessons where id = p_lesson_id for update;
  if not found or trial_lesson.teacher_user_id <> current_user_id
    or trial_lesson.lesson_type <> 'trial' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if trial_lesson.status = 'completed' then
    select id into assessment_id from public.assessments where lesson_id = trial_lesson.id;
    return assessment_id;
  end if;
  if trial_lesson.status <> 'scheduled' then
    raise exception 'trial lesson cannot be completed' using errcode = '23514';
  end if;

  update public.lessons set status = 'completed' where id = trial_lesson.id;

  insert into public.lesson_records (
    lesson_id, stage_number, student_visible_notes, private_teacher_notes,
    performance_summary, next_goal, homework, completed_at, completed_by
  ) values (
    trial_lesson.id, p_stage_number, p_student_visible_notes,
    p_private_teacher_notes, p_performance_summary, p_next_goal, p_homework,
    now(), current_user_id
  ) on conflict (lesson_id) do nothing;

  insert into public.assessments (
    student_user_id, teacher_user_id, lesson_id, assessment_type,
    primary_stage, recommendation_type, summary
  ) values (
    trial_lesson.student_user_id, trial_lesson.teacher_user_id,
    trial_lesson.id, 'teacher_trial_assessment', p_stage_number,
    p_recommendation_type, trim(p_assessment_summary)
  ) on conflict (lesson_id) do update set
    primary_stage = excluded.primary_stage,
    recommendation_type = excluded.recommendation_type,
    summary = excluded.summary
  returning id into assessment_id;

  update public.student_teacher_relationships set
    relationship_status = 'awaiting_conversion'
  where id = trial_lesson.relationship_id and relationship_status = 'trial';

  return assessment_id;
end;
$$;

create or replace function public.admin_reschedule_trial_lesson(
  p_lesson_id uuid,
  p_starts_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
    or not (select private.current_user_is_active())
    or not (
      (select private.current_user_has_role('admin'))
      or (select private.current_user_has_role('super_admin'))
    ) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if p_starts_at is null or p_starts_at <= now() then
    raise exception 'invalid trial schedule' using errcode = '23514';
  end if;
  update public.lessons set
    starts_at = p_starts_at,
    ends_at = p_starts_at + interval '50 minutes'
  where id = p_lesson_id and lesson_type = 'trial' and status = 'scheduled';
  if not found then raise exception 'trial lesson not found' using errcode = 'P0002'; end if;
end;
$$;

create or replace function public.admin_cancel_trial_lesson(p_lesson_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
    or not (select private.current_user_is_active())
    or not (
      (select private.current_user_has_role('admin'))
      or (select private.current_user_has_role('super_admin'))
    ) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  update public.lessons set status = 'admin_cancelled'
  where id = p_lesson_id and lesson_type = 'trial' and status = 'scheduled';
  if not found then raise exception 'trial lesson not found' using errcode = 'P0002'; end if;
end;
$$;

create or replace function public.get_own_teacher_trials()
returns table (
  lesson_id uuid,
  relationship_id uuid,
  student_display_name text,
  learning_goal text,
  preferred_mode public.teaching_mode,
  student_timezone text,
  starts_at timestamptz,
  ends_at timestamptz,
  delivery_mode public.teaching_mode,
  lesson_status public.lesson_status,
  location_text text,
  has_meeting boolean,
  private_teacher_notes text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
    or not (select private.current_user_is_active())
    or not (select private.current_user_has_role('teacher')) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  return query
  select
    lesson.id,
    lesson.relationship_id,
    account.display_name,
    student.learning_goal,
    student.preferred_mode,
    account.timezone,
    lesson.starts_at,
    lesson.ends_at,
    lesson.delivery_mode,
    lesson.status,
    lesson.location_text,
    lesson.meeting_url is not null,
    coalesce(record.private_teacher_notes, '')
  from public.lessons as lesson
  join public.profiles as account on account.user_id = lesson.student_user_id
  join public.student_profiles as student on student.user_id = lesson.student_user_id
  left join public.lesson_records as record on record.lesson_id = lesson.id
  where lesson.teacher_user_id = (select auth.uid())
    and lesson.lesson_type = 'trial'
  order by lesson.starts_at desc;
end;
$$;

create or replace function public.get_trial_teacher_context(p_teacher_slug text)
returns table (
  public_slug text,
  display_name text,
  trial_price_twd integer,
  teaching_modes public.teaching_mode[],
  location_text text,
  teacher_timezone text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
    or not (select private.current_user_is_active())
    or not (select private.current_user_has_role('student')) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  return query
  select
    teacher.public_slug,
    account.display_name,
    teacher.trial_price_twd,
    teacher.teaching_modes,
    teacher.location_text,
    account.timezone
  from public.teacher_profiles as teacher
  join public.profiles as account on account.user_id = teacher.user_id
  join public.teacher_public_profiles as projection
    on projection.teacher_profile_id = teacher.id
  where teacher.public_slug = p_teacher_slug
    and teacher.is_public
    and teacher.teaching_status = 'active'
    and account.account_status = 'active'
    and projection.is_discoverable;
end;
$$;

create or replace function public.get_own_student_trial_results()
returns table (
  lesson_id uuid,
  teacher_display_name text,
  starts_at timestamptz,
  ends_at timestamptz,
  delivery_mode public.teaching_mode,
  lesson_status public.lesson_status,
  location_text text,
  has_meeting boolean,
  primary_stage smallint,
  student_visible_notes text,
  performance_summary text,
  next_goal text,
  homework text,
  recommendation public.recommendation_type,
  assessment_summary text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
    or not (select private.current_user_is_active())
    or not (select private.current_user_has_role('student')) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  return query
  select
    lesson.id,
    account.display_name,
    lesson.starts_at,
    lesson.ends_at,
    lesson.delivery_mode,
    lesson.status,
    lesson.location_text,
    lesson.meeting_url is not null,
    assessment.primary_stage,
    record.student_visible_notes,
    record.performance_summary,
    record.next_goal,
    record.homework,
    assessment.recommendation_type,
    assessment.summary
  from public.lessons as lesson
  join public.profiles as account on account.user_id = lesson.teacher_user_id
  left join public.lesson_records as record on record.lesson_id = lesson.id
  left join public.assessments as assessment on assessment.lesson_id = lesson.id
  where lesson.student_user_id = (select auth.uid())
    and lesson.lesson_type = 'trial'
  order by lesson.starts_at desc;
end;
$$;

revoke all on function public.request_trial_checkout(
  text, text, public.teaching_mode, text, timestamptz, text, text
) from public, anon;
revoke all on function public.confirm_trial_payment(uuid, timestamptz) from public, anon;
revoke all on function public.update_own_teacher_meeting_defaults(
  public.meeting_provider, text
) from public, anon;
revoke all on function public.complete_trial_lesson(
  uuid, smallint, text, text, text, text, text,
  public.recommendation_type, text
) from public, anon;
revoke all on function public.admin_reschedule_trial_lesson(uuid, timestamptz)
  from public, anon;
revoke all on function public.admin_cancel_trial_lesson(uuid) from public, anon;
revoke all on function public.get_own_teacher_trials() from public, anon;
revoke all on function public.get_own_student_trial_results() from public, anon;
revoke all on function public.get_trial_teacher_context(text) from public, anon;

grant execute on function public.request_trial_checkout(
  text, text, public.teaching_mode, text, timestamptz, text, text
) to authenticated;
grant execute on function public.confirm_trial_payment(uuid, timestamptz) to authenticated;
grant execute on function public.update_own_teacher_meeting_defaults(
  public.meeting_provider, text
) to authenticated;
grant execute on function public.complete_trial_lesson(
  uuid, smallint, text, text, text, text, text,
  public.recommendation_type, text
) to authenticated;
grant execute on function public.admin_reschedule_trial_lesson(uuid, timestamptz)
  to authenticated;
grant execute on function public.admin_cancel_trial_lesson(uuid) to authenticated;
grant execute on function public.get_own_teacher_trials() to authenticated;
grant execute on function public.get_own_student_trial_results() to authenticated;
grant execute on function public.get_trial_teacher_context(text) to authenticated;

commit;
