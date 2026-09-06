begin;
-- C completes the content required for atomic internal freeze. No publishing workflow.
alter table public.curriculum_publications drop constraint curriculum_publications_state_check;
alter table public.curriculum_publications add constraint curriculum_publications_state_check check(state in ('draft','frozen'));
alter table public.curriculum_publications add column frozen_at timestamptz;
alter table public.curriculum_publications add column frozen_by uuid references auth.users(id) on delete restrict;
alter table public.curriculum_publications add constraint learning_frozen_stamp
 check((state='frozen')=(frozen_at is not null and frozen_by is not null));
create index curriculum_frozen_by on public.curriculum_publications(frozen_by);

create function private.learning_guard_version() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'learning:history_retained'; end if;
 if old.state='frozen' then raise exception 'learning:immutable_version'; end if;
 if (new.id,new.course_id,new.map_id,new.version_number,new.created_by,new.created_at)
  is distinct from (old.id,old.course_id,old.map_id,old.version_number,old.created_by,old.created_at)
 then raise exception 'learning:immutable_identity'; end if;
 return new;
end; $$;
revoke all on function private.learning_guard_version() from public,anon,authenticated,service_role;
create trigger curriculum_guard_version before update or delete on public.curriculum_publications
 for each row execute function private.learning_guard_version();
create trigger learning_map_identity before update or delete on public.learning_maps
 for each row execute function private.learning_immutable_identity();

create table public.learning_resources(
 id uuid primary key,course_id uuid not null references public.system_courses(id) on delete restrict,
 slug text not null check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug)<=100),
 unique(course_id,id),unique(course_id,slug));
create table public.learning_resource_versions(
 id uuid primary key,course_id uuid not null,resource_id uuid not null,
 kind text not null check(kind in ('text','video','pdf','audio','backing_track','image','external_link')),
 title text not null check(length(trim(title)) between 1 and 200),
 content text not null default '' check(length(content)<=50000),
 provider_ref text check(length(provider_ref)<=2048),
 foreign key(course_id,resource_id) references public.learning_resources(course_id,id) on delete restrict,
 unique(course_id,id));
create index learning_resource_versions_resource on public.learning_resource_versions(course_id,resource_id);
create table public.learning_node_resources(
 publication_id uuid not null,course_id uuid not null,id uuid not null,node_id uuid not null,
 resource_revision_id uuid not null,position integer not null check(position>0),
 purpose text not null check(length(trim(purpose)) between 1 and 80),
 primary key(publication_id,id),unique(publication_id,node_id,id),
 foreign key(publication_id,course_id,node_id) references public.learning_node_versions(publication_id,course_id,id) on delete restrict,
 foreign key(course_id,resource_revision_id) references public.learning_resource_versions(course_id,id) on delete restrict,
 unique(publication_id,node_id,resource_revision_id),unique(publication_id,node_id,position) deferrable initially immediate);
create index learning_node_resources_revision on public.learning_node_resources(course_id,resource_revision_id);
create table public.learning_objectives(
 id uuid primary key,course_id uuid not null,node_id uuid not null,
 foreign key(course_id,node_id) references public.learning_nodes(course_id,id) on delete restrict,
 unique(course_id,node_id,id));
create index learning_objectives_node on public.learning_objectives(course_id,node_id);
create table public.learning_objective_versions(
 publication_id uuid not null,course_id uuid not null,id uuid not null,node_id uuid not null,
 objective text not null check(length(trim(objective)) between 1 and 2000),
 primary key(publication_id,id),
 foreign key(course_id,node_id,id) references public.learning_objectives(course_id,node_id,id) on delete restrict,
 foreign key(publication_id,course_id,node_id) references public.learning_node_versions(publication_id,course_id,id) on delete restrict);
create index learning_objective_versions_node on public.learning_objective_versions(publication_id,course_id,node_id);
create index learning_objective_versions_identity on public.learning_objective_versions(course_id,node_id,id);
create table public.learning_skills(
 id uuid primary key,code text not null unique check(code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
 definition text not null check(length(trim(definition)) between 1 and 2000));
create table public.learning_objective_skills(
 publication_id uuid not null,objective_id uuid not null,skill_id uuid not null references public.learning_skills(id) on delete restrict,
 primary key(publication_id,objective_id,skill_id),
 foreign key(publication_id,objective_id) references public.learning_objective_versions(publication_id,id) on delete restrict);
create index learning_objective_skills_skill on public.learning_objective_skills(skill_id);
create table public.learning_node_prerequisites(
 publication_id uuid not null,dependent_node_id uuid not null,prerequisite_node_id uuid not null,
 rationale text not null default '' check(length(rationale)<=2000),
 primary key(publication_id,dependent_node_id,prerequisite_node_id),
 check(dependent_node_id<>prerequisite_node_id),
 foreign key(publication_id,dependent_node_id) references public.learning_node_versions(publication_id,id) on delete restrict,
 foreign key(publication_id,prerequisite_node_id) references public.learning_node_versions(publication_id,id) on delete restrict);
create index learning_prerequisites_reverse on public.learning_node_prerequisites(publication_id,prerequisite_node_id);
create table public.content_contributors(
 id uuid primary key,display_credit text not null check(length(trim(display_credit)) between 1 and 200),
 auth_user_id uuid references auth.users(id) on delete restrict);
create index content_contributors_account on public.content_contributors(auth_user_id);
create table public.learning_author_credits(
 publication_id uuid not null,course_id uuid not null,id uuid not null,
 contributor_id uuid not null references public.content_contributors(id) on delete restrict,
 resource_revision_id uuid,display_credit text not null check(length(trim(display_credit)) between 1 and 200),
 contribution text not null check(length(trim(contribution)) between 1 and 80),
 position integer not null check(position>0),
 primary key(publication_id,id),
 foreign key(course_id,publication_id) references public.curriculum_publications(course_id,id) on delete restrict,
 foreign key(course_id,resource_revision_id) references public.learning_resource_versions(course_id,id) on delete restrict,
 unique nulls not distinct(publication_id,resource_revision_id,contributor_id),
 unique nulls not distinct(publication_id,resource_revision_id,position));
create index learning_author_credits_contributor on public.learning_author_credits(contributor_id);
create index learning_author_credits_resource on public.learning_author_credits(course_id,resource_revision_id);
create table public.learning_capabilities(
 id uuid primary key,course_id uuid not null,node_id uuid not null,
 code text not null check(code in ('submission','async_review','verification','assessment')),
 foreign key(course_id,node_id) references public.learning_nodes(course_id,id) on delete restrict,
 unique(course_id,node_id,id),unique(node_id,code));
create table public.learning_node_capability_attachments(
 publication_id uuid not null,course_id uuid not null,id uuid not null,node_id uuid not null,
 description text not null default '' check(length(description)<=2000),
 primary key(publication_id,id),
 foreign key(course_id,node_id,id) references public.learning_capabilities(course_id,node_id,id) on delete restrict,
 foreign key(publication_id,course_id,node_id) references public.learning_node_versions(publication_id,course_id,id) on delete restrict);
create index learning_capability_attachments_node on public.learning_node_capability_attachments(publication_id,course_id,node_id);
create index learning_capability_attachments_identity on public.learning_node_capability_attachments(course_id,node_id,id);

alter table public.learning_resources enable row level security;
revoke all on public.learning_resources from public,anon,authenticated,service_role;
create trigger learning_resources_guard before update or delete on public.learning_resources
 for each row execute function private.learning_immutable_identity();

alter table public.learning_resource_versions enable row level security;
revoke all on public.learning_resource_versions from public,anon,authenticated,service_role;
create trigger learning_resource_versions_guard before update or delete on public.learning_resource_versions
 for each row execute function private.learning_immutable_identity();

alter table public.learning_objectives enable row level security;
revoke all on public.learning_objectives from public,anon,authenticated,service_role;
create trigger learning_objectives_guard before update or delete on public.learning_objectives
 for each row execute function private.learning_immutable_identity();

alter table public.learning_skills enable row level security;
revoke all on public.learning_skills from public,anon,authenticated,service_role;
create trigger learning_skills_guard before update or delete on public.learning_skills
 for each row execute function private.learning_immutable_identity();

alter table public.content_contributors enable row level security;
revoke all on public.content_contributors from public,anon,authenticated,service_role;
create trigger content_contributors_guard before update or delete on public.content_contributors
 for each row execute function private.learning_immutable_identity();

alter table public.learning_capabilities enable row level security;
revoke all on public.learning_capabilities from public,anon,authenticated,service_role;
create trigger learning_capabilities_guard before update or delete on public.learning_capabilities
 for each row execute function private.learning_immutable_identity();

alter table public.learning_node_resources enable row level security;
revoke all on public.learning_node_resources from public,anon,authenticated,service_role;
create trigger learning_node_resources_guard before insert or update or delete on public.learning_node_resources
 for each row execute function private.learning_guard_draft();

alter table public.learning_objective_versions enable row level security;
revoke all on public.learning_objective_versions from public,anon,authenticated,service_role;
create trigger learning_objective_versions_guard before insert or update or delete on public.learning_objective_versions
 for each row execute function private.learning_guard_draft();

alter table public.learning_objective_skills enable row level security;
revoke all on public.learning_objective_skills from public,anon,authenticated,service_role;
create trigger learning_objective_skills_guard before insert or update or delete on public.learning_objective_skills
 for each row execute function private.learning_guard_draft();

alter table public.learning_node_prerequisites enable row level security;
revoke all on public.learning_node_prerequisites from public,anon,authenticated,service_role;
create trigger learning_node_prerequisites_guard before insert or update or delete on public.learning_node_prerequisites
 for each row execute function private.learning_guard_draft();

alter table public.learning_author_credits enable row level security;
revoke all on public.learning_author_credits from public,anon,authenticated,service_role;
create trigger learning_author_credits_guard before insert or update or delete on public.learning_author_credits
 for each row execute function private.learning_guard_draft();

alter table public.learning_node_capability_attachments enable row level security;
revoke all on public.learning_node_capability_attachments from public,anon,authenticated,service_role;
create trigger learning_node_capability_attachments_guard before insert or update or delete on public.learning_node_capability_attachments
 for each row execute function private.learning_guard_draft();

create function private.learning_check_dag() returns trigger language plpgsql set search_path='' as $$
begin
 if exists(with recursive walk(id) as (
  select prerequisite_node_id from public.learning_node_prerequisites
   where publication_id=new.publication_id and dependent_node_id=new.prerequisite_node_id
  union
  select e.prerequisite_node_id from public.learning_node_prerequisites e join walk w on e.dependent_node_id=w.id
   where e.publication_id=new.publication_id
 ) select 1 from walk where id=new.dependent_node_id)
 then raise exception 'learning:prerequisite_cycle'; end if;
 return new;
end; $$;
revoke all on function private.learning_check_dag() from public,anon,authenticated,service_role;
create trigger learning_prerequisites_dag after insert or update on public.learning_node_prerequisites
 for each row execute function private.learning_check_dag();

create function public.learning_put_content(p_version uuid,p_expected integer,p_key uuid,p_content jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare result integer; cid uuid; i jsonb; payload jsonb; k text;
begin
 payload:=jsonb_build_object('expected',p_expected,'content',p_content);
 result:=private.learning_request(p_version,p_expected,p_key,'content',payload);
 if result is not null then return result; end if;
 perform private.learning_assert_keys(p_content,array['resources','links','objectives','skills','mappings','prerequisites','contributors','credits','capabilities']);
 if pg_column_size(p_content)>2097152 then raise exception 'learning:invalid_content'; end if;
 for k in select jsonb_object_keys(p_content) loop
  if jsonb_typeof(p_content->k)<>'array' then raise exception 'learning:invalid_content'; end if;
 end loop;
 select course_id into cid from public.curriculum_publications where id=p_version;
 set constraints all deferred;
 for i in select value from jsonb_array_elements(p_content->'resources') loop
  perform private.learning_assert_keys(i,array['id','slug','revision_id','kind','title','content','provider_ref']);
  insert into public.learning_resources(id,course_id,slug) values((i->>'id')::uuid,cid,i->>'slug') on conflict(id) do nothing;
  if not exists(select 1 from public.learning_resources where id=(i->>'id')::uuid and course_id=cid and slug=i->>'slug')
   then raise exception 'learning:identity_conflict'; end if;
  insert into public.learning_resource_versions(id,course_id,resource_id,kind,title,content,provider_ref)
   values((i->>'revision_id')::uuid,cid,(i->>'id')::uuid,i->>'kind',i->>'title',coalesce(i->>'content',''),i->>'provider_ref')
   on conflict(id) do nothing;
  if not exists(select 1 from public.learning_resource_versions r where r.id=(i->>'revision_id')::uuid
   and r.course_id=cid and r.resource_id=(i->>'id')::uuid and r.kind=i->>'kind' and r.title=i->>'title'
   and r.content=coalesce(i->>'content','') and r.provider_ref is not distinct from i->>'provider_ref')
   then raise exception 'learning:immutable_resource'; end if;
 end loop;
 for i in select value from jsonb_array_elements(p_content->'links') loop
  perform private.learning_assert_keys(i,array['id','node_id','resource_revision_id','position','purpose']);
  if exists(select 1 from public.learning_node_resources where publication_id=p_version and id=(i->>'id')::uuid and node_id<>(i->>'node_id')::uuid)
   then raise exception 'learning:identity_conflict'; end if;
  insert into public.learning_node_resources values(p_version,cid,(i->>'id')::uuid,(i->>'node_id')::uuid,(i->>'resource_revision_id')::uuid,(i->>'position')::integer,i->>'purpose')
  on conflict(publication_id,id) do update set resource_revision_id=excluded.resource_revision_id,position=excluded.position,purpose=excluded.purpose;
 end loop;
 for i in select value from jsonb_array_elements(p_content->'objectives') loop
  perform private.learning_assert_keys(i,array['id','node_id','objective']);
  insert into public.learning_objectives values((i->>'id')::uuid,cid,(i->>'node_id')::uuid) on conflict(id) do nothing;
  if not exists(select 1 from public.learning_objectives where id=(i->>'id')::uuid and course_id=cid and node_id=(i->>'node_id')::uuid)
   then raise exception 'learning:identity_conflict'; end if;
  insert into public.learning_objective_versions values(p_version,cid,(i->>'id')::uuid,(i->>'node_id')::uuid,i->>'objective')
  on conflict(publication_id,id) do update set objective=excluded.objective;
 end loop;
 for i in select value from jsonb_array_elements(p_content->'skills') loop
  perform private.learning_assert_keys(i,array['id','code','definition']);
  insert into public.learning_skills values((i->>'id')::uuid,i->>'code',i->>'definition') on conflict(id) do nothing;
  if not exists(select 1 from public.learning_skills where id=(i->>'id')::uuid and code=i->>'code' and definition=i->>'definition')
   then raise exception 'learning:immutable_skill'; end if;
 end loop;
 for i in select value from jsonb_array_elements(p_content->'mappings') loop
  perform private.learning_assert_keys(i,array['objective_id','skill_id']);
  insert into public.learning_objective_skills values(p_version,(i->>'objective_id')::uuid,(i->>'skill_id')::uuid) on conflict do nothing;
 end loop;
 for i in select value from jsonb_array_elements(p_content->'prerequisites') loop
  perform private.learning_assert_keys(i,array['dependent_node_id','prerequisite_node_id','rationale']);
  insert into public.learning_node_prerequisites values(p_version,(i->>'dependent_node_id')::uuid,(i->>'prerequisite_node_id')::uuid,coalesce(i->>'rationale',''))
  on conflict(publication_id,dependent_node_id,prerequisite_node_id) do update set rationale=excluded.rationale;
 end loop;
 for i in select value from jsonb_array_elements(p_content->'contributors') loop
  perform private.learning_assert_keys(i,array['id','display_credit','auth_user_id']);
  insert into public.content_contributors values((i->>'id')::uuid,i->>'display_credit',(i->>'auth_user_id')::uuid) on conflict(id) do nothing;
  if not exists(select 1 from public.content_contributors where id=(i->>'id')::uuid and display_credit=i->>'display_credit'
   and auth_user_id is not distinct from (i->>'auth_user_id')::uuid) then raise exception 'learning:identity_conflict'; end if;
 end loop;
 for i in select value from jsonb_array_elements(p_content->'credits') loop
  perform private.learning_assert_keys(i,array['id','contributor_id','resource_revision_id','contribution','position']);
  insert into public.learning_author_credits
   select p_version,cid,(i->>'id')::uuid,c.id,(i->>'resource_revision_id')::uuid,c.display_credit,i->>'contribution',(i->>'position')::integer
   from public.content_contributors c where c.id=(i->>'contributor_id')::uuid
  on conflict(publication_id,id) do update set contributor_id=excluded.contributor_id,resource_revision_id=excluded.resource_revision_id,
   display_credit=excluded.display_credit,contribution=excluded.contribution,position=excluded.position;
  if not found then raise exception 'learning:contributor_not_found'; end if;
 end loop;
 for i in select value from jsonb_array_elements(p_content->'capabilities') loop
  perform private.learning_assert_keys(i,array['id','node_id','code','description']);
  insert into public.learning_capabilities values((i->>'id')::uuid,cid,(i->>'node_id')::uuid,i->>'code') on conflict(id) do nothing;
  if not exists(select 1 from public.learning_capabilities where id=(i->>'id')::uuid and course_id=cid and node_id=(i->>'node_id')::uuid and code=i->>'code')
   then raise exception 'learning:identity_conflict'; end if;
  insert into public.learning_node_capability_attachments values(p_version,cid,(i->>'id')::uuid,(i->>'node_id')::uuid,coalesce(i->>'description',''))
  on conflict(publication_id,id) do update set description=excluded.description;
 end loop;
 set constraints all immediate;
 return private.learning_finish_request(p_version,p_key,'content',payload);
exception when unique_violation or foreign_key_violation or check_violation or not_null_violation or invalid_text_representation
 then raise exception 'learning:invalid_content';
end; $$;

create function public.learning_freeze_version(p_version uuid,p_expected integer,p_key uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare result integer; payload jsonb;
begin
 payload:=jsonb_build_object('expected',p_expected);
 result:=private.learning_request(p_version,p_expected,p_key,'freeze',payload);
 if result is not null then return result; end if;
 if not exists(select 1 from public.curriculum_stage_versions where publication_id=p_version)
 or exists(select 1 from public.curriculum_stage_versions s where s.publication_id=p_version
  and not exists(select 1 from public.learning_module_versions m where m.publication_id=p_version and m.stage_id=s.id))
 or exists(select 1 from public.learning_module_versions m where m.publication_id=p_version
  and not exists(select 1 from public.learning_node_versions n where n.publication_id=p_version and n.module_id=m.id))
 or exists(select 1 from public.learning_node_versions n where n.publication_id=p_version and (
  not exists(select 1 from public.learning_objective_versions o where o.publication_id=p_version and o.node_id=n.id)
  or not exists(select 1 from public.learning_node_resources r where r.publication_id=p_version and r.node_id=n.id)))
 then raise exception 'learning:incomplete_curriculum'; end if;
 result:=private.learning_finish_request(p_version,p_key,'freeze',payload);
 update public.curriculum_publications set state='frozen',frozen_by=auth.uid(),frozen_at=clock_timestamp() where id=p_version;
 return result;
end; $$;
alter function public.learning_put_content(uuid,integer,uuid,jsonb) owner to postgres;
revoke all on function public.learning_put_content(uuid,integer,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.learning_put_content(uuid,integer,uuid,jsonb) to authenticated;
alter function public.learning_freeze_version(uuid,integer,uuid) owner to postgres;
revoke all on function public.learning_freeze_version(uuid,integer,uuid) from public,anon,authenticated,service_role;
grant execute on function public.learning_freeze_version(uuid,integer,uuid) to authenticated;
commit;
