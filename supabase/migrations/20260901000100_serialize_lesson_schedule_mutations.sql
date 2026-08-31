begin;

create or replace function private.lock_lesson_schedule_resources(
  p_student_user_id uuid,
  p_teacher_user_id uuid
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  student_lock_key bigint;
  teacher_lock_key bigint;
begin
  if p_student_user_id is null or p_teacher_user_id is null then
    raise exception 'schedule lock resource is required' using errcode = '23514';
  end if;

  student_lock_key := pg_catalog.hashtextextended(
    'the-one:v1:lesson-schedule:student:' || p_student_user_id::text,
    0
  );
  teacher_lock_key := pg_catalog.hashtextextended(
    'the-one:v1:lesson-schedule:teacher:' || p_teacher_user_id::text,
    0
  );

  if student_lock_key < teacher_lock_key then
    perform pg_catalog.pg_advisory_xact_lock(student_lock_key);
    perform pg_catalog.pg_advisory_xact_lock(teacher_lock_key);
  elsif teacher_lock_key < student_lock_key then
    perform pg_catalog.pg_advisory_xact_lock(teacher_lock_key);
    perform pg_catalog.pg_advisory_xact_lock(student_lock_key);
  else
    perform pg_catalog.pg_advisory_xact_lock(student_lock_key);
  end if;
end;
$$;

alter function private.lock_lesson_schedule_resources(uuid, uuid)
  owner to postgres;
revoke all on function private.lock_lesson_schedule_resources(uuid, uuid)
  from public, anon, authenticated;

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

  -- Every mutation that enters or leaves the scheduled exclusion predicate
  -- takes these two resource locks in the helper's canonical numeric order.
  perform private.lock_lesson_schedule_resources(
    trial_order.student_user_id,
    trial_order.teacher_user_id
  );

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
  schedule_student_user_id uuid;
  schedule_teacher_user_id uuid;
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

  select lesson.student_user_id, lesson.teacher_user_id
  into schedule_student_user_id, schedule_teacher_user_id
  from public.lessons as lesson
  where lesson.id = p_lesson_id
    and lesson.teacher_user_id = current_user_id
    and lesson.lesson_type = 'trial';

  if not found then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  perform private.lock_lesson_schedule_resources(
    schedule_student_user_id,
    schedule_teacher_user_id
  );

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

create or replace function public.admin_reschedule_trial_lesson(
  p_lesson_id uuid,
  p_starts_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  schedule_student_user_id uuid;
  schedule_teacher_user_id uuid;
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

  select lesson.student_user_id, lesson.teacher_user_id
  into schedule_student_user_id, schedule_teacher_user_id
  from public.lessons as lesson
  where lesson.id = p_lesson_id
    and lesson.lesson_type = 'trial'
    and lesson.status = 'scheduled';

  if not found then
    raise exception 'trial lesson not found' using errcode = 'P0002';
  end if;

  perform private.lock_lesson_schedule_resources(
    schedule_student_user_id,
    schedule_teacher_user_id
  );

  update public.lessons set
    starts_at = p_starts_at,
    ends_at = p_starts_at + interval '50 minutes'
  where id = p_lesson_id and lesson_type = 'trial' and status = 'scheduled';

  if not found then
    raise exception 'trial lesson not found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.admin_cancel_trial_lesson(p_lesson_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  schedule_student_user_id uuid;
  schedule_teacher_user_id uuid;
begin
  if (select auth.uid()) is null
    or not (select private.current_user_is_active())
    or not (
      (select private.current_user_has_role('admin'))
      or (select private.current_user_has_role('super_admin'))
    ) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select lesson.student_user_id, lesson.teacher_user_id
  into schedule_student_user_id, schedule_teacher_user_id
  from public.lessons as lesson
  where lesson.id = p_lesson_id
    and lesson.lesson_type = 'trial'
    and lesson.status = 'scheduled';

  if not found then
    raise exception 'trial lesson not found' using errcode = 'P0002';
  end if;

  perform private.lock_lesson_schedule_resources(
    schedule_student_user_id,
    schedule_teacher_user_id
  );

  update public.lessons set status = 'admin_cancelled'
  where id = p_lesson_id and lesson_type = 'trial' and status = 'scheduled';

  if not found then
    raise exception 'trial lesson not found' using errcode = 'P0002';
  end if;
end;
$$;

alter function public.confirm_trial_payment(uuid, timestamptz) owner to postgres;
alter function public.complete_trial_lesson(
  uuid, smallint, text, text, text, text, text,
  public.recommendation_type, text
) owner to postgres;
alter function public.admin_reschedule_trial_lesson(uuid, timestamptz)
  owner to postgres;
alter function public.admin_cancel_trial_lesson(uuid) owner to postgres;

revoke all on function public.confirm_trial_payment(uuid, timestamptz)
  from public, anon;
revoke all on function public.complete_trial_lesson(
  uuid, smallint, text, text, text, text, text,
  public.recommendation_type, text
) from public, anon;
revoke all on function public.admin_reschedule_trial_lesson(uuid, timestamptz)
  from public, anon;
revoke all on function public.admin_cancel_trial_lesson(uuid)
  from public, anon;

grant execute on function public.confirm_trial_payment(uuid, timestamptz)
  to authenticated;
grant execute on function public.complete_trial_lesson(
  uuid, smallint, text, text, text, text, text,
  public.recommendation_type, text
) to authenticated;
grant execute on function public.admin_reschedule_trial_lesson(uuid, timestamptz)
  to authenticated;
grant execute on function public.admin_cancel_trial_lesson(uuid)
  to authenticated;

commit;
