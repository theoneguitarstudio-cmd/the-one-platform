import {execFileSync,spawn} from 'node:child_process';
import {randomBytes} from 'node:crypto';
import {writeFileSync,mkdirSync} from 'node:fs';
import {docker,image,host,cleanEnv,attest,guarded} from '../../scripts/epic7-readiness-local.mjs';
import {sourceIdentity,candidate,hash} from './schema.mjs';
export const database='epic7_race_20260906';
export function createTarget(){
 sourceIdentity();
 const runId=randomBytes(16).toString('hex'),dir='artifacts/remote-smoke/epic7-real-pg-'+runId;
 mkdirSync(dir,{recursive:true});
 const source=JSON.parse(docker(['inspect','supabase_db_the-one-platform']))[0];
 if(source.Id!=='22a0ebfc88f7a19d55a281f9aaa0bcc3c06e5b5bf236614e4bd02a9de07843b7'||source.Image!==image)throw Error('AUTH_SCHEMA_SOURCE_IDENTITY');
 // Only structural metadata from the verified local development container, never rows.
 const auth=docker(['exec',source.Id,'pg_dump','-U','postgres','-d','postgres','--schema-only','--schema=auth','--no-owner','--no-privileges']).replace(/^CREATE TRIGGER on_auth_user_created[^;]+;\r?\n/gm,'');
 const containerId=docker(['create','--pull=never','--network=none','--label','theone.epic7-f='+runId,'--name','epic7-f-'+runId,'--entrypoint','/bin/bash',image,'-c','sleep infinity']).trim();
 const manifest={kind:'epic7-f-synthetic-local',candidate,runId,containerId,image,database,syntheticOnly:true,sourceAuthSchemaSHA256:hash(auth)};
 const file=dir+'/target.json';writeFileSync(file,JSON.stringify(manifest,null,2));
 docker(['start',containerId]);attest(file);
 docker(['exec','--user','postgres',containerId,'initdb','-D','/tmp/epic7-f-data','--auth=trust']);
 docker(['exec','--user','postgres',containerId,'pg_ctl','-D','/tmp/epic7-f-data','-l','/tmp/epic7-f-pg.log','-o',`-k /tmp -c listen_addresses= -c autovacuum=off -c epic7_f.run_id=${runId}`,'start']);
 const adapter=guarded(file);adapter.sql('create role anon;create role authenticated;create role service_role bypassrls;'+auth,'postgres');
 for(const args of [['bootstrap'],['apply','20260906000500']])execFileSync(process.execPath,['scripts/epic7-local-db.mjs',...args],{env:{...cleanEnv(),EPIC7_F_TARGET_MANIFEST:file},stdio:'pipe',timeout:180000});
 seal(file);return {file,dir,manifest};
}
export function literal(v){if(v===null)return 'NULL';if(typeof v==='number'){if(!Number.isFinite(v))throw Error('VALUE');return String(v);}const s=typeof v==='string'?v:JSON.stringify(v);return "'"+s.replaceAll("'","''")+"'";}
export function bind(q){return q.text.replace(/\$(\d+)(::uuid\[\])?/g,(_,n,array)=>{const v=q.values[Number(n)-1];if(v===undefined)throw Error('PARAMETER');return array?'ARRAY['+v.map(literal).join(',')+']::uuid[]':literal(v);});}
export const schemaSQL="select encode(sha256(convert_to(string_agg(v,E'\\n' order by v),'UTF8')),'hex') fingerprint from (select 'f:'||n.nspname||'.'||p.proname||':'||pg_get_functiondef(p.oid)||':'||coalesce(p.proacl::text,'')||':'||pg_get_userbyid(p.proowner) v from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','auth','private') and p.prokind='f' union all select 'c:'||n.nspname||'.'||c.relname||':'||a.attname||':'||format_type(a.atttypid,a.atttypmod)||':'||a.attnotnull from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private') and c.relkind in ('r','p') and a.attnum>0 and not a.attisdropped union all select 'k:'||conname||':'||pg_get_constraintdef(oid) from pg_constraint where connamespace in ('public'::regnamespace,'auth'::regnamespace,'private'::regnamespace) union all select 'r:'||n.nspname||'.'||c.relname||':'||c.relrowsecurity||':'||c.relforcerowsecurity||':'||coalesce(c.relacl::text,'')||':'||pg_get_userbyid(c.relowner) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private') union all select 't:'||pg_get_triggerdef(t.oid)||':'||t.tgenabled::text from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private') union all select 'p:'||to_jsonb(p)::text from pg_policies p where schemaname in ('public','auth','private') union all select 'role:'||rolname||':'||rolsuper||':'||rolinherit||':'||rolcreaterole||':'||rolcreatedb||':'||rolcanlogin||':'||rolbypassrls from pg_roles union all select 'extension:'||extname||':'||extversion from pg_extension) q";
export function seal(file){const target=attest(file);if(target.schemaFingerprint)throw Error('TARGET_ALREADY_SEALED');target.schemaFingerprint=JSON.parse(guarded(file).sql('select row_to_json(q) from ('+schemaSQL+') q').trim()).fingerprint;writeFileSync(file,JSON.stringify(target,null,2));}
export async function verifyRuntime(writer,target){
 const expected=Object.keys(sourceIdentity().migrations).map(p=>p.split('/').at(-1).slice(0,14)).sort();
 const actual=await writer.query({text:'select version from supabase_migrations.schema_migrations order by version',values:[]});
 if(JSON.stringify(actual.map(r=>r.version))!==JSON.stringify(expected))throw Error('WRONG_VERSION');
 const fp=(await writer.query({text:schemaSQL,values:[]}))[0].fingerprint;
 if(!target.schemaFingerprint||fp!==target.schemaFingerprint)throw Error('WRONG_SCHEMA');
}
export async function open(file,{missingDatabaseProbe=false}={}){
 sourceIdentity();const target=attest(file);guarded(file);
 const child=spawn('docker',['--host',host,'exec','-i',target.containerId,'/bin/bash','-c',`exec psql -h /tmp -X -qAt -U postgres -d ${missingDatabaseProbe?'epic7_missing_probe':database} -v ON_ERROR_STOP=0 -v VERBOSITY=verbose 2>&1`],{env:cleanEnv(),stdio:['pipe','pipe','pipe']});
 let buffer='',pending=null,ended=false,backendId=null;const marker='epic7_'+randomBytes(12).toString('hex');
 const reject=()=>{ended=true;if(pending){clearTimeout(pending.timer);pending.reject(Error('CONNECTION_CLOSED'));pending=null;}};
 child.on('error',reject);child.on('close',reject);child.stderr.on('data',()=>{});
 child.stdout.on('data',d=>{buffer+=d;const at=buffer.indexOf(marker+' ');if(at<0||!pending)return;const end=buffer.indexOf('\n',at);if(end<0)return;const text=buffer.slice(0,at),state=buffer.slice(at,end).trim().split(' ');buffer=buffer.slice(end+1);const p=pending;pending=null;clearTimeout(p.timer);if(state[1]==='true'||/ERROR:/.test(text)){const e=Error((text.match(/ERROR:\s+[A-Z0-9]{5}:\s+(learning:[a-z_]+)/)||[])[1]??'SQL_ERROR');e.code=(text.match(/ERROR:\s+([A-Z0-9]{5}):/)||[])[1]??state[2];p.reject(e);}else p.resolve(text.trim());});
 const raw=sql=>new Promise((resolve,reject)=>{if(ended||pending)return reject(Error('SESSION_UNAVAILABLE'));pending={resolve,reject,timer:setTimeout(()=>{child.kill();const p=pending;pending=null;ended=true;p?.reject(Error('CLIENT_DEADLINE'));},15000)};child.stdin.write(sql+';\n\\echo '+marker+' :ERROR :SQLSTATE\n');});
 const query=async q=>{const sql=bind(q),select=/^(select|with)\b/i.test(sql);const text=await raw(select?"select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from ("+sql+') r':"with changed as ("+sql+" returning 1) select coalesce(jsonb_agg(to_jsonb(changed)),'[]'::jsonb) from changed");const rows=JSON.parse(text);if(!Array.isArray(rows))throw Error('RESULT_SHAPE');return rows;};
 const close=async()=>{if(!ended){await raw('rollback');child.stdin.end('\\q\n');await new Promise(resolve=>child.once('close',resolve));}if(backendId!==null){const remaining=guarded(file).sql('select count(*) from pg_stat_activity where pid='+backendId).trim();if(remaining!=='0')throw Error('CLOSE_FAILED');}};
 const identity=(await query({text:"select pg_backend_pid() pid,current_database() db,current_setting('data_directory') directory,current_setting('server_version_num') version",values:[]}))[0];
 backendId=identity.pid;
 if(identity.db!==database||identity.directory!=='/tmp/epic7-f-data'||identity.version!=='170006'){await close();throw Error('DATABASE_IDENTITY');}
 await raw("set statement_timeout='3s';set lock_timeout='1s';set idle_in_transaction_session_timeout='10s'");
 const writer={raw,query,close,identity,disconnect(){child.stdin.destroy();child.kill();}};try{await verifyRuntime(writer,target);}catch(e){await close();throw e;}return writer;
}
export function record(dir,name,value){writeFileSync(dir+'/'+name+'.json',JSON.stringify(value,null,2),{flag:'wx'});}
if(process.argv[2]==='--create-synthetic'){const t=createTarget();console.log(JSON.stringify(t));}
