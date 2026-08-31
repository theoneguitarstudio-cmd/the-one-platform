begin;

create schema if not exists private;

create type public.app_role as enum (
  'student',
  'teacher',
  'admin',
  'super_admin'
);

create type public.account_status as enum (
  'active',
  'suspended',
  'disabled'
);

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete restrict,
  display_name text not null
    check (char_length(display_name) between 2 and 80),
  phone text
    check (phone is null or char_length(phone) between 7 and 32),
  avatar_url text
    check (
      avatar_url is null
      or (
        char_length(avatar_url) <= 2048
        and avatar_url ~ '^https://'
      )
    ),
  timezone text not null default 'Asia/Taipei'
    check (
      timezone = 'UTC'
      or timezone ~ '^[A-Za-z_]+(/[A-Za-z0-9._+-]+)+$'
    ),
  locale text not null default 'zh-TW'
    check (locale ~ '^[a-z]{2,3}(-[A-Z]{2})?$'),
  account_status public.account_status not null default 'active',
  legacy_wordpress_user_id bigint unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete restrict,
  role public.app_role not null,
  assigned_at timestamptz not null default now(),
  assigned_by uuid references auth.users (id) on delete set null,
  unique (user_id, role)
);

create table public.public_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete restrict,
  display_name text not null
    check (char_length(display_name) between 2 and 80),
  avatar_url text
    check (
      avatar_url is null
      or (
        char_length(avatar_url) <= 2048
        and avatar_url ~ '^https://'
      )
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Private account profile. Never use as a public teacher profile source.';
comment on table public.public_profiles is
  'Explicit public-profile boundary. No client grants or policies in Epic 1.';
comment on table public.user_roles is
  'Application roles. Mutations require a trusted server-side administrative path.';

create index profiles_user_id_idx on public.profiles (user_id);
create index user_roles_user_id_idx on public.user_roles (user_id);
create index user_roles_role_idx on public.user_roles (role);

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.public_profiles enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.user_roles from anon, authenticated;
revoke all on table public.public_profiles from anon, authenticated;

grant select on table public.profiles to authenticated;
grant update (
  display_name,
  phone,
  avatar_url,
  timezone,
  locale
) on table public.profiles to authenticated;
grant select on table public.user_roles to authenticated;

grant all on table public.profiles to service_role;
grant all on table public.user_roles to service_role;
grant all on table public.public_profiles to service_role;

create or replace function private.current_user_is_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where user_id = (select auth.uid())
      and account_status = 'active'
  );
$$;

revoke all on function private.current_user_is_active() from public;
grant usage on schema private to authenticated;
grant execute on function private.current_user_is_active() to authenticated;

create policy profiles_select_own_active
on public.profiles
for select
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and (select private.current_user_is_active())
);

create policy profiles_update_own_allowed_fields
on public.profiles
for update
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and (select private.current_user_is_active())
)
with check (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and (select private.current_user_is_active())
);

create policy user_roles_select_own_active
on public.user_roles
for select
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and (select private.current_user_is_active())
);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function private.set_updated_at() from public, anon, authenticated;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create trigger public_profiles_set_updated_at
before update on public.public_profiles
for each row execute function private.set_updated_at();

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_display_name text;
begin
  requested_display_name := nullif(
    trim(coalesce(new.raw_user_meta_data ->> 'display_name', '')),
    ''
  );

  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    left(coalesce(requested_display_name, 'The One 學員'), 80)
  );

  insert into public.user_roles (user_id, role)
  values (new.id, 'student');

  return new;
end;
$$;

revoke all on function private.handle_new_auth_user()
from public, anon, authenticated;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_auth_user();

commit;
