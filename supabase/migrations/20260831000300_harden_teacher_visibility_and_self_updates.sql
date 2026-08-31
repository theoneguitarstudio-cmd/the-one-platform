begin;

alter table public.specialties
  add column is_active boolean not null default true;

drop policy specialties_read_catalog on public.specialties;
create policy specialties_read_active_catalog
on public.specialties
for select
to anon, authenticated
using (is_active);

create or replace function private.is_discoverable_teacher_profile(
  requested_teacher_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.teacher_public_profiles as projection
    join public.teacher_profiles as teacher
      on teacher.id = projection.teacher_profile_id
    join public.profiles as account
      on account.user_id = teacher.user_id
    where projection.teacher_profile_id = requested_teacher_profile_id
      and projection.is_discoverable
      and projection.public_status = 'active'
      and teacher.is_public
      and teacher.teaching_status = 'active'
      and account.account_status = 'active'
  );
$$;

drop policy teacher_public_profiles_read_discoverable
  on public.teacher_public_profiles;
create policy teacher_public_profiles_read_discoverable
on public.teacher_public_profiles
for select
to anon, authenticated
using ((select private.is_discoverable_teacher_profile(teacher_profile_id)));

create or replace function private.sync_teacher_public_profile(
  requested_teacher_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.teacher_public_profiles (
    teacher_profile_id, public_slug, display_name, avatar_url, bio,
    years_experience, trial_price_twd, fixed_lesson_price_twd,
    flexible_lesson_price_twd, teaching_modes, location_text, public_status,
    is_discoverable, updated_at
  )
  select
    teacher.id, teacher.public_slug, account.display_name, teacher.avatar_url,
    teacher.bio, teacher.years_experience, teacher.trial_price_twd,
    teacher.fixed_lesson_price_twd, teacher.flexible_lesson_price_twd,
    teacher.teaching_modes, teacher.location_text, teacher.teaching_status,
    teacher.is_public
      and teacher.teaching_status = 'active'
      and account.account_status = 'active',
    now()
  from public.teacher_profiles as teacher
  join public.profiles as account on account.user_id = teacher.user_id
  where teacher.id = requested_teacher_profile_id
  on conflict (teacher_profile_id) do update
  set
    public_slug = excluded.public_slug,
    display_name = excluded.display_name,
    avatar_url = excluded.avatar_url,
    bio = excluded.bio,
    years_experience = excluded.years_experience,
    trial_price_twd = excluded.trial_price_twd,
    fixed_lesson_price_twd = excluded.fixed_lesson_price_twd,
    flexible_lesson_price_twd = excluded.flexible_lesson_price_twd,
    teaching_modes = excluded.teaching_modes,
    location_text = excluded.location_text,
    public_status = excluded.public_status,
    is_discoverable = excluded.is_discoverable,
    updated_at = now();
end;
$$;

create or replace function private.sync_teacher_public_profile_from_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  teacher_profile record;
begin
  for teacher_profile in
    select teacher.id
    from public.teacher_profiles as teacher
    where teacher.user_id = new.user_id
  loop
    perform private.sync_teacher_public_profile(teacher_profile.id);
  end loop;

  return new;
end;
$$;

drop trigger profiles_sync_teacher_display_name on public.profiles;
create trigger profiles_sync_teacher_public_projection
after update of display_name, account_status on public.profiles
for each row execute function private.sync_teacher_public_profile_from_account();

revoke update on table public.teacher_profiles from authenticated;
revoke insert, delete on table public.teacher_specialties from authenticated;

create or replace function public.update_own_teacher_profile(
  p_bio text,
  p_avatar_url text,
  p_years_experience smallint,
  p_trial_price_twd integer,
  p_fixed_lesson_price_twd integer,
  p_flexible_lesson_price_twd integer,
  p_teaching_modes public.teaching_mode[],
  p_location_text text,
  p_specialty_ids uuid[]
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
    or not exists (
      select 1 from public.profiles as account
      where account.user_id = current_user_id
        and account.account_status = 'active'
    )
    or not exists (
      select 1 from public.user_roles as assignment
      where assignment.user_id = current_user_id
        and assignment.role = 'teacher'
    ) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if p_bio is null
    or char_length(p_bio) > 4000
    or (p_avatar_url is not null and (
      char_length(p_avatar_url) > 2048 or p_avatar_url !~ '^https://'
    ))
    or p_years_experience is null
    or p_years_experience not between 0 and 80
    or (p_trial_price_twd is not null and p_trial_price_twd < 0)
    or (p_fixed_lesson_price_twd is not null and p_fixed_lesson_price_twd < 0)
    or (p_flexible_lesson_price_twd is not null and p_flexible_lesson_price_twd < 0)
    or p_teaching_modes is null
    or cardinality(p_teaching_modes) > 2
    or p_location_text is not null and char_length(p_location_text) > 160
    or p_specialty_ids is null then
    raise exception 'invalid teacher profile input' using errcode = '23514';
  end if;

  if exists (
    select 1 from unnest(p_teaching_modes) as teaching_mode
    group by teaching_mode having count(*) > 1
  ) then
    raise exception 'duplicate teaching mode' using errcode = '23514';
  end if;

  if cardinality(p_specialty_ids) <> (
    select count(distinct specialty_id)
    from unnest(p_specialty_ids) as specialty_id
  ) then
    raise exception 'duplicate specialty' using errcode = '23514';
  end if;

  if exists (
    select 1
    from unnest(p_specialty_ids) as requested_specialty(id)
    left join public.specialties as specialty
      on specialty.id = requested_specialty.id
    where specialty.id is null or not specialty.is_active
  ) then
    raise exception 'invalid specialty' using errcode = '23514';
  end if;

  update public.teacher_profiles
  set
    bio = p_bio,
    avatar_url = p_avatar_url,
    years_experience = p_years_experience,
    trial_price_twd = p_trial_price_twd,
    fixed_lesson_price_twd = p_fixed_lesson_price_twd,
    flexible_lesson_price_twd = p_flexible_lesson_price_twd,
    teaching_modes = p_teaching_modes,
    location_text = p_location_text
  where user_id = current_user_id;

  if not found then
    raise exception 'teacher profile not found' using errcode = 'P0002';
  end if;

  delete from public.teacher_specialties as assignment
  where assignment.teacher_profile_id = (
    select teacher.id from public.teacher_profiles as teacher
    where teacher.user_id = current_user_id
  );

  insert into public.teacher_specialties (teacher_profile_id, specialty_id)
  select teacher.id, requested_specialty.id
  from public.teacher_profiles as teacher
  cross join unnest(p_specialty_ids) as requested_specialty(id)
  where teacher.user_id = current_user_id;
end;
$$;

revoke all on function public.update_own_teacher_profile(
  text, text, smallint, integer, integer, integer,
  public.teaching_mode[], text, uuid[]
) from public, anon;
grant execute on function public.update_own_teacher_profile(
  text, text, smallint, integer, integer, integer,
  public.teaching_mode[], text, uuid[]
) to authenticated;

commit;
