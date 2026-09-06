import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {sql,database} from './epic7-local-db.mjs';

const rows=query=>JSON.parse(sql(`select coalesce(json_agg(r),'[]'::json) from (${query}) r`).trim());
const functions=rows(`select p.oid,p.oid::regprocedure::text as signature,p.prosecdef,p.proconfig,pg_get_userbyid(p.proowner) as owner
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname like 'learning_%'`);
assert(functions.length>15);
for(const f of functions){assert.equal(f.owner,'postgres',f.signature);assert.deepEqual(f.proconfig,['search_path=""'],f.signature);}
const errors=rows(`select p.oid::regprocedure::text as signature,c.level,c.message
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 cross join lateral extensions.plpgsql_check_function_tb(p.oid) c
 where n.nspname in ('public','private') and p.proname like 'learning_%' and l.lanname='plpgsql'
 and p.prorettype<>'trigger'::regtype and c.level='error'`);
assert.deepEqual(errors,[],'PL/pgSQL migration lint');
const triggerErrors=rows(`select p.oid::regprocedure::text as signature,c.level,c.message
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_trigger t on t.tgfoid=p.oid
 cross join lateral extensions.plpgsql_check_function_tb(p.oid,t.tgrelid) c
 where n.nspname='private' and p.proname like 'learning_%' and c.level='error'`);
assert.deepEqual(triggerErrors,[],'Trigger migration lint');
const leaked=rows(`select p.oid::regprocedure::text as signature,r.role from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 cross join (values ('anon'),('authenticated'),('service_role')) r(role)
 where p.proname like 'learning_%' and n.nspname in ('public','private')
 and (n.nspname='private' or r.role<>'authenticated') and has_function_privilege(r.role,p.oid,'EXECUTE')`);
assert.deepEqual(leaked,[],'Function grants');
const files=readdirSync(new URL('../supabase/migrations/',import.meta.url)).filter(f=>f.startsWith('20260906')&&f.endsWith('.sql'));
const tables=files.flatMap(f=>[...readFileSync(new URL(`../supabase/migrations/${f}`,import.meta.url),'utf8').matchAll(/create table public\.(\w+)/g)].map(m=>m[1]));
assert.equal(tables.length,24);
for(const t of tables){
 assert.equal(sql(`select relrowsecurity from pg_class where oid='public.${t}'::regclass`).trim(),'t',t);
 assert.equal(sql(`select bool_or(has_table_privilege(r,'public.${t}','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')) from unnest(array['anon','authenticated','service_role']) r`).trim(),'f',t);
}
assert.equal(sql(`select private.learning_course_use_authorized(null,null,null,null)`).trim(),'f');
console.log(`PASS ${database}: ${files.length} Epic7 migrations; ${tables.length} tables deny raw app access; ${functions.length} functions owner/search_path/grants; function + trigger lint zero errors; policy false`);
