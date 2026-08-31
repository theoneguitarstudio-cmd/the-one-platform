begin;

create or replace function private.is_safe_trial_meeting_url(
  requested_provider public.meeting_provider,
  requested_url text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when requested_provider is null and requested_url is null then true
    when requested_provider is null or requested_url is null then false
    when requested_provider = 'manual_url' then false
    when char_length(requested_url) > 2048
      or requested_url ~ '[[:cntrl:][:space:]]'
      or position('@' in requested_url) > 0
      or position(pg_catalog.chr(92) in requested_url) > 0 then false
    when requested_provider = 'manual_google_meet' then
      requested_url ~* '^https://meet[.]google[.]com([/?#]|$)'
    when requested_provider = 'manual_zoom' then
      requested_url ~* '^https://([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?[.])*zoom[.]us([/?#]|$)'
    else false
  end;
$$;

create or replace function private.is_valid_iana_timezone(requested_timezone text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select requested_timezone is not null
    and exists (
      select 1
      from pg_catalog.pg_timezone_names
      where name = requested_timezone
    );
$$;

alter function private.is_safe_trial_meeting_url(public.meeting_provider, text)
  owner to postgres;
alter function private.is_valid_iana_timezone(text) owner to postgres;

revoke all on function private.is_safe_trial_meeting_url(
  public.meeting_provider, text
) from public, anon, authenticated;
revoke all on function private.is_valid_iana_timezone(text)
  from public, anon, authenticated;
grant usage on schema private to service_role;
grant execute on function private.is_safe_trial_meeting_url(
  public.meeting_provider, text
) to service_role;
grant execute on function private.is_valid_iana_timezone(text) to service_role;

alter table public.teacher_profiles
  add constraint teacher_profiles_safe_meeting_url
  check (
    private.is_safe_trial_meeting_url(
      default_meeting_provider,
      default_meeting_url
    )
  );

alter table public.trial_orders
  drop constraint trial_orders_idempotency_key_key,
  add constraint trial_orders_student_idempotency_key_key
    unique (student_user_id, idempotency_key),
  add constraint trial_orders_timezone_is_iana
    check (private.is_valid_iana_timezone(timezone));

alter table public.lessons
  add constraint lessons_id_participants_key
    unique (id, student_user_id, teacher_user_id),
  add constraint lessons_id_teacher_key
    unique (id, teacher_user_id),
  add constraint lessons_timezone_anchor_is_iana
    check (private.is_valid_iana_timezone(timezone_anchor)),
  add constraint lessons_safe_meeting_url
    check (
      private.is_safe_trial_meeting_url(meeting_provider, meeting_url)
    );

alter table public.assessments
  add constraint assessments_lesson_participants_fkey
  foreign key (lesson_id, student_user_id, teacher_user_id)
  references public.lessons (id, student_user_id, teacher_user_id)
  on delete restrict;

alter table public.lesson_records
  add constraint lesson_records_completed_by_assigned_teacher_fkey
  foreign key (lesson_id, completed_by)
  references public.lessons (id, teacher_user_id)
  on delete restrict;

revoke select on table public.lessons from authenticated;
grant select (
  id, lesson_type, delivery_mode, starts_at, ends_at, duration_minutes,
  timezone_anchor, status, meeting_provider, meeting_url, location_text,
  created_at, updated_at
) on table public.lessons to authenticated;

revoke select on table public.assessments from authenticated;
grant select (
  id, lesson_id, assessment_type, primary_stage, recommendation_type,
  summary, created_at, updated_at
) on table public.assessments to authenticated;

revoke select (student_user_id, teacher_user_id)
on table public.student_teacher_relationships from authenticated;

revoke select (teacher_user_id, confirmed_at, updated_at)
on table public.trial_orders from authenticated;

revoke select (completed_by, created_at, updated_at)
on table public.lesson_records from authenticated;

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
    or not (select private.is_valid_iana_timezone(p_timezone))
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

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      current_user_id::text || ':' || requested_teacher.user_id::text,
      0
    )
  );

  select * into existing_order
  from public.trial_orders
  where student_user_id = current_user_id
    and idempotency_key = p_idempotency_key;

  if found then
    if existing_order.teacher_user_id <> requested_teacher.user_id
      or existing_order.delivery_mode <> p_preferred_mode
      or existing_order.proposed_starts_at <> p_proposed_starts_at
      or existing_order.timezone <> p_timezone then
      raise exception 'idempotency key payload mismatch' using errcode = '23514';
    end if;
    return existing_order.id;
  end if;

  if exists (
    select 1
    from public.student_teacher_relationships as relation
    where relation.student_user_id = current_user_id
      and relation.teacher_user_id = requested_teacher.user_id
      and relation.relationship_status in (
        'trial', 'awaiting_conversion', 'active', 'paused'
      )
  ) then
    raise exception 'repeat trial is not supported' using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.trial_orders as pending_order
    where pending_order.student_user_id = current_user_id
      and pending_order.teacher_user_id = requested_teacher.user_id
      and pending_order.payment_status = 'pending'
  ) then
    raise exception 'a trial request is already pending' using errcode = '23514';
  end if;

  insert into public.trial_orders (
    idempotency_key, student_user_id, teacher_user_id, delivery_mode,
    proposed_starts_at, timezone, price_twd
  ) values (
    p_idempotency_key, current_user_id, requested_teacher.user_id,
    p_preferred_mode, p_proposed_starts_at, p_timezone,
    requested_teacher.trial_price_twd
  )
  on conflict (student_user_id, idempotency_key) do nothing
  returning id into created_order_id;

  if created_order_id is null then
    select * into existing_order
    from public.trial_orders
    where student_user_id = current_user_id
      and idempotency_key = p_idempotency_key;

    if not found then
      raise exception 'trial request retry could not be resolved' using errcode = '40001';
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
  relationship public.student_teacher_relationships%rowtype;
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

  select * into trial_order
  from public.trial_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'trial order not found' using errcode = 'P0002';
  end if;

  select id into lesson_id
  from public.lessons
  where trial_order_id = trial_order.id;

  if trial_order.payment_status = 'paid' and lesson_id is not null then
    return lesson_id;
  end if;
  if trial_order.payment_status <> 'pending' then
    raise exception 'trial order cannot be confirmed' using errcode = '23514';
  end if;

  effective_starts_at := coalesce(p_starts_at, trial_order.proposed_starts_at);
  if effective_starts_at is null or effective_starts_at <= now()
    or not (select private.is_valid_iana_timezone(trial_order.timezone)) then
    raise exception 'invalid trial schedule' using errcode = '23514';
  end if;

  select * into teacher
  from public.teacher_profiles
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
    and not (
      select private.is_safe_trial_meeting_url(
        teacher.default_meeting_provider,
        teacher.default_meeting_url
      )
    ) then
    raise exception 'teacher meeting settings invalid' using errcode = '23514';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      trial_order.student_user_id::text || ':' || trial_order.teacher_user_id::text,
      0
    )
  );

  select relation.* into relationship
  from public.student_teacher_relationships as relation
  where relation.student_user_id = trial_order.student_user_id
    and relation.teacher_user_id = trial_order.teacher_user_id
    and relation.relationship_status in (
      'trial', 'awaiting_conversion', 'active', 'paused'
    )
  limit 1
  for update;

  if found and relationship.relationship_status <> 'trial' then
    raise exception 'relationship does not permit a trial' using errcode = '23514';
  end if;

  if relationship.id is null then
    insert into public.student_teacher_relationships (
      student_user_id, teacher_user_id, relationship_status, preferred_mode
    ) values (
      trial_order.student_user_id, trial_order.teacher_user_id, 'trial',
      trial_order.delivery_mode
    ) returning * into relationship;
  end if;

  insert into public.lessons (
    student_user_id, teacher_user_id, relationship_id, trial_order_id,
    lesson_type, delivery_mode, starts_at, ends_at, duration_minutes,
    timezone_anchor, status, meeting_provider, meeting_url, location_text
  ) values (
    trial_order.student_user_id, trial_order.teacher_user_id, relationship.id,
    trial_order.id, 'trial', trial_order.delivery_mode, effective_starts_at,
    effective_starts_at + interval '50 minutes', 50, trial_order.timezone,
    'scheduled',
    case when trial_order.delivery_mode = 'online' then teacher.default_meeting_provider end,
    case when trial_order.delivery_mode = 'online' then teacher.default_meeting_url end,
    case when trial_order.delivery_mode = 'onsite' then teacher.location_text end
  ) returning id into lesson_id;

  update public.trial_orders set
    payment_status = 'paid',
    confirmed_at = now(),
    confirmed_by = current_user_id
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

  if not (select private.is_safe_trial_meeting_url(p_provider, p_url)) then
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
    or p_assessment_summary is null
    or char_length(trim(p_assessment_summary)) not between 1 and 4000 then
    raise exception 'invalid trial completion' using errcode = '23514';
  end if;

  select * into trial_lesson
  from public.lessons
  where id = p_lesson_id
  for update;

  if not found or trial_lesson.teacher_user_id <> current_user_id
    or trial_lesson.lesson_type <> 'trial' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if trial_lesson.status = 'completed' then
    select id into assessment_id
    from public.assessments
    where lesson_id = trial_lesson.id;
    return assessment_id;
  end if;

  if trial_lesson.status <> 'scheduled' then
    raise exception 'trial lesson cannot be completed' using errcode = '23514';
  end if;
  if trial_lesson.starts_at > now() then
    raise exception 'trial lesson has not started' using errcode = '23514';
  end if;

  perform 1
  from public.student_teacher_relationships as relation
  where relation.id = trial_lesson.relationship_id
    and relation.student_user_id = trial_lesson.student_user_id
    and relation.teacher_user_id = trial_lesson.teacher_user_id
    and relation.relationship_status = 'trial'
  for update;

  if not found then
    raise exception 'trial relationship is not in trial state' using errcode = '23514';
  end if;

  update public.lessons
  set status = 'completed'
  where id = trial_lesson.id;

  insert into public.lesson_records (
    lesson_id, stage_number, student_visible_notes, private_teacher_notes,
    performance_summary, next_goal, homework, completed_at, completed_by
  ) values (
    trial_lesson.id, p_stage_number, p_student_visible_notes,
    p_private_teacher_notes, p_performance_summary, p_next_goal, p_homework,
    now(), current_user_id
  )
  on conflict (lesson_id) do nothing;

  insert into public.assessments (
    student_user_id, teacher_user_id, lesson_id, assessment_type,
    primary_stage, recommendation_type, summary
  ) values (
    trial_lesson.student_user_id, trial_lesson.teacher_user_id,
    trial_lesson.id, 'teacher_trial_assessment', p_stage_number,
    p_recommendation_type, trim(p_assessment_summary)
  )
  on conflict (lesson_id) do update set
    primary_stage = excluded.primary_stage,
    recommendation_type = excluded.recommendation_type,
    summary = excluded.summary
  returning id into assessment_id;

  update public.student_teacher_relationships
  set relationship_status = 'awaiting_conversion'
  where id = trial_lesson.relationship_id
    and relationship_status = 'trial';

  if not found then
    raise exception 'trial relationship transition failed' using errcode = '40001';
  end if;

  return assessment_id;
end;
$$;

alter function private.current_user_participates_in_lesson(uuid) owner to postgres;
alter function public.request_trial_checkout(
  text, text, public.teaching_mode, text, timestamptz, text, text
) owner to postgres;
alter function public.confirm_trial_payment(uuid, timestamptz) owner to postgres;
alter function public.update_own_teacher_meeting_defaults(
  public.meeting_provider, text
) owner to postgres;
alter function public.complete_trial_lesson(
  uuid, smallint, text, text, text, text, text,
  public.recommendation_type, text
) owner to postgres;
alter function public.admin_reschedule_trial_lesson(uuid, timestamptz)
  owner to postgres;
alter function public.admin_cancel_trial_lesson(uuid) owner to postgres;
alter function public.get_own_teacher_trials() owner to postgres;
alter function public.get_own_student_trial_results() owner to postgres;
alter function public.get_trial_teacher_context(text) owner to postgres;

revoke all on function private.current_user_participates_in_lesson(uuid)
  from public, anon, authenticated;
grant execute on function private.current_user_participates_in_lesson(uuid)
  to authenticated;

revoke all on function public.request_trial_checkout(
  text, text, public.teaching_mode, text, timestamptz, text, text
) from public, anon;
revoke all on function public.confirm_trial_payment(uuid, timestamptz)
  from public, anon;
revoke all on function public.update_own_teacher_meeting_defaults(
  public.meeting_provider, text
) from public, anon;
revoke all on function public.complete_trial_lesson(
  uuid, smallint, text, text, text, text, text,
  public.recommendation_type, text
) from public, anon;
revoke all on function public.admin_reschedule_trial_lesson(uuid, timestamptz)
  from public, anon;
revoke all on function public.admin_cancel_trial_lesson(uuid)
  from public, anon;
revoke all on function public.get_own_teacher_trials() from public, anon;
revoke all on function public.get_own_student_trial_results() from public, anon;
revoke all on function public.get_trial_teacher_context(text) from public, anon;

grant execute on function public.request_trial_checkout(
  text, text, public.teaching_mode, text, timestamptz, text, text
) to authenticated;
grant execute on function public.confirm_trial_payment(uuid, timestamptz)
  to authenticated;
grant execute on function public.update_own_teacher_meeting_defaults(
  public.meeting_provider, text
) to authenticated;
grant execute on function public.complete_trial_lesson(
  uuid, smallint, text, text, text, text, text,
  public.recommendation_type, text
) to authenticated;
grant execute on function public.admin_reschedule_trial_lesson(uuid, timestamptz)
  to authenticated;
grant execute on function public.admin_cancel_trial_lesson(uuid)
  to authenticated;
grant execute on function public.get_own_teacher_trials() to authenticated;
grant execute on function public.get_own_student_trial_results() to authenticated;
grant execute on function public.get_trial_teacher_context(text) to authenticated;

commit;
