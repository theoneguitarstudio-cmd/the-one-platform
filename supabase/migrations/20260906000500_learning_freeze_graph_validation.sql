begin;

-- Forward-only reinforcement: validate the full snapshot at freeze as well as
-- each graph write. This adds no new access or publication authority.
create function private.learning_validate_freeze_graph() returns trigger
language plpgsql set search_path='' as $$
begin
 if exists(
  with recursive edges as (
   select dependent_node_id,prerequisite_node_id from public.learning_node_prerequisites where publication_id=new.id
  ), reach(origin,target) as (
   select dependent_node_id,prerequisite_node_id from edges
   union
   select r.origin,e.prerequisite_node_id from reach r join edges e on e.dependent_node_id=r.target
  ) select 1 from reach where origin=target
 ) then raise exception 'learning:prerequisite_cycle'; end if;
 return new;
end; $$;
revoke all on function private.learning_validate_freeze_graph() from public,anon,authenticated,service_role;
create trigger learning_freeze_graph before update on public.curriculum_publications
 for each row when (old.state='draft' and new.state='frozen')
 execute function private.learning_validate_freeze_graph();

commit;
