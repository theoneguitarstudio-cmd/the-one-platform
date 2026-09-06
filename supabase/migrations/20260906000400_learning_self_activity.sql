begin;

-- This is a deny-only integration boundary, not a Membership policy engine.
-- Epic 8 must replace it through separately reviewed policy implementation.
create function private.learning_course_use_authorized(p_actor uuid,p_course uuid,p_version uuid,p_node uuid)
returns boolean language sql stable set search_path='' as $$ select false; $$;
revoke all on function private.learning_course_use_authorized(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;

create table public.learning_self_activity (
 subject_id uuid not null references auth.users(id) on delete restrict,
 publication_id uuid not null,
 node_id uuid not null,
 revision integer not null check(revision>0),
 opened_at timestamptz,
 last_opened_at timestamptz,
 resume_resource_id uuid,
 needs_revisit boolean not null default false,
 self_completed boolean not null default false,
 self_completed_at timestamptz,
 updated_at timestamptz not null default now(),
 primary key(subject_id,publication_id,node_id),
 foreign key(publication_id,node_id) references public.learning_node_versions(publication_id,id) on delete restrict,
 foreign key(publication_id,node_id,resume_resource_id) references public.learning_node_resources(publication_id,node_id,id) on delete restrict,
 check(self_completed=(self_completed_at is not null)),
 check((opened_at is null)=(last_opened_at is null))
);
create index learning_activity_node on public.learning_self_activity(publication_id,node_id);
create index learning_activity_resource on public.learning_self_activity(publication_id,node_id,resume_resource_id);
create table public.learning_activity_requests (
 subject_id uuid not null references auth.users(id) on delete restrict,
 request_id uuid not null,
 publication_id uuid not null,
 node_id uuid not null,
 payload jsonb not null,
 result_revision integer not null,
 primary key(subject_id,request_id),
 foreign key(subject_id,publication_id,node_id) references public.learning_self_activity(subject_id,publication_id,node_id) on delete restrict
);
create index learning_activity_requests_target on public.learning_activity_requests(subject_id,publication_id,node_id);
create trigger learning_activity_requests_immutable before update or delete on public.learning_activity_requests
 for each row execute function private.learning_immutable_identity();
alter table public.learning_self_activity enable row level security;
alter table public.learning_activity_requests enable row level security;
revoke all on public.learning_self_activity,public.learning_activity_requests from public,anon,authenticated,service_role;

create function private.learning_require_use(p_version uuid,p_node uuid) returns uuid
language plpgsql set search_path='' as $$
declare actor uuid:=auth.uid(); cid uuid; available boolean;
begin
 if actor is null or not private.current_user_is_active()
 or not private.current_user_has_role(array['student']::public.app_role[])
 then raise exception using errcode='42501',message='learning:student_required'; end if;
 select course_id into cid from public.curriculum_publications where id=p_version and state='frozen';
 -- Shared Course lock serializes use with archive/withdrawal; no Commerce locks.
 select not archived and not withdrawn into available from public.system_courses where id=cid for share;
 if available is distinct from true or not exists(select 1 from public.learning_node_versions where publication_id=p_version and id=p_node)
 or private.learning_course_use_authorized(actor,cid,p_version,p_node) is distinct from true
 then raise exception using errcode='42501',message='learning:course_use_denied'; end if;
 return actor;
end; $$;
revoke all on function private.learning_require_use(uuid,uuid) from public,anon,authenticated,service_role;

create function public.learning_set_activity(p_version uuid,p_node uuid,p_expected integer,p_key uuid,p_patch jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare actor uuid; current_row public.learning_self_activity; receipt public.learning_activity_requests;
 payload jsonb; result integer; field text; resource uuid;
begin
 actor:=private.learning_require_use(p_version,p_node);
 perform private.learning_assert_keys(p_patch,array['opened','resume_resource_id','needs_revisit','self_completed']);
 if p_key is null or p_expected is null or p_expected<0 or p_patch='{}'::jsonb
 or pg_column_size(p_patch)>4096 then raise exception 'learning:invalid_request'; end if;
 foreach field in array array['opened','needs_revisit','self_completed'] loop
  if p_patch ? field and jsonb_typeof(p_patch->field)<>'boolean' then raise exception 'learning:invalid_fields'; end if;
 end loop;
 if p_patch ? 'opened' and p_patch->'opened'<>'true'::jsonb then raise exception 'learning:invalid_fields'; end if;
 if p_patch ? 'resume_resource_id' then
  if jsonb_typeof(p_patch->'resume_resource_id') not in ('string','null') then raise exception 'learning:invalid_fields'; end if;
  resource:=(p_patch->>'resume_resource_id')::uuid;
  if resource is not null and not exists(select 1 from public.learning_node_resources where publication_id=p_version and node_id=p_node and id=resource)
  then raise exception 'learning:invalid_resource'; end if;
 end if;
 payload:=jsonb_build_object('expected',p_expected,'patch',p_patch);
 -- One subject lock also serializes reuse of a request key across different Nodes.
 perform pg_advisory_xact_lock(hashtextextended('learning.activity:'||actor::text,0));
 select * into receipt from public.learning_activity_requests where subject_id=actor and request_id=p_key;
 if found then
  if receipt.publication_id<>p_version or receipt.node_id<>p_node or receipt.payload is distinct from payload
  then raise exception 'learning:idempotency_conflict'; end if;
  return receipt.result_revision;
 end if;
 select * into current_row from public.learning_self_activity where subject_id=actor and publication_id=p_version and node_id=p_node for update;
 if coalesce(current_row.revision,0)<>p_expected then raise exception 'learning:revision_conflict'; end if;
 result:=coalesce(current_row.revision,0)+1;
 insert into public.learning_self_activity(subject_id,publication_id,node_id,revision,opened_at,last_opened_at,resume_resource_id,needs_revisit,self_completed,self_completed_at)
 values(actor,p_version,p_node,result,
 case when p_patch->>'opened'='true' then coalesce(current_row.opened_at,now()) else current_row.opened_at end,
 case when p_patch->>'opened'='true' then now() else current_row.last_opened_at end,
 case when p_patch ? 'resume_resource_id' then resource else current_row.resume_resource_id end,
 coalesce((p_patch->>'needs_revisit')::boolean,current_row.needs_revisit,false),
 coalesce((p_patch->>'self_completed')::boolean,current_row.self_completed,false),
 case when p_patch->>'self_completed'='true' then coalesce(current_row.self_completed_at,now())
 when p_patch->>'self_completed'='false' then null else current_row.self_completed_at end)
 on conflict(subject_id,publication_id,node_id) do update set revision=excluded.revision,opened_at=excluded.opened_at,
 last_opened_at=excluded.last_opened_at,resume_resource_id=excluded.resume_resource_id,needs_revisit=excluded.needs_revisit,
 self_completed=excluded.self_completed,self_completed_at=excluded.self_completed_at,updated_at=now();
 insert into public.learning_activity_requests values(actor,p_key,p_version,p_node,payload,result);
 return result;
end; $$;
alter function public.learning_set_activity(uuid,uuid,integer,uuid,jsonb) owner to postgres;
revoke all on function public.learning_set_activity(uuid,uuid,integer,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.learning_set_activity(uuid,uuid,integer,uuid,jsonb) to authenticated;

create function public.learning_get_own_activity(p_version uuid,p_node uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
 actor:=private.learning_require_use(p_version,p_node);
 select jsonb_build_object('revision',revision,'opened_at',opened_at,'last_opened_at',last_opened_at,
 'resume_resource_id',resume_resource_id,'needs_revisit',needs_revisit,'self_completed',self_completed,'self_completed_at',self_completed_at)
 into result from public.learning_self_activity where subject_id=actor and publication_id=p_version and node_id=p_node;
 return result; -- Null means no activity, never an auto-enrolled 0% map.
end; $$;
alter function public.learning_get_own_activity(uuid,uuid) owner to postgres;
revoke all on function public.learning_get_own_activity(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.learning_get_own_activity(uuid,uuid) to authenticated;

create function public.learning_inspect_version(p_version uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.learning_require_admin();
 select jsonb_build_object('id',v.id,'course_id',v.course_id,'map_id',v.map_id,'version_number',v.version_number,
 'state',v.state,'revision',v.revision,'title',v.course_title,
 'levels',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'title',l.title,'position',l.position) order by l.position) from public.curriculum_stage_versions l where l.publication_id=v.id),'[]'::jsonb),
 'modules',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'level_id',m.stage_id,'title',m.title,'position',m.position) order by m.stage_id,m.position) from public.learning_module_versions m where m.publication_id=v.id),'[]'::jsonb),
 'nodes',coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'module_id',n.module_id,'title',n.title,'guidance',n.guidance,'position',n.position,
  'resources',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'revision_id',r.resource_revision_id,'kind',rv.kind,'title',rv.title,'purpose',r.purpose,'position',r.position) order by r.position) from public.learning_node_resources r join public.learning_resource_versions rv on rv.id=r.resource_revision_id where r.publication_id=n.publication_id and r.node_id=n.id),'[]'::jsonb),
  'objectives',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'objective',o.objective)) from public.learning_objective_versions o where o.publication_id=n.publication_id and o.node_id=n.id),'[]'::jsonb),
  'capabilities',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'code',c.code,'description',a.description)) from public.learning_node_capability_attachments a join public.learning_capabilities c on c.id=a.id where a.publication_id=n.publication_id and a.node_id=n.id),'[]'::jsonb)
 ) order by n.module_id,n.position) from public.learning_node_versions n where n.publication_id=v.id),'[]'::jsonb),
 'credits',coalesce((select jsonb_agg(jsonb_build_object('display_credit',c.display_credit,'contribution',c.contribution,'resource_revision_id',c.resource_revision_id)) from public.learning_author_credits c where c.publication_id=v.id),'[]'::jsonb))
 into result from public.curriculum_publications v where v.id=p_version;
 return result; -- No provider locator, linked Auth identity, learner data or delivery token.
end; $$;
alter function public.learning_inspect_version(uuid) owner to postgres;
revoke all on function public.learning_inspect_version(uuid) from public,anon,authenticated,service_role;
grant execute on function public.learning_inspect_version(uuid) to authenticated;

create function private.learning_guard_course() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' or (to_jsonb(old)-'archived'-'withdrawn') is distinct from (to_jsonb(new)-'archived'-'withdrawn')
 then raise exception 'learning:immutable_identity'; end if;
 return new;
end; $$;
revoke all on function private.learning_guard_course() from public,anon,authenticated,service_role;
create trigger learning_course_retention before update or delete on public.system_courses
 for each row execute function private.learning_guard_course();

commit;
