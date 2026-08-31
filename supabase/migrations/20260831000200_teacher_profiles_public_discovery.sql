begin;

create type public.teaching_status as enum (
  'draft',
  'active',
  'paused',
  'inactive'
);

create type public.teaching_mode as enum (
  'onsite',
  'online'
);

create type public.teacher_stage_capability_status as enum (
  'allowed',
  'certified'
);

create table public.teacher_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete restrict,
  public_slug text not null unique
    check (
      public_slug = lower(public_slug)
      and public_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
      and char_length(public_slug) between 3 and 80
    ),
  bio text not null default ''
    check (char_length(bio) <= 4000),
  avatar_url text
    check (
      avatar_url is null
      or (
        char_length(avatar_url) <= 2048
        and avatar_url ~ '^https://'
      )
    ),
  teaching_status public.teaching_status not null default 'draft',
  years_experience smallint not null default 0
    check (years_experience between 0 and 80),
  trial_price_twd integer
    check (trial_price_twd is null or trial_price_twd >= 0),
  fixed_lesson_price_twd integer
    check (fixed_lesson_price_twd is null or fixed_lesson_price_twd >= 0),
  flexible_lesson_price_twd integer
    check (flexible_lesson_price_twd is null or flexible_lesson_price_twd >= 0),
  teaching_modes public.teaching_mode[] not null default '{}'
    check (
      teaching_modes <@ array['onsite', 'online']::public.teaching_mode[]
    ),
  location_text text
    check (location_text is null or char_length(location_text) <= 160),
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.teacher_public_profiles (
  teacher_profile_id uuid primary key
    references public.teacher_profiles (id) on delete cascade,
  public_slug text not null unique,
  display_name text not null,
  avatar_url text,
  bio text not null,
  years_experience smallint not null,
  trial_price_twd integer,
  fixed_lesson_price_twd integer,
  flexible_lesson_price_twd integer,
  teaching_modes public.teaching_mode[] not null,
  location_text text,
  public_status public.teaching_status not null,
  is_discoverable boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.specialties (
  id uuid primary key default gen_random_uuid(),
  code text not null unique
    check (
      code = lower(code)
      and code ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'
    ),
  display_name text not null unique
    check (char_length(display_name) between 2 and 80),
  created_at timestamptz not null default now()
);

create table public.teacher_specialties (
  teacher_profile_id uuid not null
    references public.teacher_profiles (id) on delete cascade,
  specialty_id uuid not null
    references public.specialties (id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (teacher_profile_id, specialty_id)
);

create table public.learning_map_stages (
  stage_number smallint primary key check (stage_number between 1 and 5),
  code text not null unique
    check (code ~ '^stage_[1-5]$'),
  display_name text not null,
  created_at timestamptz not null default now()
);

create table public.teacher_stage_capabilities (
  teacher_profile_id uuid not null
    references public.teacher_profiles (id) on delete cascade,
  stage_number smallint not null
    references public.learning_map_stages (stage_number) on delete restrict,
  capability_status public.teacher_stage_capability_status not null default 'allowed',
  assigned_at timestamptz not null default now(),
  assigned_by uuid references auth.users (id) on delete set null,
  primary key (teacher_profile_id, stage_number)
);

comment on table public.teacher_profiles is
  'Private teacher platform record. Never grant anonymous access or use directly for public discovery.';
comment on table public.teacher_public_profiles is
  'Minimal public teacher projection. This is the only teacher-profile source for public routes.';
comment on table public.specialties is
  'Platform-defined teacher specialty catalog.';
comment on table public.learning_map_stages is
  'The canonical Guitar Learning Map stage catalog.';

create index teacher_profiles_user_id_idx on public.teacher_profiles (user_id);
create index teacher_public_profiles_discoverable_idx
  on public.teacher_public_profiles (is_discoverable, public_slug);
create index teacher_specialties_teacher_profile_id_idx
  on public.teacher_specialties (teacher_profile_id);
create index teacher_stage_capabilities_teacher_profile_id_idx
  on public.teacher_stage_capabilities (teacher_profile_id);

alter table public.teacher_profiles enable row level security;
alter table public.teacher_public_profiles enable row level security;
alter table public.specialties enable row level security;
alter table public.teacher_specialties enable row level security;
alter table public.learning_map_stages enable row level security;
alter table public.teacher_stage_capabilities enable row level security;

revoke all on table public.teacher_profiles from anon, authenticated;
revoke all on table public.teacher_public_profiles from anon, authenticated;
revoke all on table public.specialties from anon, authenticated;
revoke all on table public.teacher_specialties from anon, authenticated;
revoke all on table public.learning_map_stages from anon, authenticated;
revoke all on table public.teacher_stage_capabilities from anon, authenticated;

grant select on table public.teacher_profiles to authenticated;
grant update (
  bio,
  avatar_url,
  years_experience,
  trial_price_twd,
  fixed_lesson_price_twd,
  flexible_lesson_price_twd,
  teaching_modes,
  location_text
) on table public.teacher_profiles to authenticated;

grant select on table public.teacher_public_profiles to anon, authenticated;
grant select on table public.specialties to anon, authenticated;
grant select on table public.learning_map_stages to anon, authenticated;
grant select on table public.teacher_specialties to anon, authenticated;
grant insert, delete on table public.teacher_specialties to authenticated;
grant select on table public.teacher_stage_capabilities to anon, authenticated;

grant all on table public.teacher_profiles to service_role;
grant all on table public.teacher_public_profiles to service_role;
grant all on table public.specialties to service_role;
grant all on table public.teacher_specialties to service_role;
grant all on table public.learning_map_stages to service_role;
grant all on table public.teacher_stage_capabilities to service_role;

create or replace function private.current_user_has_role(
  expected_role public.app_role
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = expected_role
  );
$$;

create or replace function private.current_user_owns_teacher_profile(
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
    from public.teacher_profiles
    where id = requested_teacher_profile_id
      and user_id = (select auth.uid())
  );
$$;

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
    from public.teacher_public_profiles
    where teacher_profile_id = requested_teacher_profile_id
      and is_discoverable
  );
$$;

revoke all on function private.current_user_has_role(public.app_role) from public;
revoke all on function private.current_user_owns_teacher_profile(uuid) from public;
revoke all on function private.is_discoverable_teacher_profile(uuid) from public;
grant usage on schema private to anon, authenticated;
grant execute on function private.current_user_has_role(public.app_role) to authenticated;
grant execute on function private.current_user_owns_teacher_profile(uuid) to authenticated;
grant execute on function private.is_discoverable_teacher_profile(uuid) to anon, authenticated;

create policy teacher_profiles_select_own_active_teacher
on public.teacher_profiles
for select
to authenticated
using (
  (select auth.uid()) = user_id
  and (select private.current_user_is_active())
  and (select private.current_user_has_role('teacher'))
);

create policy teacher_profiles_update_own_editable_fields
on public.teacher_profiles
for update
to authenticated
using (
  (select auth.uid()) = user_id
  and (select private.current_user_is_active())
  and (select private.current_user_has_role('teacher'))
)
with check (
  (select auth.uid()) = user_id
  and (select private.current_user_is_active())
  and (select private.current_user_has_role('teacher'))
);

create policy teacher_public_profiles_read_discoverable
on public.teacher_public_profiles
for select
to anon, authenticated
using (is_discoverable and public_status = 'active');

create policy specialties_read_catalog
on public.specialties
for select
to anon, authenticated
using (true);

create policy learning_map_stages_read_catalog
on public.learning_map_stages
for select
to anon, authenticated
using (true);

create policy teacher_specialties_read_discoverable
on public.teacher_specialties
for select
to anon, authenticated
using ((select private.is_discoverable_teacher_profile(teacher_profile_id)));

create policy teacher_specialties_read_own_active_teacher
on public.teacher_specialties
for select
to authenticated
using (
  (select private.current_user_is_active())
  and (select private.current_user_has_role('teacher'))
  and (select private.current_user_owns_teacher_profile(teacher_profile_id))
);

create policy teacher_specialties_insert_own_active_teacher
on public.teacher_specialties
for insert
to authenticated
with check (
  (select private.current_user_is_active())
  and (select private.current_user_has_role('teacher'))
  and (select private.current_user_owns_teacher_profile(teacher_profile_id))
);

create policy teacher_specialties_delete_own_active_teacher
on public.teacher_specialties
for delete
to authenticated
using (
  (select private.current_user_is_active())
  and (select private.current_user_has_role('teacher'))
  and (select private.current_user_owns_teacher_profile(teacher_profile_id))
);

create policy teacher_stage_capabilities_read_discoverable
on public.teacher_stage_capabilities
for select
to anon, authenticated
using ((select private.is_discoverable_teacher_profile(teacher_profile_id)));

create policy teacher_stage_capabilities_read_own_active_teacher
on public.teacher_stage_capabilities
for select
to authenticated
using (
  (select private.current_user_is_active())
  and (select private.current_user_has_role('teacher'))
  and (select private.current_user_owns_teacher_profile(teacher_profile_id))
);

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
    teacher_profile_id,
    public_slug,
    display_name,
    avatar_url,
    bio,
    years_experience,
    trial_price_twd,
    fixed_lesson_price_twd,
    flexible_lesson_price_twd,
    teaching_modes,
    location_text,
    public_status,
    is_discoverable,
    updated_at
  )
  select
    teacher.id,
    teacher.public_slug,
    account.display_name,
    teacher.avatar_url,
    teacher.bio,
    teacher.years_experience,
    teacher.trial_price_twd,
    teacher.fixed_lesson_price_twd,
    teacher.flexible_lesson_price_twd,
    teacher.teaching_modes,
    teacher.location_text,
    teacher.teaching_status,
    teacher.is_public and teacher.teaching_status = 'active',
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

create or replace function private.sync_teacher_public_profile_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.teacher_public_profiles
    where teacher_profile_id = old.id;
    return old;
  end if;

  perform private.sync_teacher_public_profile(new.id);
  return new;
end;
$$;

create or replace function private.sync_teacher_public_profile_from_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.teacher_public_profiles as projection
  set
    display_name = new.display_name,
    updated_at = now()
  from public.teacher_profiles as teacher
  where projection.teacher_profile_id = teacher.id
    and teacher.user_id = new.user_id;
  return new;
end;
$$;

revoke all on function private.sync_teacher_public_profile(uuid) from public, anon, authenticated;
revoke all on function private.sync_teacher_public_profile_trigger() from public, anon, authenticated;
revoke all on function private.sync_teacher_public_profile_from_account() from public, anon, authenticated;

create trigger teacher_profiles_sync_public_projection
after insert or update or delete on public.teacher_profiles
for each row execute function private.sync_teacher_public_profile_trigger();

create trigger profiles_sync_teacher_display_name
after update of display_name on public.profiles
for each row execute function private.sync_teacher_public_profile_from_account();

create trigger teacher_profiles_set_updated_at
before update on public.teacher_profiles
for each row execute function private.set_updated_at();

insert into public.specialties (code, display_name)
values
  ('adult_beginner', '成人初學'),
  ('kids', '兒童吉他'),
  ('rhythm', '節奏訓練'),
  ('pop_accompaniment', '流行伴奏'),
  ('fingerstyle', '指彈吉他'),
  ('theory', '樂理'),
  ('fretboard', '指板訓練'),
  ('electric_guitar', '電吉他'),
  ('songwriting', '創作寫歌')
on conflict (code) do update
set display_name = excluded.display_name;

insert into public.learning_map_stages (stage_number, code, display_name)
values
  (1, 'stage_1', '0 到 1 基礎伴奏篇'),
  (2, 'stage_2', '技巧精煉／伴奏篇'),
  (3, 'stage_3', '樂理指板篇'),
  (4, 'stage_4', '聽寫轉換篇'),
  (5, 'stage_5', '改編創作篇')
on conflict (stage_number) do update
set
  code = excluded.code,
  display_name = excluded.display_name;

commit;
