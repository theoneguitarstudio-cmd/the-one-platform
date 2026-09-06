// Creates its own no-network container; reuses existing local-only regression suites.
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {randomBytes} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {candidate,root,validate,hash} from './epic7-readiness.mjs';
import {docker,image,attest,guarded,cleanEnv} from './epic7-readiness-local.mjs';

if(process.argv[2]!=='--create-isolated'||!['--epic7','--legacy'].includes(process.argv[3])||process.argv.length!==4)throw Error('Requires --create-isolated --epic7|--legacy; no existing database target accepted');
if(validate().validation!=='PASS')throw Error('Offline validation failed');
const runId=randomBytes(16).toString('hex');const directory=resolve(root,'artifacts/remote-smoke/epic7-f-local-'+runId);mkdirSync(directory,{recursive:true});
const file=resolve(directory,'target.json');const results=[];let manifest;let adapter;
function record(name,fn){try{const value=fn();results.push({name,status:'PASS'});return value;}catch(e){results.push({name,status:'FAIL',error:e.message.slice(0,1000)});throw e;}}
function child(name,args){const log=resolve(directory,name+'.log');try{const output=execFileSync(process.execPath,args,{cwd:root,env:{...cleanEnv(),EPIC7_F_TARGET_MANIFEST:file},encoding:'utf8',timeout:1200000,maxBuffer:32*1024*1024});writeFileSync(log,output);results.push({name,status:'PASS',sha256:hash(output)});return output;}catch(e){writeFileSync(log,(e.stdout??'')+'\n'+(e.stderr??''));results.push({name,status:'FAIL',exit:e.status});throw Error(name+' failed; inspect local artifact');}}
try{
 // Source is the already-verified LOCAL container; schema-only metadata, no rows.
 const source=JSON.parse(docker(['inspect','supabase_db_the-one-platform']))[0];
 if(source.Id!=='22a0ebfc88f7a19d55a281f9aaa0bcc3c06e5b5bf236614e4bd02a9de07843b7'||source.Image!==image)throw Error('Local Auth schema source identity changed');
 const auth=docker(['exec',source.Id,'pg_dump','-U','postgres','-d','postgres','--schema-only','--schema=auth','--no-owner','--no-privileges']).replace(/^CREATE TRIGGER on_auth_user_created[^;]+;\r?\n/gm,'');
 const containerId=docker(['create','--pull=never','--network=none','--label','theone.epic7-f='+runId,'--name','epic7-f-'+runId,'--entrypoint','/bin/bash',image,'-c','sleep infinity']).trim();
 manifest={kind:'epic7-f-synthetic-local',candidate,runId,containerId,image,database:'epic7_race_20260906',createdUTC:new Date().toISOString(),sourceAuthSchemaSHA256:hash(auth),syntheticOnly:true};writeFileSync(file,JSON.stringify(manifest,null,2));
 docker(['start',containerId]);attest(file);
 docker(['exec','--user','postgres',containerId,'initdb','-D','/tmp/epic7-f-data','--auth=trust']);
 docker(['exec','--user','postgres',containerId,'pg_ctl','-D','/tmp/epic7-f-data','-l','/tmp/epic7-f-pg.log','-o',`-k /tmp -c listen_addresses= -c epic7_f.run_id=${runId}`,'start']);
 adapter=guarded(file);
 adapter.sql('create role anon;create role authenticated;create role service_role bypassrls;'+auth,'postgres');
 child('bootstrap',['scripts/epic7-local-db.mjs','bootstrap']);child('apply',['scripts/epic7-local-db.mjs','apply','20260906000500']);
 const tables=JSON.parse(adapter.sql("select json_agg(schemaname||'.'||tablename order by schemaname,tablename) from pg_tables where schemaname in ('public','auth')").trim());
 if(!tables.every(t=>/^(public|auth)\.[a-z_]+$/.test(t)))throw Error('Unexpected snapshot identifier');
 const snapshotQuery="select jsonb_object_agg(t,jsonb_build_object('count',n,'digest',digest)) from ("+tables.map(t=>`select '${t}' t,count(*) n,md5(coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)::text,'[]')) digest from ${t} r`).join(' union all ')+") x";
 const counts=()=>JSON.parse(adapter.sql(snapshotQuery).trim());
 writeFileSync(resolve(directory,'side-effect-catalog.json'),adapter.sql("select jsonb_build_object('sequences',(select coalesce(jsonb_agg(jsonb_build_object('schema',schemaname,'name',sequencename,'last_value',last_value)),'[]') from pg_sequences where schemaname in ('public','auth')),'trigger_external_tokens',(select coalesce(jsonb_agg(jsonb_build_object('function',p.oid::regprocedure::text,'external_token',p.prosrc ~* '(net[.]|http[_(]|dblink|pg_notify)')),'[]') from pg_proc p join pg_trigger t on t.tgfoid=p.oid join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth') and not t.tgisinternal))").trim());
 const before=counts();
 if(process.argv[3]==='--legacy'){
 child('legacy-sql',['scripts/epic7-local-db.mjs','tests']);
 record('legacy rollback counts',()=>{if(JSON.stringify(before)!==JSON.stringify(counts()))throw Error('Legacy residue');});
 }else{
 child('structure-lock',['scripts/epic7-local-db.mjs','tests','learning_structure.test.sql','global_lock_order_contract.test.sql']);
 child('content-progress-closure',['--test','--test-concurrency=1','scripts/epic7-content.regression.mjs','scripts/epic7-progress.regression.mjs','scripts/epic7-closure.regression.mjs','scripts/epic7-readiness-effects.regression.mjs']);
 child('security',['scripts/epic7-database-review.mjs']);
 record('rollback independent session counts',()=>{if(JSON.stringify(before)!==JSON.stringify(counts()))throw Error('Unexpected rollback residue');});
 // Deliberate test-only sequence proves rollback is not an all-effects guarantee.
 record('sequence increments survive rollback',()=>{adapter.sql('create sequence public.epic7_f_sequence_probe');adapter.sql('begin;select nextval(\'public.epic7_f_sequence_probe\');rollback;');if(adapter.sql('select last_value||\':\'||is_called from public.epic7_f_sequence_probe').trim()!=='1:true')throw Error('Sequence evidence mismatch');});
 child('content-races',['--test','scripts/epic7-concurrency.regression.mjs']);
 child('progress-races',['--test','scripts/epic7-progress-concurrency.regression.mjs']);
 child('post-race-security',['scripts/epic7-database-review.mjs']);
 writeFileSync(resolve(directory,'retained-before-disposal.json'),JSON.stringify(counts(),null,2));
 record('no surviving test sessions/locks',()=>{if(adapter.sql("select count(*) from pg_stat_activity where datname=current_database() and pid<>pg_backend_pid()").trim()!=='0')throw Error('Open sessions remain');});
 }
}catch(e){process.exitCode=1;results.push({name:'orchestrator',status:'FAIL',error:e.message.slice(0,1000)});}
finally{
 if(manifest){try{attest(file);docker(['rm','-f',manifest.containerId]);results.push({name:'dispose owned synthetic container',status:'PASS'});}catch(e){process.exitCode=1;results.push({name:'disposal',status:'FAIL',residue:manifest.containerId,error:e.message.slice(0,500)});}}
 const sources=['scripts/epic7-readiness.mjs','scripts/epic7-readiness-local.mjs','scripts/epic7-readiness-cases.json','scripts/epic7-readiness-rehearse.mjs','scripts/epic7-local-db.mjs'];
 writeFileSync(resolve(directory,'result.json'),JSON.stringify({candidate,uncommittedTools:true,tools:Object.fromEntries(sources.map(p=>[p,hash(readFileSync(resolve(root,p)))])),node:process.version,completedUTC:new Date().toISOString(),results,overall:process.exitCode?'FAIL':'PASS'},null,2));
 console.log(JSON.stringify({directory,results,overall:process.exitCode?'FAIL':'PASS'},null,2));
}
