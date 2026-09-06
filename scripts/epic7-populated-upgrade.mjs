import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {sql,bootstrap,applyThrough,database} from './epic7-local-db.mjs';

assert.equal(database,'epic7_upgrade_20260906','Requires a new disposable populated-upgrade database');
bootstrap(); // Refuses existing databases; never destroys a previous run implicitly.
applyThrough('20260904001100');
assert.equal(sql('select count(*) from supabase_migrations.schema_migrations').trim(),'29');
const commerce=readFileSync(new URL('../supabase/tests/database/entitlement_revoke_booking_consistency_fixture.sql',import.meta.url),'utf8');
sql(`begin;\n\\set p16_fixture_include true\n${commerce}\ncommit;`);
sql(readFileSync(new URL('../supabase/tests/fixtures/epic7_legacy_upgrade.sql',import.meta.url),'utf8'));
const before=JSON.parse(sql('select json_agg(json_build_object(\'table\',table_name,\'rows\',jsonb_array_length(rows))) from private.epic7_upgrade_snapshot').trim());
assert.equal(before.length,13);
for(const table of before)assert(table.rows>0,`Populated evidence required: ${table.table}`);
applyThrough('20260906000500');
sql(`do $$ declare saved record; actual jsonb; begin
 for saved in select * from private.epic7_upgrade_snapshot loop
 execute format('select coalesce(jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text),''[]''::jsonb) from public.%I x',saved.table_name) into actual;
 if actual is distinct from saved.rows then raise exception 'Populated upgrade changed %',saved.table_name; end if;
 end loop;end;$$;`);
assert.equal(sql('select count(*) from supabase_migrations.schema_migrations').trim(),'34');
console.log('PASS: populated 29 → 34 upgrade; every one of 13 table snapshots unchanged');
console.log(JSON.stringify(before)); // Only synthetic aggregate counts, never table contents.
