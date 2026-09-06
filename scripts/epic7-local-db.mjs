import { execFileSync, spawn } from 'node:child_process';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const awaitAdapter = process.env.EPIC7_F_TARGET_MANIFEST ? await import('./epic7-readiness-local.mjs') : null;
const isolated = awaitAdapter?.guarded(process.env.EPIC7_F_TARGET_MANIFEST);
export const container = isolated?.container ?? 'supabase_db_the-one-platform';
export const database = isolated?.database ?? process.env.EPIC7_LOCAL_DATABASE ?? 'epic7_local_20260906';
if (!['epic7_local_20260906','epic7_clean_20260906','epic7_race_20260906','epic7_upgrade_20260906'].includes(database)) {
  throw new Error('Only named disposable local databases are permitted');
}
export const root = fileURLToPath(new URL('../', import.meta.url));
export function docker(args, input) {
  if (isolated) {
    if (args[0]!=='exec'||args[1]!==container||args[2]!=='pg_dump') throw new Error('Unexpected isolated bootstrap command');
    const adapter=awaitAdapter;
    return adapter.docker(['exec',container,'pg_dump','-h','/tmp',...args.slice(3)],input);
  }
  return execFileSync('docker', args, { input, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
}
export function sql(query, db = database) {
  if(isolated)return isolated.sql(query,db);
  if (![database, 'postgres'].includes(db)) throw new Error('Local database allowlist');
  return docker(['exec', '-i', container, 'psql', '-X', '-U', 'postgres', '-d', db,
    '-v', 'ON_ERROR_STOP=1', '-At'], query);
}
export function session(query) {
  if(isolated)return isolated.session(query);
  return new Promise((resolve) => {
    const child = spawn('docker', ['exec', '-i', container, 'psql', '-X', '-U', 'postgres', '-d', database,
      '-v', 'ON_ERROR_STOP=1', '-At'], { stdio: ['pipe', 'pipe', 'pipe'] });
    let output = '';
    child.stdout.on('data', d => { output += d; });
    child.stderr.on('data', d => { output += d; });
    const timer = setTimeout(() => child.kill(), 30000);
    child.on('close', code => { clearTimeout(timer); resolve({ code, output }); });
    child.stdin.end(query);
  });
}
function testSource(file, stack = []) {
  if (!/^[\w.-]+\.sql$/.test(file) || stack.includes(file)) throw new Error('Invalid/circular SQL fixture include');
  return readFileSync(new URL(`../supabase/tests/database/${file}`, import.meta.url),'utf8')
    .replace(/^\\ir\s+([\w.-]+\.sql)\s*$/gm, (_, included) => testSource(included, [...stack,file]));
}
export function applyThrough(last) {
  const files = readdirSync(new URL('../supabase/migrations/', import.meta.url)).filter(x => x.endsWith('.sql')).sort();
  for (const file of files.filter(x => x.slice(0,14) <= last)) {
    const version=file.slice(0,14);
    if (sql(`select count(*) from supabase_migrations.schema_migrations where version='${version}'`).trim()==='1') continue;
    sql(readFileSync(new URL(`../supabase/migrations/${file}`, import.meta.url),'utf8'));
    sql(`insert into supabase_migrations.schema_migrations(version) values('${version}')`);
    console.log(`APPLIED ${file}`);
  }
}
export function bootstrap() {
  if (sql(`select count(*) from pg_database where datname='${database}'`, 'postgres').trim() !== '0') {
    throw new Error('Isolated database already exists; never overwrite implicitly');
  }
  sql(`create database ${database} template template0`, 'postgres');
  // Managed Auth schema only from LOCAL container. No rows, secrets or dumps written to disk.
  let auth = docker(['exec', container, 'pg_dump', '-U','postgres','-d','postgres',
    '--schema-only','--schema=auth','--no-owner','--no-privileges']);
  auth = auth.replace(/^CREATE TRIGGER on_auth_user_created[^;]+;\r?\n/gm, '');
  sql(auth);
  sql(`create schema if not exists extensions;
    create extension if not exists pgcrypto with schema extensions;
    create extension if not exists pgtap with schema extensions;
    create extension if not exists plpgsql_check with schema extensions;
    grant usage on schema public,auth,extensions to anon,authenticated,service_role;
    grant execute on function auth.uid(),auth.role(),auth.jwt() to anon,authenticated,service_role;
    create schema supabase_migrations;
    create table supabase_migrations.schema_migrations(version text primary key);
    alter database ${database} set search_path=public,extensions;`);
}
if (process.argv[1] && fileURLToPath(import.meta.url) === fileURLToPath(new URL(`file:///${process.argv[1].replaceAll('\\','/')}`))) {
  if (process.argv[2] === 'bootstrap') bootstrap();
  else if (process.argv[2] === 'apply' && /^\d{14}$/.test(process.argv[3] ?? '')) applyThrough(process.argv[3]);
  else if (process.argv[2] === 'tests') {
    const names = process.argv.slice(3);
    const files = names.length ? names : readdirSync(new URL('../supabase/tests/database/', import.meta.url)).filter(x=>x.endsWith('.test.sql')).sort();
    for (const file of files) {
      if (!/^[\w.-]+\.sql$/.test(file)) throw new Error('Invalid test path');
      const output=sql(testSource(file));
      if (/^not ok|Looks like you failed|No tests run/m.test(output)) throw new Error(`${file}\n${output}`);
      const count=(output.match(/^ok /gm)||[]).length;
      if (!count) throw new Error(`No TAP assertions: ${file}`);
      console.log(`PASS ${file} (${count} assertions)`);
    }
  } else throw new Error('Usage: bootstrap | apply TIMESTAMP | tests [filenames]');
}
