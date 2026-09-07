import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';
import {docker,image,attest,guarded} from '../../scripts/epic7-readiness-local.mjs';
import {open,record,database,seal} from './pg-local.mjs';
import {candidate,hash} from './schema.mjs';
const sourceFile=process.argv[2],source=attest(sourceFile),runId=randomBytes(16).toString('hex'),dir='artifacts/remote-smoke/epic7-synthetic-recovery-'+randomUUID();mkdirSync(dir,{recursive:true});
const start=new Date().toISOString(),results=[];let target;
try{
 const id=docker(['create','--pull=never','--network=none','--label','theone.epic7-f='+runId,'--name','epic7-f-'+runId,'--entrypoint','/bin/bash',image,'-c','sleep infinity']).trim();
 const file=dir+'/target.json';writeFileSync(file,JSON.stringify({kind:'epic7-f-synthetic-local',candidate,runId,containerId:id,image,database,syntheticOnly:true}));
 docker(['start',id]);attest(file);target={file,id};
 docker(['exec','--user','postgres',id,'initdb','-D','/tmp/epic7-f-data','--auth=trust']);
 docker(['exec','--user','postgres',id,'pg_ctl','-D','/tmp/epic7-f-data','-l','/tmp/epic7-f-pg.log','-o',`-k /tmp -c listen_addresses= -c autovacuum=off -c epic7_f.run_id=${runId}`,'start']);
 const adapter=guarded(file);adapter.sql('create role anon;create role authenticated;create role service_role bypassrls;create database '+database+' template template0','postgres');
 const sql=docker(['exec',source.containerId,'pg_dump','-h','/tmp','-U','postgres','-d',database,'--no-owner']);
 // Dump only this run's attested isolated database. In memory; no production backup accepted.
 adapter.sql(sql);seal(file);results.push({name:'synthetic full DB schema/data/history restore',status:'PASS',sourceHash:hash(sql)});
 const a=await open(sourceFile),b=await open(file);
 try{
  const tables=await a.query({text:"select schemaname||'.'||tablename name from pg_tables where schemaname in ('public','auth','supabase_migrations') order by 1",values:[]});
  for(const {name}of tables){if(!/^[a-z_]+\.[a-z_]+$/.test(name))throw Error('IDENTIFIER');const q={text:"select count(*)::text n,md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text,'[]')) digest from "+name+' t',values:[]};assert.deepEqual(await b.query(q),await a.query(q),name);}
  results.push({name:'independent all-table contents and migration history',status:'PASS',tables:tables.length});
  const extensions={text:'select extname,extversion from pg_extension order by 1',values:[]};assert.deepEqual(await b.query(extensions),await a.query(extensions));
  const constraints={text:"select conname,pg_get_constraintdef(oid) definition,convalidated from pg_constraint where connamespace in ('public'::regnamespace,'auth'::regnamespace) order by 1,2",values:[]};assert.deepEqual(await b.query(constraints),await a.query(constraints));
  const roles={text:"select rolname,rolsuper,rolinherit,rolcreaterole,rolcreatedb,rolcanlogin,rolbypassrls from pg_roles order by rolname",values:[]};assert.deepEqual(await b.query(roles),await a.query(roles));
  const acls={text:"select n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity,(select jsonb_agg(jsonb_build_array(pg_get_userbyid(x.grantor),case when x.grantee=0 then 'PUBLIC' else pg_get_userbyid(x.grantee) end,x.privilege_type,x.is_grantable) order by x.grantor,x.grantee,x.privilege_type,x.is_grantable) from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) x) acl from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private') and c.relkind in ('r','p','v') order by 1,2",values:[]};assert.deepEqual(await b.query(acls),await a.query(acls));
  results.push({name:'extensions roles FK and ACL compatibility',status:'PASS'});
  await b.raw('begin');await assert.rejects(b.raw('alter table public.epic7_nonexistent_probe add column probe int'),{code:'42P01'});await assert.rejects(b.raw('select 1'),{code:'25P02'});await b.raw('rollback');
  results.push({name:'restore SQL failure aborts transaction',status:'PASS'});
  assert.throws(()=>adapter.sql('begin;create table public.epic7_failed_restore_probe(id int);select 1/0;commit'));
  assert.equal((await b.query({text:"select to_regclass('public.epic7_failed_restore_probe') is null absent",values:[]}))[0].absent,true);
  results.push({name:'bulk restore ON_ERROR_STOP exits and uncommitted schema is absent',status:'PASS'});
 }finally{await a.close();await b.close();}
 record(dir,'result',{runId,candidate,start,end:new Date().toISOString(),source:source.containerId,target:target.id,results,result:'PASS',scope:'SYNTHETIC_DATABASE_ONLY',fullServiceRecovery:false,productionBackupUsed:false,remote:'NOT RUN'});console.log(JSON.stringify({dir,result:'PASS',results}));
}catch(e){record(dir,'failure',{runId,start,end:new Date().toISOString(),reason:e.code??e.message,results,fullServiceRecovery:false});throw e;}
