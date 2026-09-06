begin;
create table public.learning_mutation_receipts (
  publication_id uuid not null references public.curriculum_publications(id) on delete restrict,
  actor_id uuid not null references auth.users(id) on delete restrict,
  request_id uuid not null,
  operation text not null,
  payload jsonb not null,
  result_revision integer not null,
  primary key(publication_id,actor_id,request_id)
);
create index learning_receipt_actor on public.learning_mutation_receipts(actor_id);
alter table public.learning_mutation_receipts enable row level security;
revoke all on public.learning_mutation_receipts from public,anon,authenticated,service_role;

create function private.learning_immutable_identity() returns trigger
language plpgsql set search_path='' as $$
begin raise exception 'learning:immutable_identity'; end; $$;
revoke all on function private.learning_immutable_identity() from public,anon,authenticated,service_role;

create function private.learning_guard_draft() returns trigger
language plpgsql set search_path='' as $$
declare v_id uuid; v_state text;
begin
  if tg_op='UPDATE' and
    (to_jsonb(new)->>'publication_id' is distinct from to_jsonb(old)->>'publication_id'
     or to_jsonb(new)->>'id' is distinct from to_jsonb(old)->>'id') then
    raise exception 'learning:immutable_identity';
  end if;
  v_id := case when tg_op='DELETE' then old.publication_id else new.publication_id end;
  select state into v_state from public.curriculum_publications where id=v_id for update;
  if v_state is distinct from 'draft' then raise exception 'learning:immutable_version'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end; $$;
revoke all on function private.learning_guard_draft() from public,anon,authenticated,service_role;

create table public.curriculum_stages (
 id uuid primary key,
 course_id uuid not null references public.system_courses(id) on delete restrict,
 slug text not null check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug)<=100),
 unique(course_id,id), unique(course_id,slug)
);
create table public.curriculum_stage_versions (
 publication_id uuid not null,
 course_id uuid not null,
 id uuid not null,
 
 position integer not null check(position>0),
 title text not null check(length(trim(title)) between 1 and 200),
 guidance text not null default '' check(length(guidance)<=10000),
 primary key(publication_id,id), unique(publication_id,course_id,id),
 foreign key(course_id,publication_id) references public.curriculum_publications(course_id,id) on delete restrict,
 foreign key(course_id,id) references public.curriculum_stages(course_id,id) on delete restrict,
 
 unique(publication_id,position) deferrable initially immediate
);
create index curriculum_stage_versions_identity on public.curriculum_stage_versions(course_id,id);
create trigger curriculum_stages_immutable before update or delete on public.curriculum_stages
 for each row execute function private.learning_immutable_identity();
create trigger curriculum_stage_versions_draft before insert or update or delete on public.curriculum_stage_versions
 for each row execute function private.learning_guard_draft();
alter table public.curriculum_stages enable row level security;
alter table public.curriculum_stage_versions enable row level security;
revoke all on public.curriculum_stages,public.curriculum_stage_versions from public,anon,authenticated,service_role;

create table public.learning_modules (
 id uuid primary key,
 course_id uuid not null references public.system_courses(id) on delete restrict,
 slug text not null check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug)<=100),
 unique(course_id,id), unique(course_id,slug)
);
create table public.learning_module_versions (
 publication_id uuid not null,
 course_id uuid not null,
 id uuid not null,
 stage_id uuid not null,
 position integer not null check(position>0),
 title text not null check(length(trim(title)) between 1 and 200),
 guidance text not null default '' check(length(guidance)<=10000),
 primary key(publication_id,id), unique(publication_id,course_id,id),
 foreign key(course_id,publication_id) references public.curriculum_publications(course_id,id) on delete restrict,
 foreign key(course_id,id) references public.learning_modules(course_id,id) on delete restrict,
 foreign key(publication_id,course_id,stage_id) references public.curriculum_stage_versions(publication_id,course_id,id) on delete restrict,
 unique(publication_id,stage_id,position) deferrable initially immediate
);
create index learning_module_versions_identity on public.learning_module_versions(course_id,id);
create trigger learning_modules_immutable before update or delete on public.learning_modules
 for each row execute function private.learning_immutable_identity();
create trigger learning_module_versions_draft before insert or update or delete on public.learning_module_versions
 for each row execute function private.learning_guard_draft();
alter table public.learning_modules enable row level security;
alter table public.learning_module_versions enable row level security;
revoke all on public.learning_modules,public.learning_module_versions from public,anon,authenticated,service_role;

create table public.learning_nodes (
 id uuid primary key,
 course_id uuid not null references public.system_courses(id) on delete restrict,
 slug text not null check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug)<=100),
 unique(course_id,id), unique(course_id,slug)
);
create table public.learning_node_versions (
 publication_id uuid not null,
 course_id uuid not null,
 id uuid not null,
 module_id uuid not null,
 position integer not null check(position>0),
 title text not null check(length(trim(title)) between 1 and 200),
 guidance text not null default '' check(length(guidance)<=10000),
 primary key(publication_id,id), unique(publication_id,course_id,id),
 foreign key(course_id,publication_id) references public.curriculum_publications(course_id,id) on delete restrict,
 foreign key(course_id,id) references public.learning_nodes(course_id,id) on delete restrict,
 foreign key(publication_id,course_id,module_id) references public.learning_module_versions(publication_id,course_id,id) on delete restrict,
 unique(publication_id,module_id,position) deferrable initially immediate
);
create index learning_node_versions_identity on public.learning_node_versions(course_id,id);
create trigger learning_nodes_immutable before update or delete on public.learning_nodes
 for each row execute function private.learning_immutable_identity();
create trigger learning_node_versions_draft before insert or update or delete on public.learning_node_versions
 for each row execute function private.learning_guard_draft();
alter table public.learning_nodes enable row level security;
alter table public.learning_node_versions enable row level security;
revoke all on public.learning_nodes,public.learning_node_versions from public,anon,authenticated,service_role;

create function private.learning_request(p_version uuid,p_expected integer,p_key uuid,p_op text,p_payload jsonb)
returns integer language plpgsql set search_path='' as $$
declare actor uuid; v public.curriculum_publications; receipt public.learning_mutation_receipts;
begin
 actor:=private.learning_require_admin();
 if p_key is null or p_expected is null or p_expected<0 then raise exception 'learning:invalid_request'; end if;
 select * into v from public.curriculum_publications where id=p_version for update;
 if not found then raise exception 'learning:version_not_found'; end if;
 if not exists(select 1 from public.system_courses where id=v.course_id and not archived and not withdrawn)
 then raise exception 'learning:course_unavailable'; end if;
 select * into receipt from public.learning_mutation_receipts
   where publication_id=p_version and actor_id=actor and request_id=p_key;
 if found then
   if receipt.operation<>p_op or receipt.payload is distinct from p_payload
   then raise exception 'learning:idempotency_conflict'; end if;
   return receipt.result_revision;
 end if;
 if v.state<>'draft' then raise exception 'learning:immutable_version'; end if;
 if v.revision<>p_expected then raise exception 'learning:revision_conflict'; end if;
 return null;
end; $$;
revoke all on function private.learning_request(uuid,integer,uuid,text,jsonb) from public,anon,authenticated,service_role;

create function private.learning_finish_request(p_version uuid,p_key uuid,p_op text,p_payload jsonb)
returns integer language plpgsql set search_path='' as $$
declare n integer; actor uuid := auth.uid();
begin
 update public.curriculum_publications set revision=revision+1 where id=p_version returning revision into n;
 insert into public.learning_mutation_receipts values(p_version,actor,p_key,p_op,p_payload,n);
 insert into public.audit_logs(actor_user_id,action,target_type,target_id,after_snapshot)
 values(actor,'learning.'||p_op,'curriculum_version',p_version,jsonb_build_object('request_id',p_key,'revision',n));
 return n;
end; $$;
revoke all on function private.learning_finish_request(uuid,uuid,text,jsonb) from public,anon,authenticated,service_role;
create trigger learning_receipts_immutable before update or delete on public.learning_mutation_receipts
 for each row execute function private.learning_immutable_identity();

create function private.learning_assert_keys(p_value jsonb,p_allowed text[]) returns void
language plpgsql set search_path='' as $$
begin
 if jsonb_typeof(p_value) is distinct from 'object' or exists(
  select 1 from jsonb_object_keys(p_value) k where not(k=any(p_allowed)))
 then raise exception 'learning:invalid_fields'; end if;
end; $$;
revoke all on function private.learning_assert_keys(jsonb,text[]) from public,anon,authenticated,service_role;

create function public.learning_put_structure(p_version uuid,p_expected integer,p_key uuid,p_structure jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare result integer; cid uuid; item jsonb; payload jsonb;
begin
 payload:=jsonb_build_object('expected',p_expected,'structure',p_structure);
 result:=private.learning_request(p_version,p_expected,p_key,'structure',payload);
 if result is not null then return result; end if;
 perform private.learning_assert_keys(p_structure,array['levels','modules','nodes']);
 if jsonb_typeof(p_structure->'levels') is distinct from 'array'
 or jsonb_typeof(p_structure->'modules') is distinct from 'array'
 or jsonb_typeof(p_structure->'nodes') is distinct from 'array'
 or pg_column_size(p_structure)>2097152 then raise exception 'learning:invalid_structure'; end if;
 select course_id into cid from public.curriculum_publications where id=p_version;
 -- Upsert placement only; identities can never change course or stable slug.
 set constraints all deferred;

 for item in select value from jsonb_array_elements(p_structure->'levels') loop
  perform private.learning_assert_keys(item,array['id','slug','position','title','guidance']);
  insert into public.curriculum_stages(id,course_id,slug)
   values((item->>'id')::uuid,cid,item->>'slug') on conflict(id) do nothing;
  if not exists(select 1 from public.curriculum_stages where id=(item->>'id')::uuid and course_id=cid and slug=item->>'slug')
  then raise exception 'learning:identity_conflict'; end if;
  insert into public.curriculum_stage_versions(publication_id,course_id,id,position,title,guidance)
   values(p_version,cid,(item->>'id')::uuid,(item->>'position')::integer,item->>'title',coalesce(item->>'guidance',''))
  on conflict(publication_id,id) do update set position=excluded.position,title=excluded.title,guidance=excluded.guidance;
 end loop;

 for item in select value from jsonb_array_elements(p_structure->'modules') loop
  perform private.learning_assert_keys(item,array['id','slug','position','title','guidance','stage_id']);
  insert into public.learning_modules(id,course_id,slug)
   values((item->>'id')::uuid,cid,item->>'slug') on conflict(id) do nothing;
  if not exists(select 1 from public.learning_modules where id=(item->>'id')::uuid and course_id=cid and slug=item->>'slug')
  then raise exception 'learning:identity_conflict'; end if;
  insert into public.learning_module_versions(publication_id,course_id,id,position,title,guidance,stage_id)
   values(p_version,cid,(item->>'id')::uuid,(item->>'position')::integer,item->>'title',coalesce(item->>'guidance',''),(item->>'stage_id')::uuid)
  on conflict(publication_id,id) do update set position=excluded.position,title=excluded.title,guidance=excluded.guidance,stage_id=excluded.stage_id;
 end loop;

 for item in select value from jsonb_array_elements(p_structure->'nodes') loop
  perform private.learning_assert_keys(item,array['id','slug','position','title','guidance','module_id']);
  insert into public.learning_nodes(id,course_id,slug)
   values((item->>'id')::uuid,cid,item->>'slug') on conflict(id) do nothing;
  if not exists(select 1 from public.learning_nodes where id=(item->>'id')::uuid and course_id=cid and slug=item->>'slug')
  then raise exception 'learning:identity_conflict'; end if;
  insert into public.learning_node_versions(publication_id,course_id,id,position,title,guidance,module_id)
   values(p_version,cid,(item->>'id')::uuid,(item->>'position')::integer,item->>'title',coalesce(item->>'guidance',''),(item->>'module_id')::uuid)
  on conflict(publication_id,id) do update set position=excluded.position,title=excluded.title,guidance=excluded.guidance,module_id=excluded.module_id;
 end loop;

 set constraints all immediate;
 return private.learning_finish_request(p_version,p_key,'structure',payload);
exception when unique_violation or foreign_key_violation or check_violation or not_null_violation or invalid_text_representation
 then raise exception 'learning:invalid_structure';
end; $$;
alter function public.learning_put_structure(uuid,integer,uuid,jsonb) owner to postgres;
revoke all on function public.learning_put_structure(uuid,integer,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.learning_put_structure(uuid,integer,uuid,jsonb) to authenticated;
commit;
