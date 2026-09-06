begin;

create table public.system_courses (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug)<=100),
  title text not null check (length(trim(title)) between 1 and 200),
  archived boolean not null default false,
  withdrawn boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.learning_maps (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.system_courses(id) on delete restrict,
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug)<=100),
  unique(course_id,slug), unique(course_id,id)
);
create table public.curriculum_publications (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null,
  map_id uuid not null,
  version_number integer not null check(version_number>0),
  revision integer not null default 0 check(revision>=0),
  state text not null default 'draft' check(state='draft'),
  course_title text not null check(length(trim(course_title)) between 1 and 200),
  base_version_id uuid,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key(course_id,map_id) references public.learning_maps(course_id,id) on delete restrict,
  unique(course_id,map_id,id), unique(course_id,id), unique(map_id,version_number),
  foreign key(course_id,map_id,base_version_id)
    references public.curriculum_publications(course_id,map_id,id) on delete restrict
);
create unique index curriculum_one_draft on public.curriculum_publications(map_id) where state='draft';
create index curriculum_base_version on public.curriculum_publications(base_version_id);
create index curriculum_created_by on public.curriculum_publications(created_by);

alter table public.system_courses enable row level security;
alter table public.learning_maps enable row level security;
alter table public.curriculum_publications enable row level security;
revoke all on public.system_courses,public.learning_maps,public.curriculum_publications
  from public,anon,authenticated,service_role;

create function private.learning_require_admin() returns uuid
language plpgsql set search_path='' as $$
declare actor uuid := auth.uid();
begin
  if actor is null or not private.current_user_is_active()
    or not private.current_user_has_role(array['admin','super_admin']::public.app_role[]) then
    raise exception 'learning:not_authorized' using errcode='42501';
  end if;
  return actor;
end; $$;
revoke all on function private.learning_require_admin() from public,anon,authenticated,service_role;

-- Stable caller-supplied UUIDs are idempotency identities, never authority.
create function public.learning_create_course(p_course uuid,p_slug text,p_title text,p_map uuid,p_map_slug text)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid; c public.system_courses; m public.learning_maps;
begin
  actor := private.learning_require_admin();
  if p_course is null or p_map is null then raise exception 'learning:invalid_identity'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('learning-course:'||p_course::text,0));
  select * into c from public.system_courses where id=p_course;
  if found then
    select * into m from public.learning_maps where id=p_map;
    if c.slug is distinct from p_slug or c.title is distinct from p_title
      or m.course_id is distinct from p_course or m.slug is distinct from p_map_slug
      or not exists(select 1 from public.audit_logs where action='learning.course.created'
        and target_id=p_course and actor_user_id=actor) then
      raise exception 'learning:idempotency_conflict';
    end if;
    return p_map;
  end if;
  insert into public.system_courses(id,slug,title) values(p_course,p_slug,p_title);
  insert into public.learning_maps(id,course_id,slug) values(p_map,p_course,p_map_slug);
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot)
    values(actor,'learning.course.created','system_course',p_course,jsonb_build_object('map_id',p_map));
  return p_map;
exception when unique_violation then raise exception 'learning:identity_conflict';
end; $$;

create function public.learning_create_draft(p_map uuid,p_version uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid; m public.learning_maps; v public.curriculum_publications; title_snapshot text;
begin
  actor := private.learning_require_admin();
  if p_version is null then raise exception 'learning:invalid_identity'; end if;
  select * into m from public.learning_maps where id=p_map for update;
  if not found then raise exception 'learning:map_not_found'; end if;
  select title into title_snapshot from public.system_courses
    where id=m.course_id and not archived and not withdrawn;
  if not found then raise exception 'learning:course_unavailable'; end if;
  select * into v from public.curriculum_publications where id=p_version;
  if found then
    if v.map_id<>p_map or v.created_by<>actor then raise exception 'learning:idempotency_conflict'; end if;
    return v.id;
  end if;
  insert into public.curriculum_publications(id,course_id,map_id,version_number,course_title,created_by)
    select p_version,m.course_id,m.id,coalesce(max(version_number),0)+1,title_snapshot,actor
    from public.curriculum_publications where map_id=p_map;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id)
    values(actor,'learning.draft.created','curriculum_version',p_version);
  return p_version;
exception when unique_violation then raise exception 'learning:draft_conflict';
end; $$;
alter function public.learning_create_course(uuid,text,text,uuid,text) owner to postgres;
alter function public.learning_create_draft(uuid,uuid) owner to postgres;
revoke all on function public.learning_create_course(uuid,text,text,uuid,text),public.learning_create_draft(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.learning_create_course(uuid,text,text,uuid,text),public.learning_create_draft(uuid,uuid)
  to authenticated;
comment on table public.curriculum_publications is
  'Epic7 internal draft version identity. No publishing, enrollment, legacy Stage conversion or progress.';
commit;
