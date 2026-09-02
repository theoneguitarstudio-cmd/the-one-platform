begin;

-- Lesson/record writes belong to the existing postgres-owned SECURITY DEFINER
-- domain RPCs. Keep service_role SELECT, participant reads, and RPC EXECUTE.
-- This also removes INSERT/UPDATE/DELETE acquired through the Epic 3 GRANT ALL.
revoke insert, update, delete on table public.lessons from service_role;
revoke insert, update, delete on table public.lesson_records from service_role;

-- Table-level REVOKE does not remove independent column-level grants.
-- Revoke only INSERT/UPDATE on every current user column; preserve SELECT.
-- No persistent helper or application-callable raw-write escape hatch is added.
do $$
declare
  target_name text;
  target_table regclass;
  column_names text;
begin
  foreach target_name in array array['lessons', 'lesson_records'] loop
    target_table := pg_catalog.format('public.%I', target_name)::regclass;

    select pg_catalog.string_agg(pg_catalog.quote_ident(attribute.attname), ', ' order by attribute.attnum)
    into column_names
    from pg_catalog.pg_attribute as attribute
    where attribute.attrelid = target_table
      and attribute.attnum > 0
      and not attribute.attisdropped;

    execute pg_catalog.format(
      'revoke insert (%s), update (%s) on table public.%I from service_role',
      column_names, column_names, target_name
    );

    -- Effective privilege checks include PUBLIC/inherited grants. If unexpected
    -- grants still permit writes, abort this transaction rather than silently
    -- claiming success or changing unrelated roles/read/EXECUTE permissions.
    if pg_catalog.has_table_privilege('service_role', target_table, 'INSERT')
      or pg_catalog.has_table_privilege('service_role', target_table, 'UPDATE')
      or pg_catalog.has_table_privilege('service_role', target_table, 'DELETE')
      or pg_catalog.has_any_column_privilege('service_role', target_table, 'INSERT')
      or pg_catalog.has_any_column_privilege('service_role', target_table, 'UPDATE') then
      raise exception 'SERVICE_ROLE_LESSON_RAW_DML_REMAINS: public.%', target_name
        using errcode = '42501';
    end if;
  end loop;
end;
$$;

commit;
